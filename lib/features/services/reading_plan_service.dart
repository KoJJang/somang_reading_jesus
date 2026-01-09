import 'models/reading_plan.dart';
import '../../core/utils/date_helper.dart';
import '../../../config/schedule_config.dart';
import '../admin/services/admin_schedule_service.dart';

class ReadingPlanService {
  final AdminScheduleService _adminScheduleService = AdminScheduleService();

  /// 특정 날짜가 속한 일정 연도 (완료 데이터 키)
  static int scheduleYearForDate(DateTime date) =>
      DateHelper.getScheduleYear(date);

  Future<ReadingPlan?> getTodaysPlan() async {
    return getPlanForDate(DateTime.now());
  }

  /// 특정 연도의 설정을 미리 로드하고 캐싱합니다.
  Future<void> ensureConfigLoaded(int year) async {
    if (ScheduleConfig.getDynamicConfig(year) == null) {
      final config = await _adminScheduleService.getScheduleConfig(year);
      ScheduleConfig.setDynamicConfig(year, config);
    }
  }

  Future<ReadingPlan?> getPlanForDate(DateTime date) async {
    // 1. 일정 설정 가져오기 (캐시 우선 사용)
    final scheduleYear = DateHelper.getScheduleYear(date);
    var config = ScheduleConfig.getDynamicConfig(scheduleYear);
    if (config == null) {
      config = await _adminScheduleService.getScheduleConfig(scheduleYear);
      ScheduleConfig.setDynamicConfig(scheduleYear, config);
    }
    if (config == null) {
      return null;
    }
    final startDate = config.startDate;

    // 2. 기본 체크 (일요일/시작 전 체크)
    // 휴일 체크는 getReadingIndex 내부에서 수행되므로 여기선 날짜 경계만 체크
    if (date.weekday == DateTime.sunday || date.isBefore(startDate)) {
      return null;
    }

    // 3. 인덱스 계산 (월~토만 포함, 휴일 제외)
    final index = DateHelper.getReadingIndex(date, startDate, config.holidays);

    // 타겟 날짜가 휴일이거나 일요일이라서 인덱스 계산 시 건너뛰어지는 경우 처리
    // getReadingIndex는 targetDate가 유효하지 않으면 이전 유효일의 인덱스를 반환하지 않고
    // 그냥 그날까지의 총 유효일수를 세므로, targetDate 자체가 유효한지 별도 체크 필요
    final isHoliday = _adminScheduleService.isHoliday(date, config.holidays);
    if (isHoliday || date.weekday == DateTime.sunday) {
      return null;
    }

    if (index < 0) return null;

    // 4. 주차(week) 및 일차(day) 계산 (6일 주기 커리큘럼 기준)
    final currentWeek = (index ~/ 6) + 1;
    final currentDay = (index % 6) + 1;

    if (currentWeek > 45) return null;

    return ReadingPlan.calculatePlanForWeekAndDay(
      currentWeek,
      currentDay,
      startDate,
    );
  }
}
