import 'package:firebase_auth/firebase_auth.dart';

import '../models/reading_completion.dart';
import '../repositories/synced_reading_repository.dart';
import '../../core/utils/date_helper.dart';

/// 통독 데이터 서비스 클래스
///
/// 이 클래스는 통독 완료 데이터의 저장, 조회, 동기화를 처리합니다.
/// 내부적으로 로컬 저장소와 Firebase 저장소를 동기화하는 SyncedReadingRepository를 사용합니다.
/// 오프라인 우선 접근 방식으로 동작합니다.
class ReadingService {
  static final ReadingService _instance = ReadingService._internal();
  final SyncedReadingRepository _repository;
  final FirebaseAuth _auth;

  /// 팩토리 생성자 - 싱글톤 패턴
  factory ReadingService() {
    return _instance;
  }

  /// 내부 생성자
  ReadingService._internal()
    : _repository = SyncedReadingRepository(),
      _auth = FirebaseAuth.instance {
    // 인증 상태는 repository에서 관리
  }

  /// 통독 완료 표시 (로컬에 저장, 인증된 경우 Firebase에도 저장)
  Future<void> markAsCompleted(ReadingCompletion completion) async {
    await _repository.markAsCompleted(completion);
  }

  /// 통독 완료 취소 (로컬에서 취소 후, 인증된 경우 Firebase에서도 취소)
  Future<void> unmarkCompleted(int year, int week, int day) async {
    await _repository.unmarkCompleted(year, week, day);
  }

  /// 특정 날짜의 통독 완료 여부 확인 (로컬 데이터 우선)
  Future<bool> isCompleted(int year, int week, int day) async {
    return await _repository.isCompleted(year, week, day);
  }

  /// 모든 완료 데이터 가져오기 (로컬 데이터 우선)
  Future<List<ReadingCompletion>> getCompletions() async {
    return await _repository.getCompletions();
  }

  /// 특정 연도의 완료 데이터 가져오기 (로컬 데이터 우선)
  Future<List<ReadingCompletion>> getCompletionsByYear(int year) async {
    return await _repository.getCompletionsByYear(year);
  }

  /// 통독 통계 가져오기 (Firebase에서만 조회)
  Future<Map<String, dynamic>?> getReadingStats() async {
    final int scheduleYear = DateHelper.getScheduleYear(DateTime.now());
    return await _repository.getReadingStatsForYear(scheduleYear);
  }

  /// 수동으로 Firebase에서 로컬로 데이터 동기화 실행
  Future<void> syncFromFirebase() async {
    await _repository.syncFromFirebase();
  }

  /// 로컬 데이터를 Firebase에 업로드
  Future<void> uploadToFirebase() async {
    await _repository.uploadLocalDataToFirebase();
  }

  /// 사용자 데이터 삭제
  Future<void> deleteUserData() async {
    // 로컬 데이터 삭제
    await _repository.deleteUserData();
  }

  /// 마지막 동기화 시간 조회
  DateTime? getLastSyncTime() {
    return _repository.getLastSyncDateTime();
  }

  /// 사용자가 인증되었는지 확인
  bool get isAuthenticated => _auth.currentUser != null;

  /// 리소스 정리
  void dispose() {
    _repository.dispose();
  }
}
