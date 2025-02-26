import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:reading_jesus_somang/features/home/screens/home_screen.dart';
import 'package:reading_jesus_somang/core/constants/theme.dart';
import 'package:reading_jesus_somang/features/layout/app_layout.dart';
import 'package:reading_jesus_somang/data/services/database_service.dart';
import 'package:reading_jesus_somang/features/bible/screens/bible_reading_screen.dart';
import 'package:reading_jesus_somang/features/calendar/screens/calendar_screen.dart';
// import 'firebase_options.dart';

void main() async {
  // Flutter 엔진과 위젯 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 데이터베이스 서비스 초기화
  final dbService = DatabaseService();
  await dbService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '성경 통독',
      theme: AppTheme.lightTheme,
      home: const AppLayout(child: HomeScreen()),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/bible':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder:
                  (context) => BibleReadingScreen(
                    book: args['book'],
                    chapter: args['chapter'],
                    endChapter: args['endChapter'],
                    readings: args['readings'] as List<Map<String, dynamic>>,
                  ),
            );
          case '/calendar':
            return MaterialPageRoute(
              builder: (context) => const CalendarScreen(),
            );
          default:
            return null;
        }
      },
    );
  }
}
