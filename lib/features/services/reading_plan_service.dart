import 'models/reading_plan.dart';
import '../../config/schedule_config.dart';

class ReadingPlanService {
  static final DateTime _startDate = DateTime(2025, 1, 20);

  static int get startYear => _startDate.year;

  Future<ReadingPlan?> getTodaysPlan() async {
    return ReadingPlan.calculateCurrentPlan(_startDate);
  }

  Future<ReadingPlan?> getPlanForDate(DateTime date) async {
    // 일요일이나 휴식 주는 null 반환
    if (date.weekday == DateTime.sunday || 
        ScheduleConfig.isBreakWeek(date) || 
        date.isBefore(_startDate)) {
      return null;
    }

    // CSV가 이미 휴식 주를 반영하고 있으므로 날짜 그대로 사용
    final diffWeeks = date.difference(_startDate).inDays ~/ 7;
    final currentWeek = diffWeeks + 1;

    if (currentWeek > 45) return null;

    final weekStartDate = _startDate.add(Duration(days: diffWeeks * 7));
    final diffDays = date.difference(weekStartDate).inDays;
    final currentDay = diffDays + 1;

    return ReadingPlan.calculatePlanForWeekAndDay(
      currentWeek,
      currentDay,
      _startDate,
    );
  }
}
