import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/logger_util.dart';
import '../models/team.dart';

/// 팀 관련 Firestore 데이터를 관리하는 서비스
///
/// 팀 생성/수정/삭제는 관리자 웹앱에서 처리하며,
/// 이 서비스는 팀 조회, 팀원 추가/제거, 진행상황 조회를 담당합니다.
class TeamService {
  final FirebaseFirestore _firestore;

  /// 테스트에서 [testCurrentUid]를 주입하면 FirebaseAuth를 초기화하지 않아도 됩니다.
  final String? _testCurrentUid;

  TeamService({FirebaseFirestore? firestore, String? testCurrentUid})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _testCurrentUid = testCurrentUid;

  String? get _currentUid =>
      _testCurrentUid ?? FirebaseAuth.instance.currentUser?.uid;

  int get _currentScheduleYear => DateHelper.getScheduleYear(DateTime.now());

  // ---------------------------------------------------------------------------
  // 팀 조회
  // ---------------------------------------------------------------------------

  /// 특정 연도, 교회의 팀 목록 조회
  Future<List<Team>> getTeamsForYear({
    required int year,
    String churchId = 'somang',
  }) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('teams')
              .where('year', isEqualTo: year)
              .where('churchId', isEqualTo: churchId)
              .orderBy('name')
              .get();
      return snapshot.docs
          .map(
            (doc) =>
                Team.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      LoggerUtil.error('팀 목록 조회 오류: $e');
      return [];
    }
  }

  /// 현재 사용자가 팀장인 팀 목록 조회
  Future<List<Team>> getMyLeadingTeams() async {
    if (_currentUid == null) return [];
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('teams')
              .where('year', isEqualTo: _currentScheduleYear)
              .where('leaderUid', isEqualTo: _currentUid)
              .get();
      return snapshot.docs
          .map(
            (doc) =>
                Team.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      LoggerUtil.error('내 팀 목록 조회 오류: $e');
      return [];
    }
  }

  /// 현재 사용자가 속한 팀 목록 조회
  ///
  /// member_year_profiles의 teamIds 배열을 읽어 Team 목록을 반환합니다.
  /// 구버전 teamId(String) 필드도 폴백으로 지원합니다.
  /// [year]를 생략하면 현재 통독 연도를 사용합니다.
  Future<List<Team>> getMyTeams({int? year}) async {
    if (_currentUid == null) return [];
    final int targetYear = year ?? _currentScheduleYear;
    try {
      final DocumentSnapshot memberDoc =
          await _firestore
              .collection('member_year_profiles')
              .doc(targetYear.toString())
              .collection('users')
              .doc(_currentUid!)
              .get();

      if (!memberDoc.exists) return [];

      final Map<String, dynamic> data =
          memberDoc.data() as Map<String, dynamic>;

      // teamIds 배열 우선, 구버전 teamId(String) 폴백
      List<String> teamIds = [];
      final teamIdsRaw = data['teamIds'];
      if (teamIdsRaw is List) {
        teamIds = teamIdsRaw
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        final oldTeamId = data['teamId'] as String?;
        if (oldTeamId != null && oldTeamId.isNotEmpty) teamIds = [oldTeamId];
      }

      if (teamIds.isEmpty) return [];

      final List<DocumentSnapshot> teamDocs = await Future.wait(
        teamIds.map((id) => _firestore.collection('teams').doc(id).get()),
      );

      return teamDocs
          .where((d) => d.exists)
          .map((d) => Team.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    } catch (e) {
      LoggerUtil.error('내 팀 목록 조회 오류: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 팀원 관리 (팀장 전용)
  // ---------------------------------------------------------------------------

  /// 같은 교회의 유저 목록 검색 (이름으로 필터)
  Future<List<Map<String, dynamic>>> searchUsersByName({
    required String query,
    String churchId = 'somang',
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      // Firestore는 부분 문자열 검색을 지원하지 않으므로,
      // 이름의 시작 부분으로 범위 검색합니다.
      final String searchEnd = '${query.trim()}\uf8ff';
      final QuerySnapshot snapshot =
          await _firestore
              .collection('users')
              .where('churchId', isEqualTo: churchId)
              .where('isActive', isEqualTo: true)
              .where('name', isGreaterThanOrEqualTo: query.trim())
              .where('name', isLessThanOrEqualTo: searchEnd)
              .limit(20)
              .get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      LoggerUtil.error('유저 검색 오류: $e');
      return [];
    }
  }

  /// 팀에 팀원 추가 (팀장 전용)
  Future<bool> addMemberToTeam({
    required String teamId,
    required String memberUid,
  }) async {
    if (_currentUid == null) return false;
    try {
      // 팀장 권한 확인
      final Team? team = await _getTeamIfLeader(teamId);
      if (team == null) return false;

      // member_year_profiles 업데이트
      final DocumentReference memberDoc = _firestore
          .collection('member_year_profiles')
          .doc(_currentScheduleYear.toString())
          .collection('users')
          .doc(memberUid);

      await memberDoc.set({
        'teamIds': FieldValue.arrayUnion([teamId]),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));

      LoggerUtil.info('팀원 추가 완료: $memberUid -> $teamId');
      return true;
    } catch (e) {
      LoggerUtil.error('팀원 추가 오류: $e');
      return false;
    }
  }

  /// 팀에서 팀원 제거 (팀장 전용)
  Future<bool> removeMemberFromTeam({
    required String teamId,
    required String memberUid,
  }) async {
    if (_currentUid == null) return false;
    try {
      // 팀장 권한 확인
      final Team? team = await _getTeamIfLeader(teamId);
      if (team == null) return false;

      // member_year_profiles에서 teamId 제거
      final DocumentReference memberDoc = _firestore
          .collection('member_year_profiles')
          .doc(_currentScheduleYear.toString())
          .collection('users')
          .doc(memberUid);

      await memberDoc.update({
        'teamIds': FieldValue.arrayRemove([teamId]),
        'updatedAt': DateTime.now(),
      });

      LoggerUtil.info('팀원 제거 완료: $memberUid from $teamId');
      return true;
    } catch (e) {
      LoggerUtil.error('팀원 제거 오류: $e');
      return false;
    }
  }

  /// 팀장인지 확인 후 팀 반환
  Future<Team?> _getTeamIfLeader(String teamId) async {
    final DocumentSnapshot teamDoc =
        await _firestore.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) return null;
    final Team team = Team.fromMap(
      teamDoc.data() as Map<String, dynamic>,
      teamDoc.id,
    );
    if (team.leaderUid != _currentUid) {
      LoggerUtil.warning('팀장 권한 없음: $_currentUid != ${team.leaderUid}');
      return null;
    }
    return team;
  }

  /// 팀 이름 변경 (팀장 전용)
  Future<bool> renameTeam({
    required String teamId,
    required String newName,
  }) async {
    if (_currentUid == null) return false;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    try {
      final Team? team = await _getTeamIfLeader(teamId);
      if (team == null) return false;
      await _firestore.collection('teams').doc(teamId).update({
        'name': trimmed,
        'updatedAt': DateTime.now(),
      });
      LoggerUtil.info('팀 이름 변경: $teamId → $trimmed');
      return true;
    } catch (e) {
      LoggerUtil.error('팀 이름 변경 오류: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 팀원 진행상황 조회 (팀장용)
  // ---------------------------------------------------------------------------

  /// 팀원 목록 및 주간/전체 진행상황 조회
  Future<List<TeamMemberSummary>> getTeamMembersWithProgress({
    required String teamId,
  }) async {
    try {
      final int scheduleYear = _currentScheduleYear;

      // 1. 팀 정보 조회 (leaderUid 확인용)
      final DocumentSnapshot teamDoc =
          await _firestore.collection('teams').doc(teamId).get();
      if (!teamDoc.exists) return [];
      final Team team =
          Team.fromMap(teamDoc.data() as Map<String, dynamic>, teamDoc.id);

      // 2. teamIds array-contains로 멤버 조회
      final QuerySnapshot memberProfilesSnapshot =
          await _firestore
              .collection('member_year_profiles')
              .doc(scheduleYear.toString())
              .collection('users')
              .where('teamIds', arrayContains: teamId)
              .get();

      if (memberProfilesSnapshot.docs.isEmpty) return [];

      final List<String> memberUids =
          memberProfilesSnapshot.docs.map((doc) => doc.id).toList();

      // 3. 모든 팀원 병렬 조회
      final List<TeamMemberSummary?> results = await Future.wait(
        memberUids.map(
          (uid) => _buildMemberSummary(
            uid: uid,
            scheduleYear: scheduleYear,
            memberProfilesSnapshot: memberProfilesSnapshot,
            teamLeaderUid: team.leaderUid,
          ),
        ),
      );
      final List<TeamMemberSummary> summaries =
          results.whereType<TeamMemberSummary>().toList();

      // 팀장을 맨 위로, 나머지는 이름순 정렬
      summaries.sort((a, b) {
        if (a.isTeamLeader && !b.isTeamLeader) return -1;
        if (!a.isTeamLeader && b.isTeamLeader) return 1;
        return a.name.compareTo(b.name);
      });

      return summaries;
    } catch (e) {
      LoggerUtil.error('팀원 진행상황 조회 오류: $e');
      return [];
    }
  }

  Future<TeamMemberSummary?> _buildMemberSummary({
    required String uid,
    required int scheduleYear,
    required QuerySnapshot memberProfilesSnapshot,
    required String teamLeaderUid,
  }) async {
    try {
      // 유저 프로필 + 통독 통계 병렬 조회
      final List<DocumentSnapshot> fetched = await Future.wait([
        _firestore.collection('users').doc(uid).get(),
        _firestore.doc('users/$uid/stats/$scheduleYear').get(),
      ]);
      final DocumentSnapshot userDoc = fetched[0];
      if (!userDoc.exists) return null;
      final Map<String, dynamic> userData =
          userDoc.data() as Map<String, dynamic>;

      // 이 팀의 팀장 여부 (UID 직접 비교)
      final bool isTeamLeader = uid == teamLeaderUid;

      // 통독 통계
      final DocumentSnapshot statsDoc = fetched[1];
      int totalCompletedDays = 0;
      if (statsDoc.exists) {
        final Map<String, dynamic> statsData =
            statsDoc.data() as Map<String, dynamic>;
        totalCompletedDays =
            statsData['total_days_completed'] as int? ?? 0;
      }

      // 휴식 주간 확인
      final bool isBreakWeek = DateHelper.isBreakWeek(DateTime.now());

      // 이번 주 완료 일수 계산
      final weeklyProgress = await _calculateWeeklyProgress(
        uid: uid,
        scheduleYear: scheduleYear,
      );

      return TeamMemberSummary(
        uid: uid,
        name: userData['name'] ?? '이름 없음',
        phoneNumber: userData['phoneNumber'] ?? '',
        totalCompletedDays: totalCompletedDays,
        weeklyCompletedDays: weeklyProgress['completed'] ?? 0,
        weeklyTotalDays: weeklyProgress['total'] ?? 0,
        isTeamLeader: isTeamLeader,
        isBreakWeek: isBreakWeek,
      );
    } catch (e) {
      LoggerUtil.error('팀원 요약 조회 오류 ($uid): $e');
      return null;
    }
  }

  /// 특정 유저의 이번 주 완료 일수 계산
  Future<Map<String, int>> _calculateWeeklyProgress({
    required String uid,
    required int scheduleYear,
  }) async {
    try {
      final DateTime now = DateTime.now();
      final int currentDayOfWeek = now.weekday;
      // 이번 주에서 오늘까지의 일수 (일요일 제외, 월~토 = 1~6)
      final int totalDaysThisWeek =
          currentDayOfWeek == 7 ? 6 : currentDayOfWeek;

      // 이번 주 월요일
      final DateTime monday = DateHelper.getThisWeekMonday();

      // docId 목록 계산 (로컬 연산)
      final List<String> docIds = [];
      for (int day = 1; day <= totalDaysThisWeek; day++) {
        final DateTime dateForDay = monday.add(Duration(days: day - 1));
        if (DateHelper.isBreakWeek(dateForDay) ||
            dateForDay.weekday == DateTime.sunday) {
          continue;
        }
        final adjustedDate = DateHelper.getAdjustedDate(dateForDay);
        final startDate = DateHelper.getScheduleStartDateForDate(dateForDay);
        final diffWeeks = adjustedDate.difference(startDate).inDays ~/ 7;
        final currentWeek = diffWeeks + 1;
        final weekStartDate = startDate.add(Duration(days: diffWeeks * 7));
        final diffDays = adjustedDate.difference(weekStartDate).inDays;
        final currentDay = diffDays + 1;
        if (currentWeek > 45 || currentWeek < 1) continue;
        docIds.add('${scheduleYear}_${currentWeek}_$currentDay');
      }

      if (docIds.isEmpty) return {'completed': 0, 'total': totalDaysThisWeek};

      // 모든 completion 문서 병렬 조회
      final List<DocumentSnapshot> docs = await Future.wait(
        docIds.map(
          (id) => _firestore.collection('users/$uid/completions').doc(id).get(),
        ),
      );

      return {
        'completed': docs.where((d) => d.exists).length,
        'total': totalDaysThisWeek,
      };
    } catch (e) {
      LoggerUtil.error('주간 진행상황 계산 오류 ($uid): $e');
      return {'completed': 0, 'total': 0};
    }
  }

  // ---------------------------------------------------------------------------
  // 팀원 대리 읽음 처리 (팀장용)
  // ---------------------------------------------------------------------------

  /// 팀원의 이번 주 일별 완료 상세 데이터 조회
  Future<List<MemberDayDetail>> getWeeklyDetailForMember({
    required String memberUid,
  }) async {
    try {
      final int scheduleYear = _currentScheduleYear;
      final DateTime monday = DateHelper.getThisWeekMonday();
      final List<String> dayLabels = ['월', '화', '수', '목', '금', '토'];
      // 날짜별 메타데이터 계산 (로컬 연산)
      final List<({DateTime date, int week, int day, String label, String docId})> metas = [];
      for (int i = 0; i < 6; i++) {
        final DateTime dateForDay = monday.add(Duration(days: i));
        if (DateHelper.isBreakWeek(dateForDay) ||
            dateForDay.weekday == DateTime.sunday) {
          continue;
        }
        final adjustedDate = DateHelper.getAdjustedDate(dateForDay);
        final startDate = DateHelper.getScheduleStartDateForDate(dateForDay);
        final diffWeeks = adjustedDate.difference(startDate).inDays ~/ 7;
        final currentWeek = diffWeeks + 1;
        final weekStartDate = startDate.add(Duration(days: diffWeeks * 7));
        final diffDays = adjustedDate.difference(weekStartDate).inDays;
        final currentDay = diffDays + 1;
        if (currentWeek > 45 || currentWeek < 1) continue;
        metas.add((
          date: dateForDay,
          week: currentWeek,
          day: currentDay,
          label: dayLabels[i],
          docId: '${scheduleYear}_${currentWeek}_$currentDay',
        ));
      }

      if (metas.isEmpty) return [];

      // 모든 completion 문서 병렬 조회
      final List<DocumentSnapshot> docs = await Future.wait(
        metas.map(
          (m) => _firestore
              .collection('users/$memberUid/completions')
              .doc(m.docId)
              .get(),
        ),
      );

      return List.generate(
        metas.length,
        (i) => MemberDayDetail(
          date: metas[i].date,
          week: metas[i].week,
          day: metas[i].day,
          isCompleted: docs[i].exists,
          dayLabel: metas[i].label,
        ),
      );
    } catch (e) {
      LoggerUtil.error('주간 상세 조회 오류 ($memberUid): $e');
      return [];
    }
  }

  /// 팀원의 특정 날짜 읽음 완료 처리 (대리)
  Future<bool> markCompletionForMember({
    required String memberUid,
    required int scheduleYear,
    required int week,
    required int day,
    required DateTime date,
  }) async {
    try {
      final String docId = '${scheduleYear}_${week}_$day';
      await _firestore
          .collection('users/$memberUid/completions')
          .doc(docId)
          .set({
            'date': date.toIso8601String(),
            'year': scheduleYear,
            'week': week,
            'day': day,
            'readings': [],
            'createdAt': FieldValue.serverTimestamp(),
          });

      // stats 업데이트
      final DocumentReference statsRef =
          _firestore.doc('users/$memberUid/stats/$scheduleYear');
      final DocumentSnapshot statsDoc = await statsRef.get();
      if (statsDoc.exists) {
        final Map<String, dynamic> data =
            statsDoc.data() as Map<String, dynamic>;
        final int total = data['total_days_completed'] as int? ?? 0;
        await statsRef.update({
          'total_days_completed': total + 1,
          'last_completed_date': date.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await statsRef.set({
          'total_days_completed': 1,
          'streak_current': 1,
          'streak_max': 1,
          'last_completed_date': date.toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      LoggerUtil.info('대리 완료 처리: $memberUid - $docId');
      return true;
    } catch (e) {
      LoggerUtil.error('대리 완료 처리 오류: $e');
      return false;
    }
  }

  /// 팀원의 특정 날짜 읽음 완료 취소 (대리)
  Future<bool> unmarkCompletionForMember({
    required String memberUid,
    required int scheduleYear,
    required int week,
    required int day,
  }) async {
    try {
      final String docId = '${scheduleYear}_${week}_$day';
      await _firestore
          .collection('users/$memberUid/completions')
          .doc(docId)
          .delete();

      // stats 업데이트
      final DocumentReference statsRef =
          _firestore.doc('users/$memberUid/stats/$scheduleYear');
      final DocumentSnapshot statsDoc = await statsRef.get();
      if (statsDoc.exists) {
        final Map<String, dynamic> data =
            statsDoc.data() as Map<String, dynamic>;
        final int total = data['total_days_completed'] as int? ?? 0;
        if (total > 0) {
          await statsRef.update({
            'total_days_completed': total - 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      LoggerUtil.info('대리 완료 취소: $memberUid - $docId');
      return true;
    } catch (e) {
      LoggerUtil.error('대리 완료 취소 오류: $e');
      return false;
    }
  }
}


