import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reading_jesus_somang/core/constants/theme.dart';
import '../controllers/user_service.dart';
import 'profile_completion_screen.dart';
import '../../../core/utils/logger_util.dart';
import '../controllers/auth_service.dart';

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
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _phoneController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  // Firebase 에러 메시지를 사용자 친화적인 메시지로 변환
  String _getReadableErrorMessage(Exception e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return '올바른 휴대폰 번호 형식이 아닙니다.';
        case 'invalid-verification-code':
          return '인증번호가 올바르지 않습니다.';
        case 'too-many-requests':
          return '너무 많은 요청을 보냈습니다. 잠시 후 다시 시도해주세요.';
        case 'quota-exceeded':
          return '서비스 요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.';
        case 'operation-not-allowed':
          return '휴대폰 인증 서비스를 사용할 수 없습니다.';
        case 'network-request-failed':
          return '네트워크 연결이 불안정합니다. 인터넷 연결을 확인해주세요.';
        case 'session-expired':
          return '인증 세션이 만료되었습니다. 인증번호를 다시 요청해주세요.';
        default:
          return '인증 과정에 문제가 발생했습니다. 잠시 후 다시 시도해주세요.';
      }
    }
    return '오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
  }

  Future<void> _verifyPhoneNumber() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 전화번호 형식 정리
    String phoneInput = _phoneController.text
        .trim()
        .replaceAll('-', '')
        .replaceAll(' ', '');

    // 전화번호 길이 검증
    if (phoneInput.length < 9 || phoneInput.length > 11) {
      setState(() {
        _isLoading = false;
        _errorMessage = '올바른 휴대폰 번호를 입력해주세요.';
      });
      return;
    }

    // 실제 Firebase 인증 로직
    try {
      final phoneNumber = '+82$phoneInput';

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          } catch (e) {
            setState(() {
              _isLoading = false;
              _errorMessage = _getReadableErrorMessage(e as Exception);
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _errorMessage = _getReadableErrorMessage(e);
          });
        },
        codeSent: (String verificationId, int? resendToken) {
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
      setState(() {
        _isLoading = false;
        _errorMessage = _getReadableErrorMessage(e as Exception);
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
        _errorMessage = '인증번호를 다시 요청해주세요.';
      });
      return;
    }

    final smsCode = _smsController.text.trim();

    // 인증 코드 길이 확인
    if (smsCode.length != 6) {
      setState(() {
        _isLoading = false;
        _errorMessage = '인증번호는 6자리 숫자입니다.';
      });
      return;
    }

    // 실제 Firebase 인증 로직
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        if (mounted) {
          // 프로필 완성 여부 확인
          _checkAndNavigateToProfileCompletion();
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '인증에 실패했습니다. 다시 시도해주세요.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _getReadableErrorMessage(e as Exception);
      });
    }
  }

  Future<void> _checkAndNavigateToProfileCompletion() async {
    try {
      final userService = UserService();
      final hasProfile = await userService.hasUserProfile();

      if (mounted) {
        if (hasProfile) {
          // 이미 프로필이 있는 경우, 홈으로 이동
          Navigator.of(context).pop(true);
        } else {
          // 프로필이 없는 경우, 프로필 완성 페이지로 이동
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfileCompletionScreen(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '프로필 정보를 확인하는 중 문제가 발생했습니다.';
        });
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
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                if (!_codeSent) ...[
                  // 앱 심사자를 위한 테스트 계정 정보
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'App 심사를 위한 안내',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '테스트용 전화번호: 010-1234-5678',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          '테스트용 인증 코드: 123456',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '위 정보로 로그인하시면 앱의 모든 기능을 테스트하실 수 있습니다.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: '휴대폰 번호',
                      hintText: '01012345678',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '휴대폰 번호를 입력해주세요';
                      }
                      String numbers = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (numbers.length < 10 || numbers.length > 11) {
                        return '올바른 휴대폰 번호를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator()
                            : const Text(
                              '인증번호 받기',
                              style: TextStyle(fontSize: 16),
                            ),
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
                      hintText: '인증번호를 입력하세요',
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
