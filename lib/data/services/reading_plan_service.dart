import '../models/reading_plan.dart';

class ReadingPlanService {
  static final DateTime _startDate = DateTime(2025, 1, 20);

  // 오늘의 읽기 계획 가져오기
  Future<ReadingPlan?> getTodaysPlan() async {
    return ReadingPlan.calculateCurrentPlan(_startDate);
  }
}
