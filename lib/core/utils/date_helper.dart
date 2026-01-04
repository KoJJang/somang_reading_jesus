import 'package:flutter/material.dart';
import '../../config/schedule_config.dart';

/// 날짜 관련 유틸리티 클래스
///
/// 휴식 주를 고려한 날짜 계산을 중앙에서 관리합니다.
class DateHelper {
  /// 사용 가능한 일정 연도 목록 (예: 2025, 2026)
  static List<int> get availableScheduleYears => ScheduleConfig.availableYears;

  /// 특정 날짜가 속한 일정 연도
  static int getScheduleYear(DateTime date) =>
      ScheduleConfig.getScheduleYearForDate(date);

  /// 특정 연도의 일정 시작일
  static DateTime getScheduleStartDateForYear(int year) =>
      ScheduleConfig.getStartDateForYear(year);

  /// 특정 날짜(연도)의 일정 시작일
  static DateTime getScheduleStartDateForDate(DateTime date) =>
      ScheduleConfig.getStartDateForDate(date);

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

  /// 일정 종료일
  static DateTime getScheduleEndDate() => ScheduleConfig.getScheduleEndDate();

  /// 특정 연도의 일정 종료일
  static DateTime getScheduleEndDateForYear(int year) =>
      ScheduleConfig.getScheduleEndDateForYear(year);

  /// 특정 날짜가 일정 종료 후인지 확인
  static bool isAfterScheduleEnd(DateTime date) =>
      ScheduleConfig.isAfterScheduleEnd(date);

  /// 특정 날짜가 해당 연도 통독 시작 전인지 확인
  static bool isBeforeScheduleStart(DateTime date) =>
      ScheduleConfig.isBeforeScheduleStart(date);

  /// 시작일로부터 특정 날짜까지의 '실제 읽기 가능일' 수 계산 (연속 인덱스)
  /// 월~금만 포함하며, 휴일 목록에 포함된 날은 제외합니다.
  static int getReadingIndex(
    DateTime targetDate,
    DateTime startDate,
    List<DateTimeRange> holidays,
  ) {
    if (targetDate.isBefore(startDate)) return -1;

    int readingDays = 0;
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedTarget = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    while (!current.isAfter(normalizedTarget)) {
      // 월~토(1~6) 인지 확인
      bool isReadingDay =
          current.weekday >= DateTime.monday &&
          current.weekday <= DateTime.saturday;

      if (isReadingDay) {
        // 휴일인지 확인 (범위 체크)
        bool isHoliday = false;
        for (final range in holidays) {
          final normalizedStart = DateTime(
            range.start.year,
            range.start.month,
            range.start.day,
          );
          final normalizedEnd = DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
          );

          if ((current.isAtSameMomentAs(normalizedStart) ||
                  current.isAfter(normalizedStart)) &&
              (current.isAtSameMomentAs(normalizedEnd) ||
                  current.isBefore(normalizedEnd))) {
            isHoliday = true;
            break;
          }
        }

        if (!isHoliday) {
          // 타겟 날짜 당일이면 그 전까지의 개수 + 1이 아니라,
          // 0-based index를 위해 현재까지의 readingDays를 반환하고 루프 종료 가능
          // 하지만 여기서는 전체 개수를 세고 마지막에 -1 하는 방식이 더 명확할 수 있음
          readingDays++;
        }
      }
      current = current.add(const Duration(days: 1));
    }

    return readingDays - 1; // 0-based index
  }
}
