import 'package:flutter/material.dart';

class AppTheme {
  // 기본 색상들 정의
  static const Color primaryColor = Colors.blue;
  static const Color secondaryColor = Colors.blueAccent;
  static const Color errorColor = Colors.red;
  static const Color backgroundColor = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: 'Pretendard',
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
