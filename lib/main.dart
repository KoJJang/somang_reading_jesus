import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:reading_jesus_somang/features/home/screens/home_screen.dart';
import 'package:reading_jesus_somang/core/constants/theme.dart';
import 'package:reading_jesus_somang/features/layout/app_layout.dart';
import 'package:reading_jesus_somang/data/services/database_service.dart';
import 'package:reading_jesus_somang/data/repositories/local_reading_repository.dart';
import 'package:reading_jesus_somang/data/services/reading_service.dart';
import 'package:reading_jesus_somang/data/services/schedule_config_service.dart';
import 'package:reading_jesus_somang/core/services/notification_service.dart';
import 'package:reading_jesus_somang/features/calendar/screens/calendar_screen.dart';
import 'package:reading_jesus_somang/features/auth/screens/phone_auth_screen.dart';
import 'package:reading_jesus_somang/features/auth/screens/profile_completion_screen.dart';
import 'package:reading_jesus_somang/features/auth/screens/profile_screen.dart';
import 'package:reading_jesus_somang/features/auth/screens/privacy_policy_screen.dart';
import 'package:reading_jesus_somang/features/team/screens/my_teams_screen.dart';
import 'firebase_options.dart';

void main() async {
  // Flutter 엔진과 위젯 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 릴리즈 모드에서는 에러만 출력하도록 설정
  if (kReleaseMode) {
    // 디버그 출력 비활성화
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Firebase 초기화
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      Firebase.app(); // 이미 초기화된 앱 인스턴스를 가져옴
    }
  } catch (e) {
    debugPrint('Firebase 초기화 오류: $e');
  }

  // 알림 서비스 초기화
  await NotificationService.instance.initialize();

  // Load remote schedule configs; fall back to local defaults on failure.
  await ScheduleConfigService().loadRemoteConfigs();

  // 데이터베이스 서비스 초기화
  final dbService = DatabaseService();
  await dbService.initialize();

  // 로컬 저장소 초기화 (마이그레이션 실행)
  final localRepo = LocalReadingRepository();
  await localRepo.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final ReadingService _readingService;

  @override
  void initState() {
    super.initState();
    _readingService = ReadingService();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readingService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 백그라운드로 이동하거나 종료될 때 리소스 정리
    if (state == AppLifecycleState.detached) {
      _readingService.dispose();
    }
    // 앱이 다시 포그라운드로 돌아왔을 때 동기화 시도
    else if (state == AppLifecycleState.resumed &&
        _readingService.isAuthenticated) {
      // 앱이 다시 포그라운드로 왔을 때 동기화 시도 (Firebase에서 데이터 가져오기)
      _readingService.syncFromFirebase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '성경 통독',
      theme: AppTheme.themeData,
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) {
        final Widget safeChild = child ?? const SizedBox.shrink();
        if (kIsWeb || !Platform.isAndroid) return safeChild;
        final MediaQueryData data = MediaQuery.of(context);
        final double scaleFactor = data.textScaleFactor;
        final double clampedScaleFactor =
            scaleFactor.clamp(1.0, 1.2).toDouble();
        return MediaQuery(
          data: data.copyWith(textScaleFactor: clampedScaleFactor),
          child: safeChild,
        );
      },
      home: const AppLayout(child: HomeScreen()),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      const AppLayout(child: HomeScreen()),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return child;
              },
              settings: settings,
            );
          case '/calendar':
            return MaterialPageRoute(
              builder: (context) => const CalendarScreen(),
            );
          case '/phone-auth':
            return MaterialPageRoute(
              builder: (context) => const PhoneAuthScreen(),
            );
          case '/profile-completion':
            return MaterialPageRoute(
              builder: (context) => const ProfileCompletionScreen(),
            );
          case '/profile':
            return MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            );
          case '/privacy-policy':
            return MaterialPageRoute(
              builder: (context) => const PrivacyPolicyScreen(),
            );
          case '/my-teams':
            return MaterialPageRoute(
              builder: (context) => const MyTeamsScreen(),
            );
          default:
            return null;
        }
      },
    );
  }
}
