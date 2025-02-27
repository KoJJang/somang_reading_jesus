import 'package:flutter/material.dart';
import '../widgets/reading_card.dart';
import '../widgets/daily_plan.dart';
import '../widgets/history_section.dart';
import '../../../data/services/completion_service.dart';
import '../../../data/models/reading_completion.dart';
import '../../../features/services/reading_plan_service.dart';
import '../../../features/auth/screens/phone_auth_screen.dart';
import '../../../features/auth/controllers/user_service.dart';
import '../../../features/auth/models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCompletedToday = false;
  bool _isLoading = true;
  final _completionService = CompletionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _userService = UserService();
  UserProfile? _userProfile;
  bool _isLoadingProfile = true;
  bool get _isAuthenticated => _auth.currentUser != null;
  final _dateFormat = DateFormat('yyyy년 MM월 dd일');

  @override
  void initState() {
    super.initState();
    _checkTodayCompletion();
    _loadUserProfile();
  }

  Future<void> _checkTodayCompletion() async {
    final plan = await ReadingPlanService().getTodaysPlan();
    final isCompleted = await _completionService.isCompleted(
      ReadingPlanService.startYear,
      plan?.week ?? 0,
      plan?.day ?? 0,
    );
    if (mounted) {
      setState(() {
        _isCompletedToday = isCompleted;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsCompleted() async {
    final plan = await ReadingPlanService().getTodaysPlan();
    if (plan != null) {
      final completion = ReadingCompletion(
        date: DateTime.now(),
        year: DateTime.now().year,
        week: plan.week,
        day: plan.day,
        readings: plan.readings,
      );
      await _completionService.markAsCompleted(completion);
      if (mounted) {
        setState(() {
          _isCompletedToday = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오늘의 말씀을 완료했습니다!'),
            duration: Duration(milliseconds: 500),
          ),
        );
      }
    }
  }

  Future<void> _loadUserProfile() async {
    if (_isAuthenticated) {
      final profile = await _userService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _userProfile = null;
          _isLoadingProfile = false;
        });
      }
    }
  }

  void _navigateToPhoneAuth() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PhoneAuthScreen()),
    );

    if (result == true && mounted) {
      setState(() {
        _isLoadingProfile = true;
      });
      await _loadUserProfile();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증이 완료되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) {
      setState(() {
        _userProfile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그아웃 되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 사용자 인증 상태 표시 및 버튼
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isAuthenticated
                            ? Icons.verified_user
                            : Icons.person_outline,
                        color: _isAuthenticated ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAuthenticated
                                  ? (_isLoadingProfile
                                      ? '인증된 사용자'
                                      : (_userProfile?.name ?? '인증된 사용자'))
                                  : '게스트 사용자',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _isAuthenticated
                                  ? '${_auth.currentUser?.phoneNumber ?? "인증됨"}'
                                  : '휴대폰 인증이 필요합니다',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed:
                            _isAuthenticated ? _signOut : _navigateToPhoneAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isAuthenticated ? Colors.red[100] : Colors.blue,
                          foregroundColor:
                              _isAuthenticated ? Colors.red : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(_isAuthenticated ? '로그아웃' : '인증하기'),
                      ),
                    ],
                  ),

                  // 생년월일 정보 표시 (인증된 사용자이고 프로필이 있는 경우)
                  if (_isAuthenticated &&
                      _userProfile != null &&
                      !_isLoadingProfile)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.cake, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '생년월일: ${_dateFormat.format(_userProfile!.birthDate)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 오늘의 말씀 카드 (이전 디자인)
            const ReadingCard(),
            const SizedBox(height: 4),
            // 통독 일정과 완료 그리드
            Row(
              children: [
                // 통독 일정
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/calendar');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: Color(0xFFFCD34D),
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '통독 일정',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '날짜별 읽기 분량',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // 완료
                Expanded(
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : GestureDetector(
                            onTap: () {
                              if (_isCompletedToday) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('이미 오늘의 말씀을 완료하셨습니다'),
                                    duration: Duration(milliseconds: 500),
                                  ),
                                );
                                return;
                              }
                              _markAsCompleted();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.check_circle_outline,
                                      color:
                                          _isCompletedToday
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF22C55E),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '완료',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          _isCompletedToday
                                              ? const Color(0xFF059669)
                                              : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isCompletedToday
                                        ? '오늘 읽기 완료!'
                                        : '오늘 읽으셨나요?',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 오늘의 말씀 (이전 디자인)
            const DailyPlan(),
            const SizedBox(height: 24),
            const HistorySection(),
          ],
        ),
      ),
    );
  }
}
