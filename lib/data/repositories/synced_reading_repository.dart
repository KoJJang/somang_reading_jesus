import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../models/reading_completion.dart';
import 'reading_completion_repository.dart';
import 'local_reading_repository.dart';
import 'firebase_reading_repository.dart';

/// 로컬 데이터와 Firebase 데이터를 동기화하는 통합 저장소
class SyncedReadingRepository implements ReadingCompletionRepository {
  final LocalReadingRepository _localRepo;
  final FirebaseReadingRepository _firebaseRepo;
  final FirebaseAuth _auth;
  final _logger = Logger();

  SyncedReadingRepository({
    LocalReadingRepository? localRepo,
    FirebaseReadingRepository? firebaseRepo,
    FirebaseAuth? auth,
  }) : _localRepo = localRepo ?? LocalReadingRepository(),
       _firebaseRepo = firebaseRepo ?? FirebaseReadingRepository(),
       _auth = auth ?? FirebaseAuth.instance;

  /// 현재 인증된 사용자인지 확인
  bool get _isAuthenticated => _auth.currentUser != null;

  @override
  Future<void> markAsCompleted(ReadingCompletion completion) async {
    // 로컬에 항상 저장
    await _localRepo.markAsCompleted(completion);

    // 인증된 경우에만 Firebase에도 저장
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
  Future<bool> isCompleted(int year, int week, int day) async {
    // 로컬에서 먼저 확인
    final isLocalCompleted = await _localRepo.isCompleted(year, week, day);
    if (isLocalCompleted) {
      return true;
    }

    // 로컬에 없고 인증된 경우 Firebase에서 확인
    if (_isAuthenticated) {
      try {
        return await _firebaseRepo.isCompleted(year, week, day);
      } catch (e) {
        _logger.e('Firebase 완료 상태 확인 중 오류: $e');
      }
    }

    return false;
  }

  @override
  Future<List<ReadingCompletion>> getCompletions() async {
    // 로컬 데이터 가져오기
    final localCompletions = await _localRepo.getCompletions();

    // 인증되지 않은 경우 로컬 데이터만 반환
    if (!_isAuthenticated) {
      return localCompletions;
    }

    try {
      // Firebase 데이터 가져오기
      final firebaseCompletions = await _firebaseRepo.getCompletions();

      // 로컬과 Firebase 데이터 합치기
      return _mergeCompletions(localCompletions, firebaseCompletions);
    } catch (e) {
      _logger.e('Firebase 데이터 조회 중 오류: $e');
      // 오류 발생 시 로컬 데이터만 반환
      return localCompletions;
    }
  }

  @override
  Future<List<ReadingCompletion>> getCompletionsByYear(int year) async {
    // 로컬 데이터 가져오기
    final localCompletions = await _localRepo.getCompletionsByYear(year);

    // 인증되지 않은 경우 로컬 데이터만 반환
    if (!_isAuthenticated) {
      return localCompletions;
    }

    try {
      // Firebase 데이터 가져오기
      final firebaseCompletions = await _firebaseRepo.getCompletionsByYear(
        year,
      );

      // 로컬과 Firebase 데이터 합치기
      return _mergeCompletions(localCompletions, firebaseCompletions);
    } catch (e) {
      _logger.e('Firebase 연도별 데이터 조회 중 오류: $e');
      // 오류 발생 시 로컬 데이터만 반환
      return localCompletions;
    }
  }

  /// 로그인 시 데이터 동기화
  Future<void> syncOnLogin() async {
    if (!_isAuthenticated) {
      _logger.w('사용자가 인증되지 않아 동기화할 수 없습니다.');
      return;
    }

    try {
      _logger.i('로그인 후 통독 데이터 동기화 시작...');

      // 1. Firebase에서 모든 완료 데이터 가져오기
      final firebaseCompletions = await _firebaseRepo.getCompletions();

      // 2. 로컬에서 모든 완료 데이터 가져오기
      final localCompletions = await _localRepo.getCompletions();

      // 3. Firebase에 있지만 로컬에 없는 데이터 로컬에 저장
      for (var fbCompletion in firebaseCompletions) {
        final isLocallyCompleted = await _localRepo.isCompleted(
          fbCompletion.year,
          fbCompletion.week,
          fbCompletion.day,
        );

        if (!isLocallyCompleted) {
          _logger.i(
            '로컬에 누락된 데이터 추가: ${fbCompletion.year}_${fbCompletion.week}_${fbCompletion.day}',
          );
          await _localRepo.markAsCompleted(fbCompletion);
        }
      }

      // 4. 로컬에 있지만 Firebase에 없는 데이터 Firebase에 저장
      for (var localCompletion in localCompletions) {
        final isFirebaseCompleted = await _firebaseRepo.isCompleted(
          localCompletion.year,
          localCompletion.week,
          localCompletion.day,
        );

        if (!isFirebaseCompleted) {
          _logger.i(
            'Firebase에 누락된 데이터 추가: ${localCompletion.year}_${localCompletion.week}_${localCompletion.day}',
          );
          await _firebaseRepo.markAsCompleted(localCompletion);
        }
      }

      _logger.i('통독 데이터 동기화 완료');
    } catch (e) {
      _logger.e('데이터 동기화 중 오류: $e');
    }
  }

  /// 두 완료 목록을 합치는 메서드
  List<ReadingCompletion> _mergeCompletions(
    List<ReadingCompletion> localList,
    List<ReadingCompletion> firebaseList,
  ) {
    // 모든 항목을 담을 맵 (중복 제거)
    final Map<String, ReadingCompletion> mergedMap = {};

    // 로컬 데이터 추가
    for (var item in localList) {
      final key = '${item.year}_${item.week}_${item.day}';
      mergedMap[key] = item;
    }

    // Firebase 데이터 추가 (이미 있는 키는 덮어씀)
    for (var item in firebaseList) {
      final key = '${item.year}_${item.week}_${item.day}';
      mergedMap[key] = item;
    }

    // 맵의 값들을 리스트로 변환하여 정렬
    final mergedList = mergedMap.values.toList();
    mergedList.sort((a, b) {
      // 연도 내림차순, 주차 내림차순, 일 내림차순
      if (a.year != b.year) return b.year.compareTo(a.year);
      if (a.week != b.week) return b.week.compareTo(a.week);
      return b.day.compareTo(a.day);
    });

    return mergedList;
  }

  /// 통독 통계 가져오기
  Future<Map<String, dynamic>?> getReadingStats() async {
    if (!_isAuthenticated) {
      return null;
    }

    try {
      return await _firebaseRepo.getReadingStats();
    } catch (e) {
      _logger.e('통독 통계 조회 중 오류: $e');
      return null;
    }
  }
}
