import '../models/reading_plan.dart';
import '../../core/utils/date_helper.dart';

class ReadingPlanService {
  // 오늘의 읽기 계획 가져오기
  Future<ReadingPlan?> getTodaysPlan() async {
    final startDate = DateHelper.getScheduleStartDateForDate(DateTime.now());
    return ReadingPlan.calculateCurrentPlan(startDate);
  }
}
