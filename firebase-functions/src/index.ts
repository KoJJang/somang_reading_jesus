import { onRequest } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import admin from 'firebase-admin';
import crypto from 'node:crypto';
import type { Request, Response } from 'express';
import twilio from 'twilio';

admin.initializeApp();

const FUNCTION_REGION = 'asia-northeast3';
const FUNCTION_SECRETS = [
  'TWILIO_ACCOUNT_SID',
  'TWILIO_AUTH_TOKEN',
  'TWILIO_VERIFY_SERVICE_SID',
] as const;

type JsonObject = Record<string, unknown>;

function getRequiredEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing env: ${key}`);
  }
  return value;
}

function getNormalizedE164Korea(phone: string): string {
  const cleaned = phone.replace(/[^\d+]/g, '');
  // Fix common mistake: +82010xxxx -> +8210xxxx
  if (cleaned.startsWith('+820')) return `+82${cleaned.slice(4)}`;
  if (cleaned.startsWith('+82')) return cleaned;
  if (/^0\d{9,10}$/.test(cleaned)) return `+82${cleaned.slice(1)}`;
  return cleaned;
}

function nowMillis(): number {
  return Date.now();
}

function maskSid(value: string): string {
  if (value.length <= 8) return '****';
  return `${value.slice(0, 4)}...${value.slice(-4)}`;
}

function getTwilioClient() {
  const accountSid = getRequiredEnv('TWILIO_ACCOUNT_SID');
  const authToken = getRequiredEnv('TWILIO_AUTH_TOKEN');
  return twilio(accountSid, authToken);
}

function validateVerifyServiceSid(verifyServiceSid: string): void {
  // Twilio Verify Service SID starts with "VA"
  if (!verifyServiceSid.startsWith('VA')) {
    throw new Error('TWILIO_VERIFY_SERVICE_SID_INVALID');
  }
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

async function findUidByPhoneE164(phoneE164: string): Promise<string | null> {
  const snapshot = await admin.firestore().collection('users').where('phoneNumber', '==', phoneE164).limit(1).get();
  if (snapshot.empty) return null;
  return snapshot.docs[0].id;
}

function assertJsonBody(request: Request): JsonObject {
  if (!request.body || typeof request.body !== 'object') {
    throw new Error('INVALID_BODY');
  }
  return request.body as JsonObject;
}

export const requestOtp = onRequest(
  { region: FUNCTION_REGION, secrets: [...FUNCTION_SECRETS] },
  async (req: Request, res: Response) => {
    try {
      const body = assertJsonBody(req);
      const rawPhone = String(body.phone ?? '');
      const phoneE164 = getNormalizedE164Korea(rawPhone);
      if (!phoneE164.startsWith('+82')) {
        res.status(400).json({ error: 'INVALID_PHONE' });
        return;
      }

      const requestId = crypto.randomUUID();
      const createdAt = admin.firestore.Timestamp.now();
      const expiresAt = admin.firestore.Timestamp.fromMillis(nowMillis() + 3 * 60 * 1000);

      // Rate limit: max 5 requests / 1 hour / phone
      //
      // NOTE:
      // Avoid composite index requirement by querying only phoneE164 (single-field index)
      // and filtering in memory for the time window.
      const recentSamePhone = await admin
        .firestore()
        .collection('otp_requests')
        .where('phoneE164', '==', phoneE164)
        .limit(20)
        .get();
      const rateWindowStartMillis = nowMillis() - 60 * 60 * 1000;
      const recentCount = recentSamePhone.docs.filter((doc) => {
        const createdAtValue = doc.get('createdAt') as admin.firestore.Timestamp | undefined;
        return (createdAtValue?.toMillis() ?? 0) >= rateWindowStartMillis;
      }).length;
      if (recentCount >= 5) {
        res.status(429).json({ error: 'TOO_MANY_REQUESTS' });
        return;
      }

      await admin.firestore().collection('otp_requests').doc(requestId).set({
        requestId,
        phoneE164,
        attemptCount: 0,
        verified: false,
        createdAt,
        expiresAt,
      });

      const verifyServiceSid = getRequiredEnv('TWILIO_VERIFY_SERVICE_SID');
      validateVerifyServiceSid(verifyServiceSid);
      logger.info('requestOtp twilio target', {
        phoneE164,
        accountSid: maskSid(getRequiredEnv('TWILIO_ACCOUNT_SID')),
        verifyServiceSid: maskSid(verifyServiceSid),
      });
      const client = getTwilioClient();
      await client.verify.v2
        .services(verifyServiceSid)
        .verifications.create({ to: phoneE164, channel: 'sms' });

      res.status(200).json({ requestId, expiresInSeconds: 180 });
    } catch (e) {
      const message = getErrorMessage(e);
      logger.error('requestOtp failed', { message });
      logger.error('requestOtp raw error', e as any);
      if (message === 'TWILIO_VERIFY_SERVICE_SID_INVALID') {
        res.status(500).json({ error: 'BAD_CONFIG', detail: message });
        return;
      }
      res.status(500).json({ error: 'INTERNAL', detail: message });
    }
  },
);

export const verifyOtp = onRequest(
  { region: FUNCTION_REGION, secrets: [...FUNCTION_SECRETS] },
  async (req: Request, res: Response) => {
    try {
      const body = assertJsonBody(req);
      const requestId = String(body.requestId ?? '');
      const otp = String(body.otp ?? '');
      if (!requestId || otp.length !== 6) {
        res.status(400).json({ error: 'INVALID_INPUT' });
        return;
      }

      const ref = admin.firestore().collection('otp_requests').doc(requestId);
      const snap = await ref.get();
      if (!snap.exists) {
        res.status(404).json({ error: 'NOT_FOUND' });
        return;
      }

      const data = snap.data() as any;
      const expiresAt: admin.firestore.Timestamp = data.expiresAt;
      if (expiresAt.toMillis() < nowMillis()) {
        res.status(400).json({ error: 'EXPIRED' });
        return;
      }
      if (data.verified === true) {
        res.status(400).json({ error: 'ALREADY_VERIFIED' });
        return;
      }

      const attemptCount: number = Number(data.attemptCount ?? 0);
      if (attemptCount >= 5) {
        res.status(429).json({ error: 'TOO_MANY_ATTEMPTS' });
        return;
      }

      const phoneE164 = String(data.phoneE164 ?? '');

      const verifyServiceSid = getRequiredEnv('TWILIO_VERIFY_SERVICE_SID');
      validateVerifyServiceSid(verifyServiceSid);
      const client = getTwilioClient();
      const check = await client.verify.v2
        .services(verifyServiceSid)
        .verificationChecks.create({ to: phoneE164, code: otp });
      if (check.status !== 'approved') {
        await ref.set({ attemptCount: attemptCount + 1 }, { merge: true });
        res.status(400).json({ error: 'INVALID_OTP' });
        return;
      }

      const existingUid = await findUidByPhoneE164(phoneE164);
      const uid =
        existingUid ?? crypto.createHash('sha256').update(phoneE164).digest('hex').slice(0, 28);

      await ref.set({ verified: true, verifiedAt: admin.firestore.Timestamp.now() }, { merge: true });

      const token = await admin.auth().createCustomToken(uid, { phoneE164 });
      res.status(200).json({ token, uid, phoneE164, isNewUser: existingUid == null });
    } catch (e) {
      const message = getErrorMessage(e);
      logger.error('verifyOtp failed', { message });
      logger.error('verifyOtp raw error', e as any);
      res.status(500).json({ error: 'INTERNAL', detail: message });
    }
  },
);
