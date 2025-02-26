import 'models/reading_plan.dart';

class ReadingPlanService {
  static final DateTime _startDate = DateTime(2025, 1, 20);

  static int get startYear => _startDate.year;

  Future<ReadingPlan?> getTodaysPlan() async {
    return ReadingPlan.calculateCurrentPlan(_startDate);
  }

  Future<ReadingPlan?> getPlanForDate(DateTime date) async {
    if (date.weekday == DateTime.sunday || date.isBefore(_startDate)) {
      return null;
    }

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
