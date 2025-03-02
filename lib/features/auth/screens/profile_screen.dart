import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../controllers/user_service.dart';
import '../models/user_profile.dart';
import '../../../core/constants/theme.dart';
import '../../../data/services/reading_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService = UserService();
  final _readingService = ReadingService();
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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    // Listen to authentication state changes
    _auth.authStateChanges().listen((User? user) {
      if (mounted) {
        if (user == null) {
          // User logged out, navigate back safely
          if (Navigator.of(context).canPop()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pop();
            });
          }
        } else {
          // User logged in, refresh profile
          _loadUserProfile();
        }
      }
    });
  }

  @override
  void dispose() {
    // 타이머 정리
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    if (_auth.currentUser != null) {
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
          _userProfile = null;
          _isLoading = false;
        });

        // No need to navigate or show snackbar here
        // The authStateChanges listener will handle navigation for unauthenticated users
      }
    }
  }

  // 쿨다운 타이머 시작
  void _startCooldownTimer() {
    // 기존 타이머 취소
    _cooldownTimer?.cancel();

    // 남은 시간 계산
    _updateRemainingCooldown();

    // 타이머 시작 (1초마다 업데이트)
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateRemainingCooldown();

        // 쿨다운이 끝나면 타이머 종료
        if (_remainingCooldown <= 0) {
          timer.cancel();
          setState(() {}); // UI 갱신하여 버튼 활성화
        }
      } else {
        timer.cancel(); // 위젯이 dispose 되었으면 타이머 종료
      }
    });
  }

  // 남은 쿨다운 시간 업데이트
  void _updateRemainingCooldown() {
    if (_lastSyncTime != null) {
      final elapsed = DateTime.now().difference(_lastSyncTime!).inSeconds;
      final remaining = _syncCooldownSeconds - elapsed;

      setState(() {
        _remainingCooldown = remaining > 0 ? remaining : 0;
      });
    } else {
      setState(() {
        _remainingCooldown = 0;
      });
    }
  }

  // 동기화 버튼이 활성화되어 있는지 확인
  bool get _isSyncButtonEnabled {
    if (_isSyncing) return false;
    if (_remainingCooldown > 0) return false;
    return true;
  }

  Future<void> _syncReadingData() async {
    // 현재 동기화 중이면 중복 실행 방지
    if (_isSyncing) return;

    // 쿨다운 시간 체크
    if (_lastSyncTime != null) {
      final timeSinceLastSync =
          DateTime.now().difference(_lastSyncTime!).inSeconds;
      if (timeSinceLastSync < _syncCooldownSeconds) {
        // 쿨다운 중이면 사용자에게 알림
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_syncCooldownSeconds - timeSinceLastSync}초 후에 다시 시도해주세요',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    // 사용자가 로그인되어 있는지 확인
    if (_auth.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('동기화하려면 로그인이 필요합니다'),
            backgroundColor: Colors.red,
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
      await _readingService.syncData();

      // 마지막 동기화 시간 업데이트
      _lastSyncTime = DateTime.now();

      // 쿨다운 타이머 시작
      _startCooldownTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('데이터가 성공적으로 동기화되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동기화 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
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
    // Sign out without navigating directly
    await _auth.signOut();

    // Only show snackbar, let the auth state listener handle navigation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그아웃 되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );

      // No explicit navigation here - authStateChanges listener will handle it
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 프로필'),
        actions: [
          // 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _signOut,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userProfile == null
              ? const Center(child: Text('프로필 정보가 없습니다'))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 프로필 이미지
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, size: 70, color: Colors.white),
                    ),
                    const SizedBox(height: 24),

                    // 사용자 이름
                    Text(
                      _userProfile!.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 전화번호
                    Text(
                      _userProfile!.phoneNumber,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),

                    // 프로필 정보 카드
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '기본 정보',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 생년월일
                          _buildProfileItem(
                            Icons.cake,
                            '생년월일',
                            _dateFormat.format(_userProfile!.birthDate),
                          ),

                          const Divider(height: 24),

                          // 계정 생성일
                          _buildProfileItem(
                            Icons.calendar_today,
                            '가입일',
                            _dateFormat.format(_userProfile!.createdAt),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 버튼 행 (프로필 수정과 데이터 동기화 버튼)
                    Row(
                      children: [
                        // 프로필 수정 버튼
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // 프로필 수정 화면으로 이동
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(
                              //     builder: (context) => EditProfileScreen(profile: _userProfile),
                              //   ),
                              // );
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('프로필 수정'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // 데이터 동기화 버튼
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _isSyncButtonEnabled ? _syncReadingData : null,
                            icon:
                                _isSyncing
                                    ? Container(
                                      width: 24,
                                      height: 24,
                                      padding: const EdgeInsets.all(2.0),
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.sync),
                            label: Text(
                              _isSyncing
                                  ? '동기화 중...'
                                  : _remainingCooldown > 0
                                  ? '동기화 (${_remainingCooldown}s)'
                                  : '데이터 동기화',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              disabledBackgroundColor: Colors.grey.shade400,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}
