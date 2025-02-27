import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 사용자 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 사용자 인증 여부 확인
  bool get isAuthenticated => _auth.currentUser != null;

  // 사용자 UID 가져오기
  String? get userId => _auth.currentUser?.uid;

  // 휴대폰 번호 인증 상태 확인 및 검증
  Future<bool> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        timeout: const Duration(seconds: 60),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // SMS 코드로 인증
  Future<UserCredential?> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      return null;
    }
  }
}
