import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../models/reading_completion.dart';
import 'reading_completion_repository.dart';

/// Firebase Firestore 기반의 원격 통독 완료 데이터 저장소
class FirebaseReadingRepository implements ReadingCompletionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _logger = Logger();

  /// 현재 인증된 사용자 ID
  String? get _userId => _auth.currentUser?.uid;

  /// 사용자의 통독 완료 데이터 컬렉션 참조
  CollectionReference? get _completionsCollection =>
      _userId != null
          ? _firestore.collection('users/$_userId/completions')
          : null;

  /// 사용자의 통독 통계 문서 참조
  DocumentReference? get _statsDocument =>
      _userId != null ? _firestore.doc('users/$_userId/stats/summary') : null;

  @override
  Future<void> markAsCompleted(ReadingCompletion completion) async {
    if (_userId == null) {
      _logger.w('사용자가 인증되지 않아 Firebase에 저장할 수 없습니다.');
      return;
    }

    try {
      // 통독 완료 데이터 저장
      final docId = '${completion.year}_${completion.week}_${completion.day}';
      await _completionsCollection!.doc(docId).set({
        'date': completion.date.toIso8601String(),
        'year': completion.year,
        'week': completion.week,
        'day': completion.day,
        'readings': completion.readings,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 통계 데이터 업데이트
      await _updateReadingStats(completion.date);

      _logger.i('Firebase에 통독 완료 데이터 저장: $docId');
    } catch (e) {
      _logger.e('Firebase 통독 완료 표시 중 오류: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isCompleted(int year, int week, int day) async {
    if (_userId == null) {
      return false;
    }

    try {
      final docId = '${year}_${week}_${day}';
      final docSnapshot = await _completionsCollection!.doc(docId).get();
      return docSnapshot.exists;
    } catch (e) {
      _logger.e('Firebase 완료 상태 확인 중 오류: $e');
      return false;
    }
  }

  @override
  Future<List<ReadingCompletion>> getCompletions() async {
    if (_userId == null) {
      return [];
    }

    try {
      final querySnapshot =
          await _completionsCollection!
              .orderBy('year', descending: true)
              .orderBy('week', descending: true)
              .orderBy('day', descending: true)
              .get();

      return _convertQuerySnapshotToCompletions(querySnapshot);
    } catch (e) {
      _logger.e('Firebase 완료 데이터 조회 중 오류: $e');
      return [];
    }
  }

  @override
  Future<List<ReadingCompletion>> getCompletionsByYear(int year) async {
    if (_userId == null) {
      return [];
    }

    try {
      final querySnapshot =
          await _completionsCollection!
              .where('year', isEqualTo: year)
              .orderBy('week')
              .orderBy('day')
              .get();

      return _convertQuerySnapshotToCompletions(querySnapshot);
    } catch (e) {
      _logger.e('Firebase 연도별 완료 데이터 조회 중 오류: $e');
      return [];
    }
  }

  /// 통독 통계 데이터 업데이트
  Future<void> _updateReadingStats(DateTime completionDate) async {
    try {
      // 통계 문서 참조
      final statsDocRef = _statsDocument;
      if (statsDocRef == null) return;

      // 트랜잭션을 사용하여 통계 업데이트
      await _firestore.runTransaction((transaction) async {
        final statsDoc = await transaction.get(statsDocRef);

        if (statsDoc.exists) {
          // 기존 통계가 있는 경우
          final data = statsDoc.data() as Map<String, dynamic>;

          // 마지막 완료일 가져오기
          final lastCompletedDateStr = data['last_completed_date'] as String?;
          final lastCompletedDate =
              lastCompletedDateStr != null
                  ? DateTime.parse(lastCompletedDateStr)
                  : null;

          final currentStreak = data['streak_current'] as int? ?? 0;
          final maxStreak = data['streak_max'] as int? ?? 0;
          final totalDays = data['total_days_completed'] as int? ?? 0;

          // 연속 일수(스트릭) 계산
          int newStreak = 1; // 기본값은 1 (오늘 완료)
          if (lastCompletedDate != null) {
            final isConsecutive = _isConsecutiveDay(
              lastCompletedDate,
              completionDate,
            );
            newStreak = isConsecutive ? currentStreak + 1 : 1;
          }

          // 최대 스트릭 업데이트
          final newMaxStreak = newStreak > maxStreak ? newStreak : maxStreak;

          // 통계 업데이트
          transaction.update(statsDocRef, {
            'total_days_completed': totalDays + 1,
            'streak_current': newStreak,
            'streak_max': newMaxStreak,
            'last_completed_date': completionDate.toIso8601String(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // 통계가 없는 경우 새로 생성
          transaction.set(statsDocRef, {
            'total_days_completed': 1,
            'streak_current': 1,
            'streak_max': 1,
            'last_completed_date': completionDate.toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _logger.i('통독 통계 업데이트 완료');
    } catch (e) {
      _logger.e('통독 통계 업데이트 중 오류: $e');
    }
  }

  /// 두 날짜가 연속된 날인지 확인
  bool _isConsecutiveDay(DateTime previous, DateTime current) {
    // 날짜의 시간 부분 제거 (00:00:00으로 설정)
    final prevDate = DateTime(previous.year, previous.month, previous.day);
    final currDate = DateTime(current.year, current.month, current.day);

    // 두 날짜의 차이가 1일인지 확인
    final difference = currDate.difference(prevDate).inDays;
    return difference == 1;
  }

  /// Firestore 쿼리 결과를 ReadingCompletion 객체 목록으로 변환
  List<ReadingCompletion> _convertQuerySnapshotToCompletions(
    QuerySnapshot querySnapshot,
  ) {
    return querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // date 필드가 Timestamp인 경우 처리
      dynamic dateField = data['date'];
      DateTime date;

      if (dateField is Timestamp) {
        date = dateField.toDate();
      } else if (dateField is String) {
        date = DateTime.parse(dateField);
      } else {
        // 기본값으로 현재 시간 사용
        date = DateTime.now();
      }

      // readings 필드 처리
      List<Map<String, dynamic>> readings = [];
      if (data['readings'] != null) {
        final readingsData = data['readings'];
        if (readingsData is List) {
          readings = List<Map<String, dynamic>>.from(readingsData);
        }
      }

      return ReadingCompletion(
        date: date,
        year: data['year'] as int,
        week: data['week'] as int,
        day: data['day'] as int,
        readings: readings,
      );
    }).toList();
  }

  /// 통독 통계 가져오기
  Future<Map<String, dynamic>?> getReadingStats() async {
    if (_userId == null) {
      return null;
    }

    try {
      final docSnapshot = await _statsDocument!.get();
      if (docSnapshot.exists) {
        return docSnapshot.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _logger.e('통독 통계 조회 중 오류: $e');
      return null;
    }
  }
}
