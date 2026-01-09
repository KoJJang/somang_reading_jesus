import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/logger_util.dart';

class ScheduleConfigData {
  final DateTime startDate;
  final List<DateTimeRange> holidays;

  ScheduleConfigData({required this.startDate, required this.holidays});

  factory ScheduleConfigData.fromMap(Map<String, dynamic> map) {
    List<DateTimeRange> holidayRanges = [];
    if (map['holidays'] != null) {
      final List<dynamic> list = map['holidays'];
      for (final item in list) {
        if (item is Map) {
          holidayRanges.add(
            DateTimeRange(
              start: (item['start'] as Timestamp).toDate(),
              end: (item['end'] as Timestamp).toDate(),
            ),
          );
        } else if (item is Timestamp) {
          // 하위 호환성: 이전의 단일 Timestamp 형식 처리
          holidayRanges.add(
            DateTimeRange(start: item.toDate(), end: item.toDate()),
          );
        }
      }
    }

    return ScheduleConfigData(
      startDate: (map['startDate'] as Timestamp).toDate(),
      holidays: holidayRanges,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'holidays':
          holidays
              .map(
                (e) => {
                  'start': Timestamp.fromDate(e.start),
                  'end': Timestamp.fromDate(e.end),
                },
              )
              .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Default config if none exists
  factory ScheduleConfigData.defaultConfig() {
    return ScheduleConfigData(startDate: DateTime(2025, 1, 20), holidays: []);
  }
}

class AdminScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference _configDoc(int year) => _firestore
      .collection('config')
      .doc('schedule')
      .collection('years')
      .doc(year.toString());

  // 일정 설정 가져오기
  Future<ScheduleConfigData?> getScheduleConfig(int year) async {
    try {
      final doc = await _configDoc(year).get();
      if (doc.exists) {
        return ScheduleConfigData.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      LoggerUtil.error('$year년 일정 설정 로드 중 오류: $e');
    }
    return null;
  }

  /// 설정된 모든 연도 목록 가져오기
  Future<List<int>> getAvailableYears() async {
    try {
      final snapshot =
          await _firestore
              .collection('config')
              .doc('schedule')
              .collection('years')
              .get();
      return snapshot.docs
          .map((doc) => int.tryParse(doc.id))
          .whereType<int>()
          .toList()
        ..sort();
    } catch (e) {
      LoggerUtil.error('설정 가능 연도 목록 로드 중 오류: $e');
      return [];
    }
  }

  // 일정 설정 저장하기
  Future<void> saveScheduleConfig(int year, ScheduleConfigData config) async {
    try {
      await _configDoc(year).set(config.toMap(), SetOptions(merge: true));
      LoggerUtil.info('$year년 일정 설정 저장 완료');
    } catch (e) {
      LoggerUtil.error('$year년 일정 설정 저장 중 오류: $e');
      throw Exception('$year년 일정을 저장하는 데 실패했습니다: $e');
    }
  }

  // 특정 날짜가 휴일 목록에 있는지 확인
  bool isHoliday(DateTime date, List<DateTimeRange> holidays) {
    final targetScore = date.year * 10000 + date.month * 100 + date.day;
    for (final range in holidays) {
      final startScore =
          range.start.year * 10000 + range.start.month * 100 + range.start.day;
      final endScore =
          range.end.year * 10000 + range.end.month * 100 + range.end.day;

      if (targetScore >= startScore && targetScore <= endScore) {
        return true;
      }
    }
    return false;
  }
}
