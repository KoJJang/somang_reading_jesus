import '../models/reading_completion.dart';

/// 통독 완료 데이터에 대한 저장소 인터페이스
abstract class ReadingCompletionRepository {
  /// 통독 완료 표시
  Future<void> markAsCompleted(ReadingCompletion completion);

  /// 특정 날짜의 통독 완료 여부 확인
  Future<bool> isCompleted(int year, int week, int day);

  /// 모든 완료 데이터 가져오기
  Future<List<ReadingCompletion>> getCompletions();

  /// 특정 연도의 완료 데이터 가져오기
  Future<List<ReadingCompletion>> getCompletionsByYear(int year);
}
