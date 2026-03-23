import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../controllers/user_service.dart';
import '../models/user_profile.dart';
import '../../../data/services/reading_service.dart';
import '../controllers/auth_service.dart';
import '../../team/models/team.dart';
import '../../team/services/team_service.dart';
import '../../team/services/real_team_data_importer.dart';
import '../../../core/utils/phone_helper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final ReadingService _readingService = ReadingService();
  final TeamService _teamService = TeamService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserProfile? _userProfile;
  List<Team> _myTeams = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  final _dateFormat = DateFormat('yyyy년 MM월 dd일');

  // 알림 설정
  bool _notificationEnabled = false;
  int _notificationHour = 8;
  int _notificationMinute = 0;

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
    _loadNotificationSettings();

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

  // 알림 설정 로드
  Future<void> _loadNotificationSettings() async {
    final settings = await NotificationService.instance.loadSettings();
    if (mounted) {
      setState(() {
        _notificationEnabled = settings.enabled;
        _notificationHour = settings.hour;
        _notificationMinute = settings.minute;
      });
    }
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
      // 팀 정보 로드
      List<Team> myTeams = [];
      try {
        myTeams = await _teamService.getMyTeams();
      } catch (_) {
        // 팀 정보 로드 실패 시 무시
      }
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _myTeams = myTeams;
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
                        '계정 삭제를 위해 인증이 필요합니다.\n휴대폰 번호 ${PhoneHelper.formatForDisplay(_phoneNumber)}로 인증 코드를 전송합니다.',
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

  Widget _buildEditableRow({
    required String label,
    required TextStyle style,
    required VoidCallback onEdit,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: style),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onEdit,
          child: const Icon(Icons.edit, size: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(
      text: _userProfile?.name ?? '',
    );
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('이름 수정'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '이름을 입력하세요',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    if (newName != null && newName.isNotEmpty && mounted) {
      await _userService.saveUserProfile(
        name: newName,
        birthDate: _userProfile?.birthDate,
      );
      _loadUserProfile();
    }
  }

  Future<void> _showEditBirthDateDialog() async {
    final controller = TextEditingController(
      text: _userProfile?.birthDate != null
          ? DateFormat('yyyy-MM-dd').format(_userProfile!.birthDate!)
          : '',
    );
    final String? newDateStr = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('생년월일 수정'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'YYYY-MM-DD (예: 1990-01-01)',
              border: OutlineInputBorder(),
              helperText: 'YYYY-MM-DD 형식으로 입력',
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    if (newDateStr != null && newDateStr.isNotEmpty && mounted) {
      try {
        final newDate = DateFormat('yyyy-MM-dd').parse(newDateStr);
        await _userService.saveUserProfile(
          name: _userProfile?.name ?? '',
          birthDate: newDate,
        );
        _loadUserProfile();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('올바른 날짜 형식이 아닙니다 (YYYY-MM-DD)')),
          );
        }
      }
    }
  }

  Widget _buildNotificationCard() {
    final timeLabel =
        '${_notificationHour.toString().padLeft(2, '0')}:'
        '${_notificationMinute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOTIFICATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '말씀 알림',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                value: _notificationEnabled,
                onChanged: (value) async {
                  if (value) {
                    await NotificationService.instance.requestPermission();
                  }
                  await NotificationService.instance.saveSettings(
                    enabled: value,
                    hour: _notificationHour,
                    minute: _notificationMinute,
                  );
                  if (mounted) {
                    setState(() => _notificationEnabled = value);
                  }
                },
              ),
            ],
          ),
          if (_notificationEnabled) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: _notificationHour,
                    minute: _notificationMinute,
                  ),
                );
                if (picked != null && mounted) {
                  await NotificationService.instance.saveSettings(
                    enabled: true,
                    hour: picked.hour,
                    minute: picked.minute,
                  );
                  setState(() {
                    _notificationHour = picked.hour;
                    _notificationMinute = picked.minute;
                  });
                }
              },
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '매일 $timeLabel 알림 (월~토, 휴식주 제외)',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TEAM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          if (_myTeams.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final team in _myTeams)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      team.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryMuted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _myTeams.length == 1
                  ? '팀장: ${_myTeams.first.leaderName}'
                  : '팀 ${_myTeams.length}개 소속',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/my-teams');
                  _loadUserProfile();
                },
                icon: const Icon(Icons.group, size: 18),
                label: const Text('팀 현황 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.disabled,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '아직 팀에 배정되지 않았습니다',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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
                                child: Text(
                                  (_userProfile?.name.isNotEmpty == true)
                                      ? _userProfile!.name[0]
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 이름 (편집 가능)
                            _buildEditableRow(
                              label: (_userProfile != null &&
                                      _userProfile!.name.trim().isNotEmpty)
                                  ? _userProfile!.name
                                  : '이름 미설정',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              onEdit: () => _showEditNameDialog(),
                            ),
                            const SizedBox(height: 8),
                            // 전화번호
                            Center(
                              child: Text(
                                PhoneHelper.formatForDisplay(
                                  _userProfile?.phoneNumber ??
                                      _auth.currentUser?.phoneNumber,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 생년월일 (편집 가능)
                            _buildEditableRow(
                              label: _userProfile?.birthDate != null
                                  ? '생년월일: ${DateFormat('yyyy년 MM월 dd일').format(_userProfile!.birthDate!)}'
                                  : '생년월일: 미설정',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              onEdit: () => _showEditBirthDateDialog(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 팀 정보 카드
                    if (_authService.isAuthenticated) _buildTeamInfoCard(),

                    const SizedBox(height: 16),

                    // 알림 설정 카드
                    _buildNotificationCard(),

                    const SizedBox(height: 16),

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

                    // ─────────────────────────────────────────────
                    // ⚠️ DEBUG ONLY – 팀 테스트 데이터 시드 섹션
                    // kDebugMode가 false이면 이 블록은 아예 렌더링되지 않습니다.
                    // 삭제 시점: 팀 기능 QA 완료 후
                    // ─────────────────────────────────────────────
                    if (kDebugMode && _authService.isAuthenticated)
                      _buildDebugSeedSection(),
                  ],
                ),
              ),
    );
  }

  // ===========================================================================
  // ⚠️ DEBUG ONLY – 테스트 데이터 생성/삭제 UI
  // ===========================================================================

  Widget _buildDebugSeedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'DEBUG – 팀 테스트 데이터',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ⚠️ 임시 – 실제 2026 팀 데이터 임포트 (Excel → JSON → Firestore)
        OutlinedButton.icon(
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('실제 팀 데이터 임포트 (2026)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue.shade700,
            side: BorderSide(color: Colors.blue.shade300),
          ),
          onPressed: _importRealTeamData,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('수동 추가 팀만 임포트 (manualAdd)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.teal.shade700,
            side: BorderSide(color: Colors.teal.shade300),
          ),
          onPressed: _importManualTeams,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_sweep, size: 18),
          label: const Text('2026 팀 전체 삭제 (임포트 초기화)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade300),
          ),
          onPressed: _deleteAll2026Teams,
        ),
        const SizedBox(height: 4),
        const Text(
          '⚠️ 이 섹션은 디버그 빌드에서만 표시됩니다.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Future<void> _importRealTeamData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('실제 팀 데이터 임포트'),
        content: const Text(
          'assets/data/teams_2026.json 파일의 데이터를 Firestore에 반영합니다.\n\n'
          '• 팀장/팀원 이름으로 users 컬렉션 매칭\n'
          '• 2026년 팀 및 member_year_profiles 생성\n\n'
          '이미 2026 팀이 있으면 중복 생성될 수 있습니다. 진행할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('임포트'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final importer = RealTeamDataImporter();
      final result = await importer.importFromAssets();
      await _loadUserProfile();

      if (!mounted) return;
      final message = result.errors.isEmpty
          ? '✅ ${result.summary}'
          : '${result.summary}\n\n미매칭: ${result.errors.take(5).join(", ")}${result.errors.length > 5 ? " 외 ${result.errors.length - 5}건" : ""}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('임포트 실패: $e')),
        );
      }
    }
  }

  Future<void> _importManualTeams() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('수동 추가 팀 임포트'),
        content: const Text(
          'teams_2026.json 에서 manualAdd: true 항목만 Firestore에 추가합니다.\n\n'
          '기존 팀은 삭제되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('임포트'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final importer = RealTeamDataImporter();
      final result = await importer.importManualEntriesFromAssets();
      if (!mounted) return;
      final message = result.errors.isEmpty
          ? '✅ ${result.summary}'
          : '${result.summary}\n\n미매칭: ${result.errors.take(5).join(", ")}${result.errors.length > 5 ? " 외 ${result.errors.length - 5}건" : ""}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('임포트 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteAll2026Teams() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('2026 팀 전체 삭제'),
        content: const Text(
          'teams 컬렉션의 2026년 팀을 모두 삭제하고,\n'
          'member_year_profiles/2026/users 의 teamIds 필드를 초기화합니다.\n\n'
          '임포트를 다시 실행하기 전에 이 작업을 수행하세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // 1) teams 컬렉션에서 year=2026, churchId=somang 팀 전체 삭제
      final teamsSnap = await firestore
          .collection('teams')
          .where('year', isEqualTo: 2026)
          .where('churchId', isEqualTo: 'somang')
          .get();

      final batch1 = firestore.batch();
      for (final doc in teamsSnap.docs) {
        batch1.delete(doc.reference);
      }
      await batch1.commit();

      // 2) member_year_profiles/2026/users 의 teamIds 필드 제거
      final profilesSnap = await firestore
          .collection('member_year_profiles')
          .doc('2026')
          .collection('users')
          .get();

      // Firestore batch는 500건 제한 — 500건씩 나눠서 처리
      const batchSize = 400;
      for (int i = 0; i < profilesSnap.docs.length; i += batchSize) {
        final chunk = profilesSnap.docs.skip(i).take(batchSize).toList();
        final batch = firestore.batch();
        for (final doc in chunk) {
          batch.update(doc.reference, {'teamIds': FieldValue.delete()});
        }
        await batch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ 팀 ${teamsSnap.docs.length}개 삭제 완료, '
            '프로필 ${profilesSnap.docs.length}건 초기화 완료',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }
}
