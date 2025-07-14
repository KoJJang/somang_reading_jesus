import 'package:flutter/material.dart';
import '../widgets/reading_card.dart';
import '../widgets/daily_plan.dart';
import '../widgets/weekly_progress_card.dart';
import '../widgets/weekly_commentary_card.dart';
import '../widgets/daily_explanation_card.dart';
import '../widgets/schedule_card.dart';
import '../widgets/completion_card.dart';
import '../../../data/services/reading_service.dart';
import '../../../features/auth/screens/phone_auth_screen.dart';
import '../../../features/auth/controllers/user_service.dart';
import '../../../features/auth/models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey<WeeklyProgressCardState> _weeklyProgressKey =
      GlobalKey<WeeklyProgressCardState>();
  final _readingService = ReadingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _userService = UserService();
  UserProfile? _userProfile;
  bool _isLoadingProfile = true;
  bool get _isAuthenticated => _auth.currentUser != null;
  Map<String, dynamic>? _readingStats;
  DateTime? _lastUpdatedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastUpdatedDate = DateTime.now();
    _loadUserProfile();
    _loadReadingStats();

    // 앱 내에서 화면 전환 시 호출되는 리스너
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // PageRoute 리스너
      final route = ModalRoute.of(context);
      if (route != null) {
        route.addScopedWillPopCallback(() async {
          _checkForDateChange();
          _refreshAllData();
          return true;
        });
      }

      // 화면에 처음 진입할 때도 데이터 갱신
      _refreshAllData();

      // 화면 포커스 변경 리스너 추가
      FocusManager.instance.addListener(_onFocusChange);
    });

    // Listen to authentication state changes
    _auth.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = true;
        });
        _loadUserProfile();
        _loadReadingStats();
        _weeklyProgressKey.currentState?.loadWeeklyProgress();
      }
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkForDateChange();
    // 화면이 활성화될 때마다 WeeklyProgressCard 갱신
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _weeklyProgressKey.currentState?.loadWeeklyProgress();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 다시 포그라운드로 돌아왔을 때 날짜 변경 확인
    if (state == AppLifecycleState.resumed) {
      _checkForDateChange();
      _refreshAllData();
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

  // 추가: 화면이 다시 포커스를 받을 때 호출될 함수
  void _refreshAllData() {
    _loadReadingStats();
    _weeklyProgressKey.currentState?.loadWeeklyProgress();
  }

  // 화면 포커스 변경 시 호출되는 메서드
  void _onFocusChange() {
    if (FocusManager.instance.primaryFocus != null && mounted) {
      // 앱이 포커스를 받았을 때 데이터 갱신
      _refreshAllData();
    }
  }

  // 완료 상태 변경 시 호출되는 콜백
  void _onCompletionChanged() {
    _loadReadingStats();
    _weeklyProgressKey.currentState?.loadWeeklyProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 오늘의 말씀 카드
            const ReadingCard(),
            const SizedBox(height: 4),
            // 통독 일정과 완료 그리드
            Row(
              children: [
                // 통독 일정
                Expanded(child: ScheduleCard()),
                const SizedBox(width: 4),
                // 완료
                Expanded(
                  child: CompletionCard(
                    onCompletionChanged: _onCompletionChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 주간 해설과 일별 해설 그리드
            Row(
              children: [
                // 주간 해설
                Expanded(child: WeeklyCommentaryCard()),
                const SizedBox(width: 4),
                // 일별 해설
                Expanded(child: DailyExplanationCard()),
              ],
            ),
            const SizedBox(height: 6),
            // 이번 주 진행 현황
            WeeklyProgressCard(key: _weeklyProgressKey),
            const SizedBox(height: 24),
            const DailyPlan(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
