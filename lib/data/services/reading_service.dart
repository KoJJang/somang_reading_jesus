import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import '../models/reading_completion.dart';
import '../repositories/synced_reading_repository.dart';

/// 통독 데이터 서비스 클래스
///
/// 이 클래스는 통독 완료 데이터의 저장, 조회, 동기화를 처리합니다.
/// 내부적으로 로컬 저장소와 Firebase 저장소를 동기화하는 SyncedReadingRepository를 사용합니다.
class ReadingService {
  static final ReadingService _instance = ReadingService._internal();
  final SyncedReadingRepository _repository;
  final FirebaseAuth _auth;
  final _logger = Logger();

  /// 팩토리 생성자 - 싱글톤 패턴
  factory ReadingService() {
    return _instance;
  }

  /// 내부 생성자
  ReadingService._internal()
    : _repository = SyncedReadingRepository(),
      _auth = FirebaseAuth.instance {
    // 인증 상태 변경 감지
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// 인증 상태 변경 시 호출되는 메서드
  void _onAuthStateChanged(User? user) {
    if (user != null) {
      // 로그인된 경우, 데이터 동기화 수행
      _syncDataAfterLogin();
    }
  }

  /// 로그인 후 데이터 동기화
  Future<void> _syncDataAfterLogin() async {
    try {
      _logger.i('로그인 감지됨: 통독 데이터 동기화 시작');
      await _repository.syncOnLogin();
    } catch (e) {
      _logger.e('로그인 후 데이터 동기화 중 오류: $e');
    }
  }

  /// 통독 완료 표시
  Future<void> markAsCompleted(ReadingCompletion completion) async {
    await _repository.markAsCompleted(completion);
  }

  /// 특정 날짜의 통독 완료 여부 확인
  Future<bool> isCompleted(int year, int week, int day) async {
    return await _repository.isCompleted(year, week, day);
  }

  /// 모든 완료 데이터 가져오기
  Future<List<ReadingCompletion>> getCompletions() async {
    return await _repository.getCompletions();
  }

  /// 특정 연도의 완료 데이터 가져오기
  Future<List<ReadingCompletion>> getCompletionsByYear(int year) async {
    return await _repository.getCompletionsByYear(year);
  }

  /// 통독 통계 가져오기
  Future<Map<String, dynamic>?> getReadingStats() async {
    return await _repository.getReadingStats();
  }

  /// 수동으로 데이터 동기화 실행
  Future<void> syncData() async {
    await _repository.syncOnLogin();
  }
}
