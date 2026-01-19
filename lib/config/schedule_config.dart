/// 리딩 지저스 일정 설정
///
/// 일정이 변경되거나 휴식 주가 추가될 때 이 파일의 설정을 수정하면 됩니다.
class ScheduleConfig {
  /// 통독 일정 정의
  ///
  /// - `year`: 일정 식별 연도 (완료 데이터 키에도 사용)
  /// - `startDate`: 해당 연도 통독 시작일
  /// - `breakWeeks`: 휴식 주 (해당 주 전체를 휴식으로 처리; 일요일 포함 7일)
  static Map<int, _ReadingSchedule> _schedules = {
    2025: _ReadingSchedule(
      year: 2025,
      startDate: DateTime(2025, 1, 20),
      breakWeeks: [
        DateTime(2025, 8, 3), // 1차 휴식 주 (8/3 ~ 8/9)
        DateTime(2025, 10, 5), // 2차 휴식 주 (10/5 ~ 10/11)
      ],
    ),
    2026: _ReadingSchedule(
      year: 2026,
      startDate: DateTime(2026, 1, 19), // 2026 시작: 1/19 주간
      breakWeeks: [
        DateTime(2026, 2, 16), // 2/16 주차
        DateTime(2026, 7, 27), // 7/27 주차
        DateTime(2026, 9, 21), // 9/21 주차
      ],
    ),
  };

  static void updateFromRemote(List<ScheduleConfigEntry> entries) {
    if (entries.isEmpty) {
      return;
    }
    final Map<int, _ReadingSchedule> updates = {
      for (final ScheduleConfigEntry entry in entries)
        entry.year: _ReadingSchedule(
          year: entry.year,
          startDate: entry.startDate,
          breakWeeks: entry.breakWeeks,
        ),
    };
    _schedules = {..._schedules, ...updates};
  }

  static List<int> get availableYears {
    final years = _schedules.keys.toList()..sort();
    return years;
  }

  static DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 특정 날짜가 속한 "스케줄 연도" 계산
  ///
  /// - 스케줄이 다음 해까지 이어질 수 있으므로 `date.year`를 그대로 쓰면 틀릴 수 있습니다.
  /// - 예: 2025 스케줄이 2026년 1월까지 이어지면, 2026-01-05는 "2025 스케줄"에 속합니다.
  static int getScheduleYearForDate(DateTime date) {
    final List<int> years = availableYears;
    if (years.isEmpty) {
      return date.year;
    }

    final DateTime normalizedDate = _normalize(date);

    // 1) 스케줄 범위(start~end)에 포함되는 연도가 있으면 그 연도를 반환
    for (final int year in years) {
      final _ReadingSchedule schedule = _scheduleForYear(year);
      final DateTime start = _normalize(schedule.startDate);
      final DateTime end = _normalize(getScheduleEndDateForYear(year));
      final bool isAfterOrSameStart =
          normalizedDate.isAtSameMomentAs(start) ||
          normalizedDate.isAfter(start);
      final bool isBeforeOrSameEnd =
          normalizedDate.isAtSameMomentAs(end) || normalizedDate.isBefore(end);
      if (isAfterOrSameStart && isBeforeOrSameEnd) {
        return year;
      }
    }

    // 2) 어떤 범위에도 속하지 않으면, startDate가 가장 가까운 "이전" 스케줄을 선택
    int? bestYear;
    DateTime? bestStart;
    for (final int year in years) {
      final DateTime start = _normalize(_scheduleForYear(year).startDate);
      if (start.isAfter(normalizedDate)) {
        continue;
      }
      if (bestStart == null || start.isAfter(bestStart)) {
        bestStart = start;
        bestYear = year;
      }
    }

    // 3) 날짜가 모든 스케줄 시작일보다 이전이면 가장 첫 스케줄로 fallback
    return bestYear ?? years.first;
  }

  static _ReadingSchedule _scheduleForYear(int year) {
    // 지정된 연도가 없으면 가장 오래된 일정으로 fallback (앱 크래시 방지)
    return _schedules[year] ?? _schedules[availableYears.first]!;
  }

  static _ReadingSchedule _scheduleForDate(DateTime date) {
    return _scheduleForYear(getScheduleYearForDate(date));
  }

  /// (호환용) "현재 날짜" 기준 일정 시작일
  static DateTime get startDate => getStartDateForDate(DateTime.now());

  /// (호환용) "현재 날짜" 기준 휴식 주 목록
  static List<DateTime> get breakWeeks => getBreakWeeksForDate(DateTime.now());

  static DateTime getStartDateForYear(int year) =>
      _scheduleForYear(year).startDate;

  static DateTime getStartDateForDate(DateTime date) =>
      _scheduleForDate(date).startDate;

  static List<DateTime> getBreakWeeksForYear(int year) =>
      _scheduleForYear(year).breakWeeks;

  static List<DateTime> getBreakWeeksForDate(DateTime date) =>
      _scheduleForDate(date).breakWeeks;

  /// 특정 날짜가 휴식 주에 해당하는지 확인
  static bool isBreakWeek(DateTime date) {
    final breakWeeks = getBreakWeeksForDate(date);

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
    final breakWeeks = getBreakWeeksForDate(date);
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

  /// 일정 종료일 계산 (45주차 마지막 날)
  ///
  /// 45주차의 마지막 읽기 날짜 (금요일)
  static DateTime getScheduleEndDateForYear(int year) {
    final schedule = _scheduleForYear(year);
    final startDate = schedule.startDate;
    // 45주차 월요일 = 시작일 + 44주(308일)
    final week45Monday = startDate.add(const Duration(days: 44 * 7));
    // 45주차 금요일 = 월요일 + 4일 (월화수목금)
    final week45Friday = week45Monday.add(const Duration(days: 4));

    // 휴식 주 일수 추가
    final totalBreakDays = schedule.breakWeeks.length * 7;

    return week45Friday.add(Duration(days: totalBreakDays));
  }

  static DateTime getScheduleEndDateForDate(DateTime date) =>
      getScheduleEndDateForYear(_scheduleForDate(date).year);

  /// (호환용) "현재 날짜" 기준 일정 종료일
  static DateTime getScheduleEndDate() =>
      getScheduleEndDateForDate(DateTime.now());

  /// 특정 날짜가 일정 종료 후인지 확인
  static bool isAfterScheduleEnd(DateTime date) {
    final endDate = getScheduleEndDateForDate(date);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

    return normalizedDate.isAfter(normalizedEnd);
  }

  /// 특정 날짜가 해당 연도 통독 시작 전인지 확인
  static bool isBeforeScheduleStart(DateTime date) {
    final startDate = getStartDateForDate(date);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    return normalizedDate.isBefore(normalizedStart);
  }
}

class _ReadingSchedule {
  final int year;
  final DateTime startDate;
  final List<DateTime> breakWeeks;

  const _ReadingSchedule({
    required this.year,
    required this.startDate,
    required this.breakWeeks,
  });
}

class ScheduleConfigEntry {
  final int year;
  final DateTime startDate;
  final List<DateTime> breakWeeks;

  const ScheduleConfigEntry({
    required this.year,
    required this.startDate,
    required this.breakWeeks,
  });
}
