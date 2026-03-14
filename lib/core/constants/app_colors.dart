import 'package:flutter/material.dart';

class AppColors {
  // ── Primary ──────────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryMuted = Color(0xFF6366F1);   // 태그 텍스트 등 연한 primary
  static const Color accent = Color(0xFF818CF8);         // 도트 하이라이트 등 더 연한 primary
  static const Color primaryLight = Color(0xFFEEF2FF);
  static const Color primaryLighter = Color(0xFFE0E7FF);

  // ── Text ─────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // ── Background / Surface ─────────────────────────────────────
  static const Color background = Color(0xFFF9FAFB);
  static const Color cardBackground = Colors.white;
  static const Color surfaceGray = Color(0xFFF3F4F6);

  // ── Border ───────────────────────────────────────────────────
  static const Color border = Color(0xFFE5E7EB);
  static const Color disabled = Color(0xFFD1D5DB);

  // ── Status: Completed (초록) ──────────────────────────────────
  static const Color completed = Color(0xFF059669);
  static const Color completedLight = Color(0xFFF0FDF4);
  static const Color completedBorder = Color(0xFFBBF7D0);
  static const Color completedSubtle = Color(0xFFD1FAE5);

  // ── Status: Error (빨강) ──────────────────────────────────────
  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFDC2626);      // 에러 스낵바 배경 등

  // ── Status: Warning (노랑/주황) ───────────────────────────────
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color pending = Color(0xFFFCD34D);        // 미완료 dot 등

  // ── Status: Info (파랑) ───────────────────────────────────────
  static const Color info = Color(0xFF3B82F6);

  // ── Calendar ─────────────────────────────────────────────────
  static const Color sundayText = Colors.red;
  static const Color saturdayText = Colors.blue;

  // ── Deprecated (하위 호환 — 새 코드에서 사용 금지) ─────────────
  @Deprecated('Use textTertiary')
  static const Color disabledText = Color(0xFFD1D5DB);
  @Deprecated('Use errorDark')
  static const Color errorBackground = Color(0xFFDC2626);
}
