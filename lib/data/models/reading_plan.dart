import 'reading_schedule.dart';

class ReadingPlan {
  final int week; // 주차 (1-45)
  final int volume; // 권 (1-6)
  final int chapter; // 강 (1-7)
  final int day; // 일차 (1-6)
  final String bookName; // 책 이름
  final int startChapter; // 시작 장
  final int endChapter; // 끝 장

  ReadingPlan({
    required this.week,
    required this.volume,
    required this.chapter,
    required this.day,
    required this.bookName,
    required this.startChapter,
    required this.endChapter,
  });

  // 현재 날짜 기준으로 오늘의 읽기 계획 계산
  static ReadingPlan? calculateCurrentPlan(DateTime startDate) {
    final now = DateTime.now();

    // 일요일이면 null 반환
    if (now.weekday == DateTime.sunday) return null;

    // 시작일로부터 경과된 주 수 계산
    final diffWeeks = now.difference(startDate).inDays ~/ 7;
    final currentWeek = diffWeeks + 1;

    if (currentWeek > 45) return null; // 45주 초과

    // 현재 주의 시작일로부터 경과된 일 수 계산
    final weekStartDate = startDate.add(Duration(days: diffWeeks * 7));
    final diffDays = now.difference(weekStartDate).inDays;
    final currentDay = diffDays + 1;

    // volume과 chapter 계산
    final volume = ((currentWeek - 1) ~/ 15) + 1;
    final chapter = ((currentWeek - 1) % 15) + 1;

    // 읽기 계획표에서 오늘의 범위 가져오기
    final readings = ReadingSchedule.getReadingsByWeekAndDay(
      currentWeek,
      currentDay,
    );
    if (readings == null || readings.isEmpty) return null;

    // 첫 번째 읽기 범위의 책 이름과 장 범위를 사용
    return ReadingPlan(
      week: currentWeek,
      volume: volume,
      chapter: chapter,
      day: currentDay,
      bookName: readings[0]['book'],
      startChapter: readings[0]['start'],
      endChapter: readings[0]['end'],
    );
  }

  // 진행률 계산
  double get progress => ReadingSchedule.calculateProgress(week, day);
}
