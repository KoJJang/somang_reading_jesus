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

  DocumentReference? get _legacyStatsDocument =>
      _userId != null ? _firestore.doc('users/$_userId/stats/summary') : null;

  DocumentReference? _statsDocumentForYear({required int scheduleYear}) {
    if (_userId == null) {
      return null;
    }
    return _firestore.doc('users/$_userId/stats/$scheduleYear');
  }

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
      await _updateReadingStats(
        scheduleYear: completion.year,
        completionDate: completion.date,
      );

      _logger.i('Firebase에 통독 완료 데이터 저장: $docId');
    } catch (e) {
      _logger.e('Firebase 통독 완료 표시 중 오류: $e');
      rethrow;
    }
  }

  Future<void> _updateReadingStats({
    required int scheduleYear,
    required DateTime completionDate,
  }) async {
    try {
      final DocumentReference? statsDocRef = _statsDocumentForYear(
        scheduleYear: scheduleYear,
      );
      if (statsDocRef == null) return;
      await _firestore.runTransaction((transaction) async {
        final DocumentSnapshot statsDoc = await transaction.get(statsDocRef);
        if (statsDoc.exists) {
          final Map<String, dynamic> data =
              statsDoc.data() as Map<String, dynamic>;
          final String? lastCompletedDateStr =
              data['last_completed_date'] as String?;
          final DateTime? lastCompletedDate =
              lastCompletedDateStr != null
                  ? DateTime.parse(lastCompletedDateStr)
                  : null;
          final int currentStreak = data['streak_current'] as int? ?? 0;
          final int maxStreak = data['streak_max'] as int? ?? 0;
          final int totalDays = data['total_days_completed'] as int? ?? 0;
          int newStreak = 1;
          if (lastCompletedDate != null) {
            final bool isConsecutive = _isConsecutiveDay(
              lastCompletedDate,
              completionDate,
            );
            newStreak = isConsecutive ? currentStreak + 1 : 1;
          }
          final int newMaxStreak =
              newStreak > maxStreak ? newStreak : maxStreak;
          transaction.update(statsDocRef, {
            'total_days_completed': totalDays + 1,
            'streak_current': newStreak,
            'streak_max': newMaxStreak,
            'last_completed_date': completionDate.toIso8601String(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
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

  bool _isConsecutiveDay(DateTime previous, DateTime current) {
    final DateTime prevDate = DateTime(
      previous.year,
      previous.month,
      previous.day,
    );
    final DateTime currDate = DateTime(
      current.year,
      current.month,
      current.day,
    );
    final int difference = currDate.difference(prevDate).inDays;
    return difference == 1;
  }

  Future<Map<String, dynamic>?> getReadingStatsForYear(int scheduleYear) async {
    if (_userId == null) {
      return null;
    }
    try {
      final DocumentReference? statsDocRef = _statsDocumentForYear(
        scheduleYear: scheduleYear,
      );
      if (statsDocRef == null) {
        return null;
      }
      final DocumentSnapshot docSnapshot = await statsDocRef.get();
      if (docSnapshot.exists) {
        return docSnapshot.data() as Map<String, dynamic>;
      }
      final DocumentReference? legacyDocRef = _legacyStatsDocument;
      if (legacyDocRef == null) {
        return null;
      }
      final DocumentSnapshot legacySnapshot = await legacyDocRef.get();
      if (legacySnapshot.exists) {
        return legacySnapshot.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _logger.e('통독 통계 조회 중 오류: $e');
      return null;
    }
  }

  @override
  Future<void> unmarkCompleted(int year, int week, int day) async {
    if (_userId == null) {
      return;
    }

    try {
      final docId = '${year}_${week}_${day}';
      await _completionsCollection!.doc(docId).delete();
      _logger.i('Firebase 통독 완료 취소: $docId');
    } catch (e) {
      _logger.e('Firebase 통독 완료 취소 중 오류: $e');
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
}
