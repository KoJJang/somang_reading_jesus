import 'package:flutter/material.dart';
import '../widgets/reading_card.dart';
import '../widgets/daily_plan.dart';
import '../widgets/weekly_progress_card.dart';
import '../../../data/services/reading_service.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isCompletedToday = false;
  bool _isLoading = true;
  final _readingService = ReadingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _userService = UserService();
  UserProfile? _userProfile;
  bool _isLoadingProfile = true;
  bool get _isAuthenticated => _auth.currentUser != null;
  final _dateFormat = DateFormat('yyyy년 MM월 dd일');
  Map<String, dynamic>? _readingStats;
  DateTime? _lastUpdatedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastUpdatedDate = DateTime.now();
    _checkTodayCompletion();
    _loadUserProfile();
    _loadReadingStats();

    // 앱 내에서 화면 전환 시 호출되는 리스너
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // PageRoute 리스너
      final route = ModalRoute.of(context);
      if (route != null) {
        route.addScopedWillPopCallback(() async {
          _checkForDateChange();
          return true;
        });
      }
    });

    // Listen to authentication state changes
    _auth.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = true;
        });
        _loadUserProfile();
        _checkTodayCompletion();
        _loadReadingStats();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkForDateChange();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 다시 포그라운드로 돌아왔을 때 날짜 변경 확인
    if (state == AppLifecycleState.resumed) {
      _checkForDateChange();
    }
  }

  // 날짜 변경 여부를 확인하고 필요시 데이터 갱신
  void _checkForDateChange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastUpdated =
        _lastUpdatedDate != null
            ? DateTime(
              _lastUpdatedDate!.year,
              _lastUpdatedDate!.month,
              _lastUpdatedDate!.day,
            )
            : null;

    // 날짜가 변경되었거나 처음 로드하는 경우
    if (lastUpdated == null || today.isAfter(lastUpdated)) {
      _lastUpdatedDate = now;
      _checkTodayCompletion();
      _loadReadingStats();
    }
  }

  Future<void> _loadReadingStats() async {
    if (_isAuthenticated) {
      final stats = await _readingService.getReadingStats();
      if (mounted) {
        setState(() {
          _readingStats = stats;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _readingStats = null;
        });
      }
    }
  }

  Future<void> _checkTodayCompletion() async {
    setState(() {
      _isLoading = true;
    });

    final plan = await ReadingPlanService().getTodaysPlan();
    final isCompleted = await _readingService.isCompleted(
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

      setState(() {
        _isLoading = true;
      });

      await _readingService.markAsCompleted(completion);

      if (_isAuthenticated) {
        await _loadReadingStats();
      }

      if (mounted) {
        setState(() {
          _isCompletedToday = true;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오늘의 말씀을 완료했습니다!'),
            duration: Duration(milliseconds: 1500),
            backgroundColor: Color(0xFF059669),
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
            const WeeklyProgressCard(),
            const SizedBox(height: 24),
            const DailyPlan(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
