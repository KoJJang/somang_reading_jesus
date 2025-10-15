import '../../config/schedule_config.dart';

/// 날짜 관련 유틸리티 클래스
///
/// 휴식 주를 고려한 날짜 계산을 중앙에서 관리합니다.
class DateHelper {
  /// 특정 날짜가 휴식 주인지 확인
  static bool isBreakWeek(DateTime date) {
    return ScheduleConfig.isBreakWeek(date);
  }

  /// 휴식 주를 고려한 조정된 날짜 계산
  ///
  /// CSV에서 데이터를 찾을 때 사용합니다.
  /// 예: 10/15 → 10/1 (2주 휴식 반영)
  static DateTime getAdjustedDate(DateTime date) {
    return ScheduleConfig.getAdjustedDate(date);
  }

  /// 오늘 날짜의 조정된 날짜
  static DateTime getAdjustedToday() {
    return ScheduleConfig.getAdjustedToday();
  }

  /// 이번 주 월요일 날짜 계산
  static DateTime getThisWeekMonday() {
    final now = DateTime.now();
    // 일요일(7)이면 이전 주 월요일
    if (now.weekday == DateTime.sunday) {
      return now.subtract(const Duration(days: 6));
    }
    return now.subtract(Duration(days: now.weekday - 1));
  }

  /// 특정 주의 월요일 날짜 계산
  static DateTime getMondayOfWeek(DateTime date) {
    if (date.weekday == DateTime.sunday) {
      return date.subtract(const Duration(days: 6));
    }
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// 날짜 비교 (년/월/일만)
  static bool isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// 시작일
  static DateTime get startDate => ScheduleConfig.startDate;

  /// 휴식 주 목록
  static List<DateTime> get breakWeeks => ScheduleConfig.breakWeeks;
}
