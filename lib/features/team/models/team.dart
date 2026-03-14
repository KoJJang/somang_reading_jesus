import 'package:cloud_firestore/cloud_firestore.dart';

/// 팀 정보를 나타내는 모델 클래스
///
/// Firestore 경로: `teams/{teamId}`
class Team {
  final String teamId;
  final String name;
  final String churchId;
  final int year;
  final String leaderUid;
  final String leaderName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Team({
    required this.teamId,
    required this.name,
    required this.churchId,
    required this.year,
    required this.leaderUid,
    required this.leaderName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Team.fromMap(Map<String, dynamic> map, String docId) {
    return Team(
      teamId: docId,
      name: map['name'] ?? '',
      churchId: map['churchId'] ?? 'somang',
      year: map['year'] ?? DateTime.now().year,
      leaderUid: map['leaderUid'] ?? '',
      leaderName: map['leaderName'] ?? '',
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'churchId': churchId,
      'year': year,
      'leaderUid': leaderUid,
      'leaderName': leaderName,
      'createdAt': createdAt,
      'updatedAt': DateTime.now(),
    };
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}

/// 팀원의 연도별 프로필 및 진행 상황 요약
class TeamMemberSummary {
  final String uid;
  final String name;
  final String phoneNumber;
  final int totalCompletedDays;
  final int weeklyCompletedDays;
  final int weeklyTotalDays;
  final bool isTeamLeader;
  final bool isBreakWeek;

  TeamMemberSummary({
    required this.uid,
    required this.name,
    required this.phoneNumber,
    required this.totalCompletedDays,
    required this.weeklyCompletedDays,
    required this.weeklyTotalDays,
    required this.isTeamLeader,
    this.isBreakWeek = false,
  });

  double get weeklyProgressRate {
    if (isBreakWeek || weeklyTotalDays == 0) return 0.0;
    return weeklyCompletedDays / weeklyTotalDays;
  }
}

/// 팀원의 이번 주 일별 완료 상세 정보
class MemberDayDetail {
  final DateTime date;
  final int week;
  final int day;
  final bool isCompleted;
  final String dayLabel; // 월, 화, 수, ...

  MemberDayDetail({
    required this.date,
    required this.week,
    required this.day,
    required this.isCompleted,
    required this.dayLabel,
  });
}


