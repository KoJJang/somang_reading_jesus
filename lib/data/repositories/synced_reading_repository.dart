import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../models/reading_completion.dart';
import 'reading_completion_repository.dart';
import 'local_reading_repository.dart';
import 'firebase_reading_repository.dart';
import 'dart:async';

/// 로컬 데이터와 Firebase 데이터를 동기화하는 통합 저장소 (오프라인 우선 방식)
class SyncedReadingRepository implements ReadingCompletionRepository {
  final LocalReadingRepository _localRepo;
  final FirebaseReadingRepository _firebaseRepo;
  final FirebaseAuth _auth;
  final _logger = Logger();

  // 동기화 설정
  DateTime? _lastSyncTime; // 마지막 동기화 시간
  Timer? _syncTimer; // 자동 동기화 타이머
  static const int _syncIntervalMinutes = 60; // 기본 동기화 주기: 60분

  SyncedReadingRepository({
    LocalReadingRepository? localRepo,
    FirebaseReadingRepository? firebaseRepo,
    FirebaseAuth? auth,
  }) : _localRepo = localRepo ?? LocalReadingRepository(),
       _firebaseRepo = firebaseRepo ?? FirebaseReadingRepository(),
       _auth = auth ?? FirebaseAuth.instance {
    // 인증 상태 변경 감지
    _auth.authStateChanges().listen(_onAuthStateChanged);

    // 자동 동기화 타이머 시작
    _startSyncTimer();
  }

  /// 현재 인증된 사용자인지 확인
  bool get _isAuthenticated => _auth.currentUser != null;

  /// 현재 인증된 사용자의 UID
  String? get _currentUid => _auth.currentUser?.uid;

  /// 인증 상태 변경 시 호출되는 메서드
  void _onAuthStateChanged(User? user) async {
    if (user != null) {
      // 로그인 시 사용자 UID 설정
      _localRepo.setCurrentUid(user.uid);

      // 마지막 동기화 시간 로드
      _lastSyncTime = await _localRepo.loadLastSyncTime(user.uid);

      // 로그인 시 자동 동기화 실행 (마지막 동기화로부터 일정 시간이 지났으면)
      _checkAndRunAutoSync();
    } else {
      // 로그아웃 시 UID 제거
      _localRepo.setCurrentUid(null);

      // 타이머 취소
      _syncTimer?.cancel();
    }
  }

  /// 자동 동기화 타이머 시작
  void _startSyncTimer() {
    // 기존 타이머 취소
    _syncTimer?.cancel();

    // 새 타이머 시작 (1시간마다 동기화 체크)
    _syncTimer = Timer.periodic(
      const Duration(minutes: _syncIntervalMinutes),
      (_) => _checkAndRunAutoSync(),
    );

    _logger.i('자동 동기화 타이머 시작: $_syncIntervalMinutes분 간격');
  }

  /// 마지막 동기화 시간을 확인하고 필요한 경우 동기화 실행
  Future<void> _checkAndRunAutoSync() async {
    // 인증되지 않은 경우 동기화 건너뛰기
    if (!_isAuthenticated || _currentUid == null) {
      return;
    }

    // 마지막 동기화 시간 확인
    if (_lastSyncTime == null) {
      // 동기화 이력이 없으면 바로 동기화
      await syncFromFirebase();
      return;
    }

    // 마지막 동기화로부터 경과 시간 계산
    final elapsedHours = DateTime.now().difference(_lastSyncTime!).inHours;

    // 일정 시간 이상 지났으면 동기화 실행 (12시간 이상 지났을 때)
    if (elapsedHours >= 12) {
      _logger.i('마지막 동기화로부터 $elapsedHours시간 지남, 자동 동기화 실행');
      await syncFromFirebase();
    }
  }

  @override
  Future<void> markAsCompleted(ReadingCompletion completion) async {
    // 로컬에 먼저 저장 (오프라인 우선)
    await _localRepo.markAsCompleted(completion);

    // 인증된 경우 Firebase에도 항상 저장
    if (_isAuthenticated) {
      try {
        await _firebaseRepo.markAsCompleted(completion);
      } catch (e) {
        _logger.e('Firebase 저장 중 오류: $e');
        // 로컬 저장은 완료됐으므로 Firebase 오류는 무시
      }
    }
  }

  @override
  Future<void> unmarkCompleted(int year, int week, int day) async {
    // 로컬에서 먼저 취소 (오프라인 우선)
    await _localRepo.unmarkCompleted(year, week, day);

    // 인증된 경우 Firebase에서도 취소 시도
    if (_isAuthenticated) {
      try {
        await _firebaseRepo.unmarkCompleted(year, week, day);
      } catch (e) {
        _logger.e('Firebase 완료 취소 중 오류: $e');
        // 로컬 취소는 완료됐으므로 Firebase 오류는 무시
      }
    }
  }

