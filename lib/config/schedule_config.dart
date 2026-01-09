import 'package:flutter/material.dart';
import '../features/admin/services/admin_schedule_service.dart';

/// 리딩 지저스 일정 설정
///
/// 일정이 변경되거나 휴식 주가 추가될 때 이 파일의 설정을 수정하면 됩니다.
class ScheduleConfig {
  // --- Dynamic Config Support (New) ---
  static final Map<int, ScheduleConfigData> _dynamicConfigs = {};

  static void setDynamicConfig(int year, ScheduleConfigData? data) {
    if (data != null) {
      _dynamicConfigs[year] = data;
    } else {
      _dynamicConfigs.remove(year);
    }
  }

  static ScheduleConfigData? getDynamicConfig(int year) =>
      _dynamicConfigs[year];

  /// 통독 일정 정의
  ///
  /// - `year`: 일정 식별 연도 (완료 데이터 키에도 사용)
  /// - `startDate`: 해당 연도 통독 시작일
  /// - `breakWeeks`: 휴식 주 (해당 주 전체를 휴식으로 처리; 일요일 포함 7일)
  // ------------------------------------

  static List<int> get availableYears {
    // 동적 설정 연도 반환
    final years = _dynamicConfigs.keys.toList()..sort();
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
      final DateTime start = _normalize(getStartDateForYear(year));
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
      final DateTime start = _normalize(getStartDateForYear(year));
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

  /// (호환용) "현재 날짜" 기준 일정 시작일
  static DateTime get startDate => getStartDateForDate(DateTime.now());

  /// (호환용) "현재 날짜" 기준 휴식 주 목록
  static List<DateTime> get breakWeeks => getBreakWeeksForDate(DateTime.now());

  static DateTime getStartDateForYear(int year) {
    if (_dynamicConfigs.containsKey(year)) {
      return _dynamicConfigs[year]!.startDate;
    }
    // 폴백: 해당 연도 1월 1일 (설정 없음)
    return DateTime(year, 1, 1);
  }

  static DateTime getStartDateForDate(DateTime date) {
    return getStartDateForYear(getScheduleYearForDate(date));
  }

  static List<DateTime> getBreakWeeksForYear(int year) {
    // 동적 설정에서는 breakWeeks 개념 대신 holidays를 사용하므로
    // 이 메서드는 더 이상 유효한 breakWeeks를 반환하지 않습니다. (호환성 유지용 빈 리스트)
    return [];
  }

  static List<DateTime> getBreakWeeksForDate(DateTime date) {
    return getBreakWeeksForYear(getScheduleYearForDate(date));
  }

  /// 특정 날짜가 휴식 주에 해당하는지 확인
  static bool isBreakWeek(DateTime date) {
    final year = getScheduleYearForDate(date);
    final dynamicConfig = _dynamicConfigs[year];

    if (dynamicConfig != null) {
      // 동적 설정 (Integer comparison fix 적용)
      final targetScore = date.year * 10000 + date.month * 100 + date.day;
      if (date.weekday == DateTime.sunday) {
        return false;
      }
      for (final range in dynamicConfig.holidays) {
        final startScore =
            range.start.year * 10000 +
            range.start.month * 100 +
            range.start.day;
        final endScore =
            range.end.year * 10000 + range.end.month * 100 + range.end.day;

        if (targetScore >= startScore && targetScore <= endScore) {
          return true;
        }
      }
      return false;
    }

    // 설정 없음: 일요일만 제외하고 BreakWeek 아님
    return false;
  }

  /// 휴식 주를 고려한 실제 읽기 날짜 계산
  static DateTime getAdjustedDate(DateTime date) {
    // 동적 설정 시스템에서는 별도의 '휴식 주' 차감 로직이 필요 없음.
    // ReadingPlanService에서 인덱스 기반으로 날짜를 처리함.
    return date;
  }

  /// 오프셋이 적용된 오늘 날짜 계산
  static DateTime getAdjustedToday() {
    return getAdjustedDate(DateTime.now());
  }

  /// 일정 종료일 계산 (270번째 읽기 날짜)
  static DateTime getScheduleEndDateForYear(int year) {
    if (_dynamicConfigs.containsKey(year)) {
      final config = _dynamicConfigs[year]!;
      return _getDateForReadingIndex(269, config.startDate, config.holidays);
    }

    // 설정이 없는 경우: 1월 1일 시작 가정, 45주(270일) 뒤 종료
    final startDate = DateTime(year, 1, 1);
    // 45주 * 7일 중 일요일 45개 제외, 휴일 없음 가정 -> 대략적으로 계산
    // 정확히는 _getDateForReadingIndex를 빈 공휴일 목록으로 호출하여 계산
    return _getDateForReadingIndex(269, startDate, []);
  }

  static DateTime _getDateForReadingIndex(
    int index,
    DateTime startDate,
    List<DateTimeRange> holidays,
  ) {
    int validDaysFound = 0;
    DateTime current = _normalize(startDate);

    while (true) {
      bool isReadingDay =
          current.weekday >= DateTime.monday &&
          current.weekday <= DateTime.saturday;
      if (isReadingDay) {
        bool isHoliday = false;
        // Integer comparison fix inside dynamic helper
        final currentScore =
            current.year * 10000 + current.month * 100 + current.day;
        for (final range in holidays) {
          final startScore =
              range.start.year * 10000 +
              range.start.month * 100 +
              range.start.day;
          final endScore =
              range.end.year * 10000 + range.end.month * 100 + range.end.day;

          if (currentScore >= startScore && currentScore <= endScore) {
            isHoliday = true;
            break;
          }
        }
        if (!isHoliday) {
          if (validDaysFound == index) return current;
          validDaysFound++;
        }
      }
      current = current.add(const Duration(days: 1));

      // 무한 루프 방지 (약 2년 뒤까지만 체크)
      if (current.isAfter(startDate.add(const Duration(days: 730)))) {
        return current;
      }
    }
  }

  static DateTime getScheduleEndDateForDate(DateTime date) =>
      getScheduleEndDateForYear(getScheduleYearForDate(date));

  /// (호환용) "현재 날짜" 기준 일정 종료일
  static DateTime getScheduleEndDate() =>
      getScheduleEndDateForDate(DateTime.now());

  /// 특정 날짜가 일정 종료 후인지 확인
  static bool isAfterScheduleEnd(DateTime date) {
    final normalizedDate = _normalize(date);
    final endDate = getScheduleEndDateForDate(date);
    final normalizedEnd = _normalize(endDate);
    return normalizedDate.isAfter(normalizedEnd);
  }

  /// 특정 날짜가 해당 연도 통독 시작 전인지 확인
  static bool isBeforeScheduleStart(DateTime date) {
    final normalizedDate = _normalize(date);
    final startDate = getStartDateForDate(date);
    final normalizedStart = _normalize(startDate);
    return normalizedDate.isBefore(normalizedStart);
  }
}
