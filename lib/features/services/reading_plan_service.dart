import 'models/reading_plan.dart';
import '../../core/utils/date_helper.dart';

class ReadingPlanService {
  /// 특정 날짜가 속한 일정 연도 (완료 데이터 키)
  static int scheduleYearForDate(DateTime date) => DateHelper.getScheduleYear(date);

  Future<ReadingPlan?> getTodaysPlan() async {
    return getPlanForDate(DateTime.now());
  }

  Future<ReadingPlan?> getPlanForDate(DateTime date) async {
    final startDate = DateHelper.getScheduleStartDateForDate(date);

    // 일요일이나 휴식 주는 null 반환
    if (date.weekday == DateTime.sunday ||
        DateHelper.isBreakWeek(date) ||
        date.isBefore(startDate) ||
        DateHelper.isAfterScheduleEnd(date)) {
      return null;
    }

    // 휴식 주를 고려한 조정된 날짜로 일정 계산
    final adjustedDate = DateHelper.getAdjustedDate(date);

    final diffWeeks = adjustedDate.difference(startDate).inDays ~/ 7;
    final currentWeek = diffWeeks + 1;

    if (currentWeek > 45) return null;

    final weekStartDate = startDate.add(Duration(days: diffWeeks * 7));
    final diffDays = adjustedDate.difference(weekStartDate).inDays;
    final currentDay = diffDays + 1;

    return ReadingPlan.calculatePlanForWeekAndDay(
      currentWeek,
      currentDay,
      startDate,
    );
  }
}
