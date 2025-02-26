import 'package:logger/logger.dart';
import 'package:flutter/material.dart';

class LoggerUtil {
  static final Logger _logger = Logger();

  // 일반 로그
  static void debug(String message) {
    _logger.d(message);
  }

  // 에러 로그
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  // 정보 로그
  static void info(String message) {
    _logger.i(message);
  }

  // 경고 로그
  static void warning(String message) {
    _logger.w(message);
  }

  // 사용자에게 에러 메시지 표시
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