  @override
  Future<bool> isCompleted(int year, int week, int day) async {
    // 오프라인 우선 - 로컬에서만 확인
    return await _localRepo.isCompleted(year, week, day);
  }

  @override
  Future<List<ReadingCompletion>> getCompletions() async {
    // 오프라인 우선 - 로컬 데이터만 반환
    return await _localRepo.getCompletions();
  }

  @override
  Future<List<ReadingCompletion>> getCompletionsByYear(int year) async {
    // 오프라인 우선 - 로컬 데이터만 반환
    return await _localRepo.getCompletionsByYear(year);
  }

  /// 명시적 동기화 요청을 처리하는 메서드
  Future<void> syncFromFirebase() async {
    if (!_isAuthenticated || _currentUid == null) {
      _logger.w('사용자가 인증되지 않아 동기화할 수 없습니다.');
      return;
    }

    try {
      _logger.i('클라우드에서 통독 데이터 동기화 시작...');

      // 1. Firebase에서 모든 완료 데이터 가져오기
      final firebaseCompletions = await _firebaseRepo.getCompletions();

      // 2. Firebase의 데이터를 로컬에 저장 (기존 데이터가 있으면 덮어쓰지 않음)
      for (var fbCompletion in firebaseCompletions) {
        final isLocallyCompleted = await _localRepo.isCompleted(
          fbCompletion.year,
          fbCompletion.week,
          fbCompletion.day,
        );

        if (!isLocallyCompleted) {
          _logger.i(
            '로컬에 추가: ${fbCompletion.year}_${fbCompletion.week}_${fbCompletion.day}',
          );
          await _localRepo.markAsCompleted(fbCompletion);
        }
      }

      // 3. 마지막 동기화 시간 업데이트
      _lastSyncTime = DateTime.now();
      await _localRepo.saveLastSyncTime(_currentUid!, _lastSyncTime!);

      _logger.i('통독 데이터 동기화 완료: ${_lastSyncTime?.toIso8601String()}');
    } catch (e) {
      _logger.e('데이터 동기화 중 오류: $e');
    }
  }

  /// 로컬 데이터를 Firebase에 업로드하는 메서드 (명시적 호출 시에만 사용)
  Future<void> uploadLocalDataToFirebase() async {
    if (!_isAuthenticated || _currentUid == null) {
      _logger.w('사용자가 인증되지 않아 업로드할 수 없습니다.');
      return;
    }

    try {
      _logger.i('로컬 데이터를 Firebase에 업로드 시작...');

      // 1. 로컬 데이터 가져오기
      final localCompletions = await _localRepo.getCompletions();

      // 2. 로컬 데이터를 Firebase에 업로드
      int uploadedCount = 0;
      for (var localCompletion in localCompletions) {
        try {
          final isFirebaseCompleted = await _firebaseRepo.isCompleted(
            localCompletion.year,
            localCompletion.week,
            localCompletion.day,
          );

          if (!isFirebaseCompleted) {
            await _firebaseRepo.markAsCompleted(localCompletion);
            uploadedCount++;
          }
        } catch (e) {
          _logger.e('항목 업로드 중 오류: $e');
          // 개별 항목 오류는 무시하고 계속 진행
        }
      }

      // 3. 마지막 동기화 시간 업데이트
      _lastSyncTime = DateTime.now();
      await _localRepo.saveLastSyncTime(_currentUid!, _lastSyncTime!);

      _logger.i('Firebase 업로드 완료: $uploadedCount개 항목 업로드됨');
    } catch (e) {
      _logger.e('데이터 업로드 중 오류: $e');
    }
  }

  /// 통독 통계 가져오기
  Future<Map<String, dynamic>?> getReadingStatsForYear(int scheduleYear) async {
    if (!_isAuthenticated) {
      return null;
    }

    try {
      return await _firebaseRepo.getReadingStatsForYear(scheduleYear);
    } catch (e) {
      _logger.e('통독 통계 조회 중 오류: $e');
      return null;
    }
  }

  /// 마지막 동기화 시간 반환
  DateTime? getLastSyncDateTime() {
    return _lastSyncTime;
  }

  /// 사용자 데이터 삭제
  Future<void> deleteUserData() async {
    try {
      _logger.i('사용자 데이터 삭제 시작...');

      // 로컬 데이터 삭제
      await _localRepo.deleteAllCompletions();

      // 마지막 동기화 시간 초기화
      _lastSyncTime = null;

      _logger.i('사용자 데이터 삭제 완료');
    } catch (e) {
      _logger.e('사용자 데이터 삭제 중 오류: $e');
      rethrow;
    }
  }

  /// 리소스 정리
  void dispose() {
    _syncTimer?.cancel();
  }
}
