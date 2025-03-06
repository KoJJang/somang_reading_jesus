import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../controllers/user_service.dart';
import '../models/user_profile.dart';
import '../../../core/constants/theme.dart';
import '../../../data/services/reading_service.dart';
import '../controllers/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final ReadingService _readingService = ReadingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isSyncing = false;
  final _dateFormat = DateFormat('yyyy년 MM월 dd일');

  // 동기화 제한 관련 변수 추가
  DateTime? _lastSyncTime;
  static const int _syncCooldownSeconds = 30; // 30초 쿨다운
  int _remainingCooldown = 0; // 남은 쿨다운 시간
  Timer? _cooldownTimer; // 쿨다운 타이머

  // 재인증 관련 변수
  final TextEditingController _smsCodeController = TextEditingController();
  String? _verificationId;
  bool _isVerifying = false;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadLastSyncTime();

    // Listen to authentication state changes
    _auth.authStateChanges().listen((User? user) {
      if (mounted) {
        if (user == null) {
          // 사용자가 로그아웃했을 때는 프로필 상태만 갱신
          setState(() {
            _userProfile = null;
          });
          _loadUserProfile();
        } else {
          // User logged in, refresh profile
          _loadUserProfile();
        }
      }
    });
  }

  @override
  void dispose() {
    _smsCodeController.dispose();
    // 타이머 정리
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // 마지막 동기화 시간 로드
  Future<void> _loadLastSyncTime() async {
    if (_authService.isAuthenticated) {
      final lastSyncTime = _readingService.getLastSyncTime();
      setState(() {
        _lastSyncTime = lastSyncTime;
      });
    }
  }

  // 쿨다운 타이머 시작
  void _startCooldownTimer() {
    _remainingCooldown = _syncCooldownSeconds;

    // 기존 타이머 취소
    _cooldownTimer?.cancel();

    // 새 타이머 시작
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingCooldown > 0) {
          _remainingCooldown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // 사용자 프로필 로드
  Future<void> _loadUserProfile() async {
    if (_authService.isAuthenticated) {
      final profile = await _userService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 로그인 화면으로 이동
  Future<void> _login() async {
    // 로그인 화면으로 이동
    final result = await Navigator.pushNamed(context, '/phone-auth');
    if (result == true && mounted) {
      // 로그인 성공 시 프로필 다시 로드
      _loadUserProfile();
      _loadLastSyncTime();
    }
  }

  // 데이터 동기화 실행
  Future<void> _syncReadingData() async {
    // 사용자가 인증되지 않은 경우 로그인 안내
    if (!_authService.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('데이터 동기화를 위해 로그인이 필요합니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      // 데이터 동기화 실행
      await _readingService.syncFromFirebase();

      // 마지막 동기화 시간 업데이트
      _lastSyncTime = DateTime.now();

      // 쿨다운 타이머 시작
      _startCooldownTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('데이터 동기화가 완료되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동기화 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  // 로컬 데이터를 Firebase에 업로드
  Future<void> _uploadToFirebase() async {
    // 사용자가 인증되지 않은 경우 로그인 안내
    if (!_authService.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('데이터 업로드를 위해 로그인이 필요합니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      // 로컬 데이터 업로드 실행
      await _readingService.uploadToFirebase();

      // 마지막 동기화 시간 업데이트
      _lastSyncTime = DateTime.now();

      // 쿨다운 타이머 시작
      _startCooldownTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로컬 데이터가 성공적으로 업로드되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업로드 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();

      // 로그아웃 후 상태 업데이트
      setState(() {
        _userProfile = null;
      });

      if (mounted) {
        // 로그아웃 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그아웃 되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );

        // 프로필 화면 닫고 홈 화면으로 이동
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그아웃 중 오류가 발생했습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 회원 탈퇴 확인 다이얼로그 표시
  Future<void> _showDeleteAccountDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 대화 상자 밖을 탭해도 닫히지 않음
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('회원 탈퇴'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('회원 탈퇴를 진행하시겠습니까?'),
                SizedBox(height: 10),
                Text(
                  '모든 계정 정보와 통독 데이터가 삭제되며, 이 작업은 취소할 수 없습니다.',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('탈퇴하기', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
            ),
          ],
        );
      },
    );
  }

  // 회원 탈퇴 실행
  Future<void> _deleteAccount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Firestore에서 사용자 데이터 삭제
      try {
        await _userService.deleteUserData();
        print('Firestore 데이터 삭제 완료');
      } catch (e) {
        print('Firestore 데이터 삭제 중 오류: $e');
        // Firestore 데이터 삭제 실패해도 계속 진행
      }

      // 2. 로컬 통독 데이터 삭제
      try {
        await _readingService.deleteUserData();
        print('로컬 데이터 삭제 완료');
      } catch (e) {
        print('로컬 데이터 삭제 중 오류: $e');
        // 로컬 데이터 삭제 실패해도 계속 진행
      }

      // 3. Firebase Auth에서 계정 삭제
      await _authService.deleteAccount();
      print('Firebase 계정 삭제 완료');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원 탈퇴가 완료되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );

        // 홈 화면으로 이동
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (e.toString().contains('requires-recent-login')) {
          // 재인증이 필요한 경우 재인증 다이얼로그 표시
          _showReauthenticationDialog();
          return;
        }

        String errorMessage = '회원 탈퇴 중 오류가 발생했습니다: ${e.toString()}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 3),
          ),
        );

        // 콘솔에도 오류 로그 출력
        print('회원 탈퇴 오류: $e');
      }
    }
  }

  // 재인증 다이얼로그 표시
  void _showReauthenticationDialog() {
    // 현재 사용자의 전화번호 가져오기
    _phoneNumber = _authService.currentUser?.phoneNumber;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('보안 인증'),
              content:
                  _verificationId == null
                      ? Text(
                        '계정 삭제를 위해 인증이 필요합니다.\n휴대폰 번호 $_phoneNumber로 인증 코드를 전송합니다.',
                      )
                      : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('인증 코드 6자리를 입력해주세요'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _smsCodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              hintText: '6자리 코드 입력',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isLoading = false;
                      _verificationId = null;
                    });
                  },
                  child: const Text('취소'),
                ),
                if (_verificationId == null)
                  TextButton(
                    onPressed:
                        _isVerifying
                            ? null
                            : () => _sendVerificationCode(setState),
                    child:
                        _isVerifying
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('인증 코드 전송'),
                  )
                else
                  TextButton(
                    onPressed:
                        _isVerifying
                            ? null
                            : () => _verifyAndDeleteAccount(setState),
                    child:
                        _isVerifying
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('확인'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // 인증 코드 전송
  Future<void> _sendVerificationCode(StateSetter setState) async {
    if (_phoneNumber == null) return;

    setState(() {
      _isVerifying = true;
    });

    await _authService.reauthenticateWithPhone(
      phoneNumber: _phoneNumber!,
      verificationCompleted: (credential) async {
        // 자동 인증 완료
        setState(() {
          _isVerifying = false;
        });
        Navigator.of(context).pop();
        await _completeReauthentication(credential);
      },
      verificationFailed: (e) {
        setState(() {
          _isVerifying = false;
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('인증 실패: ${e.message}')));
      },
      codeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isVerifying = false;
        });
      },
      codeAutoRetrievalTimeout: (verificationId) {
        setState(() {
          _verificationId = verificationId;
          _isVerifying = false;
        });
      },
    );
  }

  // 인증 코드 확인 및 계정 삭제
  Future<void> _verifyAndDeleteAccount(StateSetter setState) async {
    if (_verificationId == null) return;

    setState(() {
      _isVerifying = true;
    });

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _smsCodeController.text.trim(),
    );

    await _completeReauthentication(credential);
  }

  // 재인증 완료 후 계정 삭제 진행
  Future<void> _completeReauthentication(PhoneAuthCredential credential) async {
    try {
      // 현재 다이얼로그 닫기
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      setState(() {
        _isLoading = true;
      });

      // 재인증
      await _authService.currentUser?.reauthenticateWithCredential(credential);
      print('재인증 완료');

      // 계정 삭제 재시도 - 이전에 데이터는 이미 삭제되었으므로 Auth 계정만 삭제
      try {
        // Firebase Auth에서 계정 삭제
        await _authService.deleteAccount();
        print('Firebase 계정 삭제 완료');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('회원 탈퇴가 완료되었습니다'),
              duration: Duration(seconds: 2),
            ),
          );

          // 홈 화면으로 이동
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        print('계정 삭제 재시도 중 오류: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('계정 삭제 중 오류가 발생했습니다: ${e.toString()}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('재인증 실패: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('재인증 실패: ${e.toString()}')));
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 프로필 정보 카드
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.blue.shade100,
                                child: const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_userProfile != null) ...[
                              Center(
                                child: Text(
                                  _userProfile!.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  _userProfile!.phoneNumber,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  '생년월일: ${DateFormat('yyyy년 MM월 dd일').format(_userProfile!.birthDate)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ] else ...[
                              const Center(
                                child: Text(
                                  '프로필 정보가 없습니다',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 데이터 동기화 설정 카드
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.sync, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  '데이터 동기화 설정',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            ListTile(
                              title: const Text('데이터 동기화'),
                              subtitle: Text(
                                _lastSyncTime != null
                                    ? '마지막 동기화: ${_dateFormat.format(_lastSyncTime!)}'
                                    : '아직 동기화되지 않음',
                              ),
                              trailing:
                                  _isSyncing
                                      ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.cloud_download),
                              onTap:
                                  _isSyncing || _remainingCooldown > 0
                                      ? null
                                      : _syncReadingData,
                            ),
                            if (_remainingCooldown > 0)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Text(
                                  '${_remainingCooldown}초 후에 다시 시도할 수 있습니다',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ListTile(
                              title: const Text('로컬 데이터 업로드'),
                              subtitle: const Text('로컬 데이터를 클라우드에 업로드합니다'),
                              trailing:
                                  _isSyncing
                                      ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.cloud_upload),
                              onTap:
                                  _isSyncing || _remainingCooldown > 0
                                      ? null
                                      : _uploadToFirebase,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 로그인/로그아웃 버튼 위에 개인정보 처리방침 링크 추가
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('개인정보 처리방침'),
                      onTap: () {
                        Navigator.pushNamed(context, '/privacy-policy');
                      },
                    ),
                    const Divider(),
                    if (_authService.isAuthenticated) ...[
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('로그아웃'),
                        onTap: _signOut,
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        title: const Text(
                          '회원 탈퇴',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: _showDeleteAccountDialog,
                      ),
                    ] else ...[
                      ListTile(
                        leading: const Icon(Icons.login),
                        title: const Text('로그인'),
                        onTap: _login,
                      ),
                    ],
                  ],
                ),
              ),
    );
  }
}
