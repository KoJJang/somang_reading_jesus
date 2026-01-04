## 외부 OTP + Firebase Custom Token (Twilio Verify) 설정 가이드

목표: Firebase Phone Auth(SMS) 대신, **Twilio Verify로 OTP 발송/검증 → Firebase Custom Token 로그인**으로 교체

---

## 1) 비용/운영 관점 (월 1000회)

- **비용의 대부분은 SMS 단가**
- Cloud Functions 실행 비용은 월 1000회 수준에서는 보통 매우 작음(거의 무시 가능)
- 운영 부담(서버 관리)은 Cloud Functions가 가장 낮음

---

## 2) Twilio 준비

필요 항목:
- Twilio Account SID → `TWILIO_ACCOUNT_SID` (AC...)
- Twilio Auth Token → `TWILIO_AUTH_TOKEN`
- Verify Service SID → `TWILIO_VERIFY_SERVICE_SID` (**VA...**)
  - ⚠️ `MG...`(Messaging Service SID)와 다릅니다. Verify 콘솔에서 Service SID를 확인하세요.

---

## 3) Firebase Functions 배포 준비

repo에 `firebase-functions/`가 추가되어 있습니다.

### Secrets (Functions v2 권장 방식)

Cloud Functions(2nd gen)은 `secrets`로 환경변수를 주입하는 방식이 가장 안전합니다.

필요 secrets:

- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_VERIFY_SERVICE_SID`

설정 예시:

```bash
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_VERIFY_SERVICE_SID
```

---

## 4) Flutter 앱 연결

Flutter 쪽은 `PhoneAuthScreen`이 Firebase Phone Auth 대신 아래 흐름으로 변경되어 있습니다.

- OTP 요청: `POST /requestOtp`
- OTP 검증: `POST /verifyOtp` → token 수신 → `signInWithCustomToken(token)`

설정해야 할 값:
- `lib/features/auth/screens/phone_auth_screen.dart`의 `OtpAuthService(baseUrl: ...)`
  - 서울 리전(asia-northeast3): `https://asia-northeast3-reading-jesus-somang.cloudfunctions.net`

---

## 5) 보안 메모 (필수)

현재 구현은 MVP로 빠르게 붙이기 위한 형태입니다. 운영 전 아래를 추가 권장:

- OTP 요청/검증 rate limit 강화 (IP + phone 기준)
- `otp_requests` TTL 인덱스(만료 자동 삭제)
- verify 성공 후 requestId 재사용 방지(현재 verified로 방지)
- abuse 방지(디바이스 fingerprint, reCAPTCHA 웹 등은 선택)


