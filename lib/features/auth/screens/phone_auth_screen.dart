import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reading_jesus_somang/core/constants/theme.dart';
import '../controllers/user_service.dart';
import 'profile_completion_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _smsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  bool _codeSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhoneNumber() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 테스트 번호 체크
    String phoneInput = _phoneController.text
        .trim()
        .replaceAll('-', '')
        .replaceAll(' ', '');

    // 테스트 모드에서는 Firebase 호출 없이 직접 진행
    if (phoneInput == '1029066258' || phoneInput == '1011111111') {
      print('TEST MODE: Using direct test flow for verification');

      // 테스트용 임의 verificationId 생성
      _verificationId =
          'test-verification-id-${DateTime.now().millisecondsSinceEpoch}';

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _codeSent = true;
            _isLoading = false;
          });
          print(
            'TEST MODE: Code sent, using test verificationId: $_verificationId',
          );
        }
      });

      return;
    }

    // 실제 Firebase 인증 로직 (테스트 번호가 아닌 경우)
    try {
      final phoneNumber = '+82$phoneInput';
      print('Verifying phone number: $phoneNumber');

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          } catch (e) {
            print('Auto-verification failed: $e');
            setState(() {
              _isLoading = false;
              _errorMessage = '자동 인증 실패: $e';
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.message}');
          setState(() {
            _isLoading = false;
            _errorMessage = '인증번호 전송 실패: ${e.message}';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          print('Code sent, verificationId: $verificationId');
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 120),
      );
    } catch (e) {
      print('Error during verification: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '오류가 발생했습니다: $e';
      });
    }
  }

  Future<void> _verifySmsCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_verificationId == null || _verificationId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '유효한 인증 ID가 없습니다. 인증번호를 다시 요청해주세요.';
      });
      return;
    }

    final smsCode = _smsController.text.trim();
    print('Verifying SMS code: $smsCode with verificationId: $_verificationId');

    // 테스트 모드 확인 (verificationId가 'test-verification-id'로 시작하는지)
    if (_verificationId!.startsWith('test-verification-id')) {
      print('TEST MODE: Validating test verification code');

      // 전화번호별 테스트 코드 확인
      String phoneInput = _phoneController.text
          .trim()
          .replaceAll('-', '')
          .replaceAll(' ', '');

      bool isValid = false;

      if (phoneInput == '1029066258' && smsCode == '332123') {
        isValid = true;
      } else if (phoneInput == '1011111111' && smsCode == '123123') {
        isValid = true;
      }

      if (isValid) {
        print('TEST MODE: Verification successful');

        // 테스트 인증 성공 시 사용자 정보 생성 (실제로는 Firebase가 처리)
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          // 프로필 완성 여부 확인
          _checkAndNavigateToProfileCompletion();
        }
      } else {
        print('TEST MODE: Invalid verification code');
        setState(() {
          _isLoading = false;
          _errorMessage = '인증 코드가 올바르지 않습니다. 다시 확인해주세요.';
        });
      }

      return;
    }

    // 실제 Firebase 인증 로직 (테스트 모드가 아닌 경우)
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      print('Authentication successful: ${userCredential.user?.uid}');

      if (mounted) {
        // 프로필 완성 여부 확인
        _checkAndNavigateToProfileCompletion();
      }
    } catch (e) {
      print('SMS verification failed: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '인증 코드가 올바르지 않습니다. 다시 확인해주세요.';
      });
    }
  }

  // 프로필 완성 여부를 확인하고 필요시 프로필 설정 화면으로 이동
  Future<void> _checkAndNavigateToProfileCompletion() async {
    try {
      final userService = UserService();
      final hasProfile = await userService.hasUserProfile();

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (hasProfile) {
          // 이미 프로필이 있으면 홈 화면으로 이동
          Navigator.of(context).pop(true);
        } else {
          // 프로필이 없으면 프로필 설정 화면으로 이동
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfileCompletionScreen(),
            ),
          );

          // 프로필 설정 완료되면 홈 화면으로 이동
          if (result == true && mounted) {
            Navigator.of(context).pop(true);
          }
        }
      }
    } catch (e) {
      print('프로필 확인 오류: $e');
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('휴대폰 인증')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 테스트 모드 알림 추가
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            '테스트 모드 안내',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '현재 Firebase 테스트 모드에서는 다음 번호와 코드만 사용할 수 있습니다:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• 번호: 10-2906-6258, 코드: 332123',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      Text(
                        '• 번호: 10-1111-1111, 코드: 123123',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (!_codeSent) ...[
                  const Text(
                    '휴대폰 번호를 입력해주세요',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('+82 ', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: '테스트 번호 중 하나를 입력하세요',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '휴대폰 번호를 입력해주세요';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                              if (_formKey.currentState!.validate()) {
                                _verifyPhoneNumber();
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text('인증번호 받기'),
                  ),
                ] else ...[
                  const Text(
                    '인증번호 입력',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _smsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '테스트 인증번호를 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '인증번호를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                              if (_formKey.currentState!.validate()) {
                                _verifySmsCode();
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text('인증하기'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : _verifyPhoneNumber,
                    child: const Text('인증번호 재전송'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
