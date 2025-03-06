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

  // 회원 탈퇴 (계정 삭제)
  Future<void> deleteAccount() async {
    try {
      // 현재 사용자가 있는지 확인
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('로그인되어 있지 않습니다');
      }

      // Firebase Auth에서 계정 삭제
      await user.delete();
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'requires-recent-login') {
          throw Exception(
            '보안상의 이유로 최근에 로그인한 경우에만 계정을 삭제할 수 있습니다. 로그아웃 후 다시 로그인해주세요.',
          );
        }
      }
      rethrow; // 다른 예외는 그대로 전달
    }
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

  // 재인증을 위한 휴대폰 번호 인증
  Future<bool> reauthenticateWithPhone({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    return await verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  // SMS 코드로 재인증
  Future<UserCredential?> reauthenticateWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // 현재 사용자가 로그인 되어 있는 경우에만 재인증 진행
      if (_auth.currentUser != null) {
        // reauthenticateWithCredential 메서드는 UserCredential을 반환합니다
        return await _auth.currentUser!.reauthenticateWithCredential(
          credential,
        );
      }
      return null;
    } catch (e) {
      print('재인증 오류: $e');
      return null;
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
