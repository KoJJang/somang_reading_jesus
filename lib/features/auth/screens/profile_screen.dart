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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadLastSyncTime();

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
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다')));
      }
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

                    // 로그아웃 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _signOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('로그아웃'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
