// 각 volume 파일들을 part로 선언
part 'reading_schedule_volume1.dart';
part 'reading_schedule_volume2.dart';
part 'reading_schedule_volume3.dart';
part 'reading_schedule_volume4.dart';
part 'reading_schedule_volume5.dart';
part 'reading_schedule_volume6.dart';

class ReadingSchedule {
  // 성경 읽기 계획표 데이터
  static final List<Map<String, dynamic>> schedule = [
    // 1권 (1-7주차)
    ..._volume1Schedule,
    // 2권 (8-15주차)
    ..._volume2Schedule,
    // 3권 (16-22주차)
    ..._volume3Schedule,
    // 4권 (23-31주차)
    ..._volume4Schedule,
    // 5권 (32-38주차)
    ..._volume5Schedule,
    // 6권 (39-45주차)
    ..._volume6Schedule,
  ];

  // 특정 주차와 일차의 읽기 범위 가져오기
  static List<Map<String, dynamic>>? getReadingsByWeekAndDay(
    int week,
    int day,
  ) {
    try {
      final weekSchedule = schedule.firstWhere((s) => s['week'] == week);
      final daySchedule = weekSchedule['ranges'].firstWhere(
        (r) => r['day'] == day,
      );
      return List<Map<String, dynamic>>.from(daySchedule['readings']);
    } catch (e) {
      return null;
    }
  }

  // 현재 진행률 계산 (0.0 ~ 1.0)
  static double calculateProgress(int currentWeek, int currentDay) {
    const totalDays = 45 * 6; // 45주 * 6일
    final completedDays = ((currentWeek - 1) * 6) + (currentDay - 1);
    return completedDays / totalDays;
  }
}
