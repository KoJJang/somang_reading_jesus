import '../../../data/models/reading_schedule.dart';

class ReadingPlan {
  final int week;
  final int volume;
  final int chapter;
  final int day;
  final List<Map<String, dynamic>> readings;

  ReadingPlan({
    required this.week,
    required this.volume,
    required this.chapter,
    required this.day,
    required this.readings,
  });

  static ReadingPlan? calculateCurrentPlan(DateTime startDate) {
    final now = DateTime.now();
    if (now.weekday == DateTime.sunday) return null;

    final diffWeeks = now.difference(startDate).inDays ~/ 7;
    final currentWeek = diffWeeks + 1;
    if (currentWeek > 45) return null;

    final weekStartDate = startDate.add(Duration(days: diffWeeks * 7));
    final diffDays = now.difference(weekStartDate).inDays;
    final currentDay = diffDays + 1;

    final readings = ReadingSchedule.getReadingsByWeekAndDay(
      currentWeek,
      currentDay,
    );
    if (readings == null) return null;

    final volume = ((currentWeek - 1) ~/ 15) + 1;
    final chapter = ((currentWeek - 1) % 15) + 1;

    return ReadingPlan(
      week: currentWeek,
      volume: volume,
      chapter: chapter,
      day: currentDay,
      readings: readings,
    );
  }

  static ReadingPlan? calculatePlanForWeekAndDay(
    int week,
    int day,
    DateTime startDate,
  ) {
    if (day > 6 || week > 45) return null;

    final readings = ReadingSchedule.getReadingsByWeekAndDay(week, day);
    if (readings == null) return null;

    final volume = ((week - 1) ~/ 15) + 1;
    final chapter = ((week - 1) % 15) + 1;

    return ReadingPlan(
      week: week,
      volume: volume,
      chapter: chapter,
      day: day,
      readings: readings,
    );
  }
}
