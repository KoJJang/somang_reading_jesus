import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reading_jesus_somang/core/constants/theme.dart';
import '../controllers/user_service.dart';
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
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  String? _verificationId;
  bool _isLoading = false;
  String? _errorMessage;

  // 각 단계의 완료 상태
  bool _phoneVerified = false;
  bool _smsVerified = false;
  bool _profileComplete = false;

  // 약관 동의 상태
  bool _privacyPolicyAccepted = false;

  @override
  void initState() {
    super.initState();
    // 뒤로가기 버튼 처리를 위한 WillPopScope 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupBackButtonInterceptor();
    });
  }

  void _setupBackButtonInterceptor() {
    // 화면이 처음 로드될 때 인증 상태 확인
    _checkAuthState();
  }

  // 인증 상태 확인 및 정리
  Future<void> _checkAuthState() async {
    if (_auth.currentUser != null) {
      // 이미 로그인된 사용자가 있는 경우 프로필 확인
      final hasProfile = await _userService.hasUserProfile();

      setState(() {
        _profileComplete = hasProfile;
      });

      // 프로필이 없는 경우 인증 상태 유지
      if (!hasProfile) {
        LoggerUtil.info('프로필이 없는 인증 상태 감지: ${_auth.currentUser?.uid}');
        // 전화번호가 있으면 표시
        if (_auth.currentUser?.phoneNumber != null) {
          setState(() {
            _phoneController.text = _auth.currentUser!.phoneNumber!
                .replaceFirst('+82', '');
            _phoneVerified = true;
            _smsVerified = true;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    // 화면을 나갈 때 프로필이 완료되지 않았으면 로그아웃 처리
    if (_auth.currentUser != null && !_profileComplete) {
      _authService.cleanupIncompleteAuth();
    }
    _phoneController.dispose();
    _smsController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
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

  // 전화번호 인증 시작
  Future<void> _verifyPhoneNumber() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 전화번호 형식 정리
    String phoneInput = _phoneController.text
        .trim()
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .replaceAll('_', '');

    // 전화번호 길이 검증
    if (phoneInput.length < 9 || phoneInput.length > 11) {
      setState(() {
        _isLoading = false;
        _errorMessage = '올바른 휴대폰 번호를 입력해주세요.';
      });
      return;
    }

    // 국가코드 추가
    final phoneNumber = '+82$phoneInput';

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,

        // SMS 코드가 자동으로 검색되었을 때 (주로 안드로이드에서 발생)
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            setState(() {
              _phoneVerified = true;
              _smsVerified = true;
              _isLoading = false;
            });
          } catch (e) {
            setState(() {
              _isLoading = false;
              _errorMessage = _getReadableErrorMessage(e as Exception);
            });
          }
        },

        // 인증 실패 시
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _errorMessage = _getReadableErrorMessage(e);
          });
        },

        // 인증 코드가 전송됨
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _phoneVerified = true;
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

  // SMS 코드 검증
  Future<void> _verifySmsCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
        // 인증 성공, 프로필 확인
        final hasProfile = await _userService.hasUserProfile();

        setState(() {
          _smsVerified = true;
          _isLoading = false;
          _profileComplete = hasProfile;
        });

        // 이미 프로필이 있으면 완료 처리
        if (hasProfile) {
          _completeAuthentication();
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

  // 프로필 저장 및 완료
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 개인정보 처리방침 동의 확인
    if (!_privacyPolicyAccepted) {
      setState(() {
        _errorMessage = '서비스 이용을 위해 개인정보 처리방침에 동의해주세요.';
      });
      return;
    }

    // 이름 및 생년월일 값 가져오기
    final name = _nameController.text.trim();
    final birthDateText = _birthDateController.text.trim();

    // 생년월일 형식 변환 (비어있는 경우 null로 처리)
    DateTime? birthDate;
    if (birthDateText.isNotEmpty) {
      try {
        // 입력 형식이 YYYY-MM-DD인 경우
        final parts = birthDateText.split('-');
        if (parts.length == 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          birthDate = DateTime(year, month, day);
        } else {
          // 입력이 숫자로만 이루어진 경우 (YYYYMMDD)
          final cleanedInput = birthDateText.replaceAll(RegExp(r'[^0-9]'), '');
          if (cleanedInput.length == 8) {
            final year = int.parse(cleanedInput.substring(0, 4));
            final month = int.parse(cleanedInput.substring(4, 6));
            final day = int.parse(cleanedInput.substring(6, 8));
            birthDate = DateTime(year, month, day);
          }
        }

        if (birthDateText.isNotEmpty && birthDate == null) {
          throw Exception('유효하지 않은 생년월일 형식입니다.');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = '생년월일 형식이 올바르지 않습니다. YYYY-MM-DD 형식으로 입력해주세요.';
        });
        return;
      }
    }

    try {
      // 프로필 저장
      await _userService.saveUserProfile(name: name, birthDate: birthDate);

      setState(() {
        _profileComplete = true;
        _isLoading = false;
      });

      // 인증 완료 및 홈 화면으로 이동
      _completeAuthentication();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '프로필 저장 중 오류가 발생했습니다: ${e.toString()}';
      });
    }
  }

  // 인증 완료 및 홈 화면으로 이동
  void _completeAuthentication() {
    if (_phoneVerified && _smsVerified && _profileComplete) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final result = await _handlePop();
        if (result && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('회원 인증'),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 오류 메시지 표시
                  if (_errorMessage != null) ...[
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
                  ],

                  // 안내 메시지
                  const Text(
                    '서비스 이용을 위해\n휴대폰 번호를 인증해 주세요',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // 전화번호 입력 필드 (인증 완료 시 비활성화)
                  Stack(
                    children: [
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: '휴대폰 번호',
                          hintText: '01012345678',
                          prefixIcon: const Icon(Icons.phone_android),
                          suffixIcon:
                              _phoneVerified
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                  : null,
                        ),
                        keyboardType: TextInputType.phone,
                        enabled: !_phoneVerified,
                        validator: (value) {
                          if (!_phoneVerified &&
                              (value == null || value.trim().isEmpty)) {
                            return '휴대폰 번호를 입력해주세요';
                          }
                          if (!_phoneVerified) {
                            String numbers = value!.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );
                            if (numbers.length < 10 || numbers.length > 11) {
                              return '올바른 휴대폰 번호를 입력해주세요';
                            }
                          }
                          return null;
                        },
                      ),
                      if (_phoneVerified)
                        Positioned(
                          right: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.check,
                                    color: Colors.green,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 인증번호 받기 버튼 (인증 완료 시 숨김)
                  if (!_phoneVerified) ...[
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyPhoneNumber,
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                '인증번호 받기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ],

                  // SMS 인증 필드 (전화번호 인증 후 표시, SMS 인증 완료 시 비활성화)
                  if (_phoneVerified) ...[
                    // const SizedBox(height: 24),
                    // const Divider(),
                    // const SizedBox(height: 16),
                    Stack(
                      children: [
                        TextFormField(
                          controller: _smsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: '인증번호',
                            hintText: '6자리 숫자',
                            prefixIcon: const Icon(Icons.security),
                            suffixIcon:
                                _smsVerified
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                    : null,
                          ),
                          enabled: _phoneVerified && !_smsVerified,
                          validator: (value) {
                            if (_phoneVerified &&
                                !_smsVerified &&
                                (value == null || value.isEmpty)) {
                              return '인증번호를 입력해주세요';
                            }
                            if (_phoneVerified &&
                                !_smsVerified &&
                                (value!.length != 6 ||
                                    int.tryParse(value) == null)) {
                              return '6자리 숫자를 입력해주세요';
                            }
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                        ),
                        if (_smsVerified)
                          Positioned(
                            right: 12,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.check,
                                      color: Colors.green,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '인증완료',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 인증하기 버튼 (SMS 인증 완료 시 숨김)
                    if (!_smsVerified) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifySmsCode,
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text(
                                        '인증하기',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading ? null : _verifyPhoneNumber,
                        child: const Text(
                          '인증번호 재전송',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],

                  // 프로필 정보 입력 필드 (SMS 인증 후 표시)
                  if (_smsVerified) ...[
                    // const SizedBox(height: 24),
                    // const Divider(),
                    // const SizedBox(height: 16),
                    const Text(
                      '회원 가입을 위해 \n프로필 정보를 입력해 주세요',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // 이름 입력 필드
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '이름 (필수)',
                        hintText: '이름을 입력해주세요',
                        prefixIcon: Icon(Icons.person),
                      ),
                      enabled: !_profileComplete,
                      validator: (value) {
                        if (_smsVerified &&
                            !_profileComplete &&
                            (value == null || value.trim().isEmpty)) {
                          return '이름을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 생년월일 입력 필드
                    TextFormField(
                      controller: _birthDateController,
                      decoration: const InputDecoration(
                        labelText: '생년월일 (선택)',
                        hintText: 'YYYY-MM-DD (예: 1990-01-01)',
                        prefixIcon: Icon(Icons.calendar_today),
                        helperText: '생년월일을 YYYY-MM-DD 형식으로 입력해주세요.',
                      ),
                      enabled: !_profileComplete,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                        LengthLimitingTextInputFormatter(
                          10,
                        ), // YYYY-MM-DD는 최대 10자
                      ],
                      validator: (value) {
                        // 비어있으면 문제 없음 (선택 입력)
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }

                        if (_smsVerified && !_profileComplete) {
                          // 숫자만 추출해서 길이 확인
                          final numericOnly = value.replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          );
                          if (numericOnly.length != 8) {
                            return '올바른 생년월일을 입력해주세요 (YYYYMMDD)';
                          }

                          try {
                            // 입력 형식 변환 및 유효성 검사
                            final formatted = _formatDateInput(value);
                            final parts = formatted.split('-');

                            if (parts.length == 3) {
                              final year = int.parse(parts[0]);
                              final month = int.parse(parts[1]);
                              final day = int.parse(parts[2]);

                              if (year < 1900 || year > DateTime.now().year) {
                                return '올바른 년도를 입력해주세요';
                              }
                              if (month < 1 || month > 12) {
                                return '올바른 월을 입력해주세요 (1-12)';
                              }
                              if (day < 1 || day > 31) {
                                return '올바른 일을 입력해주세요 (1-31)';
                              }
                            } else {
                              return '생년월일을 YYYY-MM-DD 형식으로 입력해주세요';
                            }
                          } catch (e) {
                            return '올바른 생년월일을 입력해주세요';
                          }
                        }

                        return null;
                      },
                      onChanged: (value) {
                        // 자동 포맷팅 적용
                        final formatted = _formatDateInput(value);
                        if (formatted != value) {
                          _birthDateController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // 프로필 저장하기 버튼 (프로필 완료 시 숨김)
                    if (!_profileComplete) ...[
                      // 개인정보 처리방침 동의 체크박스
                      Row(
                        children: [
                          Checkbox(
                            value: _privacyPolicyAccepted,
                            onChanged: (value) {
                              setState(() {
                                _privacyPolicyAccepted = value ?? false;
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                const Text(
                                  '[필수] ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                                const Text(
                                  '개인정보 처리방침에 동의합니다',
                                  style: TextStyle(fontSize: 13),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/privacy-policy',
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 0,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text(
                                    '보기',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveProfile,
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text(
                                        '프로필 저장하기',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],

                  // 모든 단계 완료 시 성공 메시지
                  if (_phoneVerified && _smsVerified && _profileComplete) ...[
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '인증이 완료되었습니다!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '이제 서비스를 이용하실 수 있습니다.',
                            style: TextStyle(color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _completeAuthentication,
                            child: const Text('시작하기'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 뒤로가기 처리
  Future<bool> _handlePop() async {
    // 프로필이 완료되지 않았으면 로그아웃 처리
    if (_auth.currentUser != null && !_profileComplete) {
      await _authService.signOut();

      if (!mounted) return true;

      // 사용자에게 알림 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필 설정이 완료되지 않아 로그아웃되었습니다.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    return true;
  }

  // 생년월일 입력 서식 지정
  String _formatDateInput(String value) {
    // 숫자만 추출
    final numericOnly = value.replaceAll(RegExp(r'[^0-9]'), '');

    // 길이가 0이면 빈 문자열 반환
    if (numericOnly.isEmpty) {
      return '';
    }

    // 길이에 따라 구분자 추가
    if (numericOnly.length <= 4) {
      // 연도만 입력
      return numericOnly;
    } else if (numericOnly.length <= 6) {
      // 연도와 월 입력
      return '${numericOnly.substring(0, 4)}-${numericOnly.substring(4)}';
    } else {
      // 연도, 월, 일 입력
      return '${numericOnly.substring(0, 4)}-${numericOnly.substring(4, 6)}-${numericOnly.substring(6, min(8, numericOnly.length))}';
    }
  }

  int min(int a, int b) => a < b ? a : b;
}
