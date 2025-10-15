/// 리딩 지저스 일정 설정
///
/// 일정이 변경되거나 휴식 주가 추가될 때 이 파일의 설정을 수정하면 됩니다.
class ScheduleConfig {
  /// 일정 시작일
  /// 리딩 지저스가 시작된 날짜
  static final DateTime startDate = DateTime(2025, 1, 20);

  /// 휴식 주 설정
  ///
  /// 각 항목은 휴식 주의 시작일을 나타냅니다.
  /// 월요일부터 토요일까지 전체 주가 휴식으로 처리됩니다.
  ///
  /// 예시:
  /// - DateTime(2025, 8, 3): 8월 3일이 속한 주(8/3 월요일 ~ 8/9 일요일)가 휴식
  /// - DateTime(2025, 10, 5): 10월 5일이 속한 주(10/5 일요일 포함)가 휴식
  static final List<DateTime> breakWeeks = [
    DateTime(2025, 8, 3), // 1차 휴식 주 (8/3 ~ 8/9)
    DateTime(2025, 10, 5), // 2차 휴식 주 (10/5 ~ 10/11)
    // DateTime(2025, 10, 12), // 3차 휴식 주 (10/12 ~ 10/18)
  ];

  /// 특정 날짜가 휴식 주에 해당하는지 확인
  static bool isBreakWeek(DateTime date) {
    // 일요일은 원래 쉬는 날이므로 휴식 주 체크 불필요
    if (date.weekday == DateTime.sunday) {
      return false;
    }

    for (final breakWeek in breakWeeks) {
      // 해당 주의 월요일 찾기
      final weekStart = _getWeekStart(breakWeek);
      final weekEnd = weekStart.add(const Duration(days: 5)); // 토요일까지 (월~토)

      // 날짜를 자정 기준으로 정규화
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final normalizedStart = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );
      final normalizedEnd = DateTime(weekEnd.year, weekEnd.month, weekEnd.day);

      if ((normalizedDate.isAtSameMomentAs(normalizedStart) ||
              normalizedDate.isAfter(normalizedStart)) &&
          (normalizedDate.isAtSameMomentAs(normalizedEnd) ||
              normalizedDate.isBefore(normalizedEnd))) {
        return true;
      }
    }
    return false;
  }

  /// 주의 시작일(월요일) 계산
  static DateTime _getWeekStart(DateTime date) {
    // 일요일(7)이면 다음 날(월요일)
    if (date.weekday == DateTime.sunday) {
      return date.add(const Duration(days: 1));
    }
    // 월요일(1)이 아니면 해당 주 월요일로 이동
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// 휴식 주를 고려한 실제 읽기 날짜 계산
  ///
  /// 현재 날짜에서 그 이전의 휴식 주 수를 빼서 실제 읽어야 할 날짜를 계산합니다.
  static DateTime getAdjustedDate(DateTime date) {
    int breakDaysToSubtract = 0;

    // 날짜 이전의 모든 휴식 주를 카운트
    for (final breakWeek in breakWeeks) {
      final weekStart = _getWeekStart(breakWeek);
      final weekEnd = weekStart.add(const Duration(days: 6)); // 일요일까지 (월~일)

      // 휴식 주 전체(일요일 포함)가 현재 날짜보다 이전이면 7일을 뺌
      if (weekEnd.isBefore(date)) {
        breakDaysToSubtract += 7; // 일~토 7일 (일요일 포함 전체 주)
      }
    }

    return date.subtract(Duration(days: breakDaysToSubtract));
  }

  /// 오프셋이 적용된 오늘 날짜 계산
  static DateTime getAdjustedToday() {
    return getAdjustedDate(DateTime.now());
  }
}
