import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/logger_util.dart';

class OtpAuthService {
  final FirebaseAuth _auth;
  final String _baseUrl;

  static String _normalizeE164Korea(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'[\s\-\(\)_]'), '');

    // Already E.164
    if (cleaned.startsWith('+')) {
      // Fix common mistake: +82010xxxx -> +8210xxxx
      if (cleaned.startsWith('+820')) {
        return '+82${cleaned.substring(4)}';
      }
      return cleaned;
    }

    // Local KR format: 010xxxxxxxx or 0xxxxxxxxx
    if (cleaned.startsWith('0')) {
      return '+82${cleaned.substring(1)}';
    }

    // Fallback: assume KR national number without leading 0 (e.g. 10xxxxxxxx)
    return '+82$cleaned';
  }

  OtpAuthService({FirebaseAuth? auth, required String baseUrl})
    : _auth = auth ?? FirebaseAuth.instance,
      _baseUrl = baseUrl;

  Future<String> requestOtp({required String phone}) async {
    final uri = Uri.parse('$_baseUrl/requestOtp');
    final phoneE164 = _normalizeE164Korea(phone);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phoneE164}),
    );

    if (response.statusCode != 200) {
      LoggerUtil.error('requestOtp failed', {
        'status': response.statusCode,
        'body': response.body,
      });
      throw Exception('OTP_REQUEST_FAILED');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final requestId = (decoded['requestId'] ?? '').toString();
    if (requestId.isEmpty) {
      throw Exception('OTP_REQUEST_INVALID_RESPONSE');
    }
    return requestId;
  }

  Future<UserCredential> verifyOtp({
    required String requestId,
    required String otp,
  }) async {
    final uri = Uri.parse('$_baseUrl/verifyOtp');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'requestId': requestId, 'otp': otp}),
    );

    if (response.statusCode != 200) {
      LoggerUtil.error('verifyOtp failed', {
        'status': response.statusCode,
        'body': response.body,
      });
      throw Exception('OTP_VERIFY_FAILED');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final token = (decoded['token'] ?? '').toString();
    if (token.isEmpty) {
      throw Exception('OTP_VERIFY_INVALID_RESPONSE');
    }

    return await _auth.signInWithCustomToken(token);
  }
}
