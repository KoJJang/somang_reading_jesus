/// 리딩 지저스 일정 설정
///
/// 일정이 지연되거나 변경될 때 이 파일의 설정을 수정하면 됩니다.
class ScheduleConfig {
  /// 일정 지연 일수
  ///
  /// 양수: 일정이 지연된 경우 (예: 14 = 2주 지연)
  /// 음수: 일정이 앞당겨진 경우 (예: -7 = 1주 앞당김)
  /// 0: 원래 일정대로 진행
  ///
  /// 예시 1 - 2주 지연:
  /// - 현재 날짜: 10월 15일
  /// - delayDays = 14 (2주 지연)
  /// - 실제 조회되는 일정: 10월 1일의 일정 (사도행전 21-22장)
  ///
  /// 예시 2 - 지연 없음:
  /// - 현재 날짜: 10월 15일
  /// - delayDays = 0
  /// - 실제 조회되는 일정: 10월 15일의 일정 (고린도전서 9-12장)
  static const int delayDays = 14;

  /// 일정 시작일
  /// 리딩 지저스가 시작된 날짜
  static final DateTime startDate = DateTime(2025, 1, 20);

  /// 오프셋이 적용된 현재 날짜 계산
  static DateTime getAdjustedDate(DateTime date) {
    return date.subtract(Duration(days: delayDays));
  }

  /// 오프셋이 적용된 오늘 날짜 계산
  static DateTime getAdjustedToday() {
    return getAdjustedDate(DateTime.now());
  }
}
