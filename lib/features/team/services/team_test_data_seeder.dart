// =============================================================================
// ⚠️  DEBUG ONLY – 팀 기능 테스트용 시드 데이터 생성기
// =============================================================================
//
// 이 파일은 개발/디버그 환경에서만 사용됩니다.
// 릴리즈 빌드에서는 이 파일의 코드가 호출되지 않습니다.
//
// 사용처: ProfileScreen (kDebugMode 가드 내부)
// 삭제 시점: 팀 기능 QA 완료 후, 또는 관리자 웹앱에서 팀 데이터 운영 투입 후
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/logger_util.dart';

/// ⚠️ DEBUG ONLY
///
/// Firestore에 테스트용 팀 데이터를 생성합니다.
/// - 팀 1개 생성 (현재 로그인 유저가 팀장)
/// - 가상 팀원 3명 생성 (users + member_year_profiles + 통독 통계)
///
/// 릴리즈 빌드에서는 절대 호출하지 마세요.
class TeamTestDataSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 테스트 데이터가 이미 존재하는지 확인
  Future<bool> hasTestData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final snapshot =
        await _firestore
            .collection('teams')
            .where('leaderUid', isEqualTo: uid)
            .where('_isTestData', isEqualTo: true)
            .limit(1)
            .get();
    return snapshot.docs.isNotEmpty;
  }

  /// 복합 케이스 테스트 데이터가 이미 존재하는지 확인
  Future<bool> hasComplexTestData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final snapshot =
        await _firestore
            .collection('teams')
            .where('leaderUid', isEqualTo: uid)
            .where('_isComplexTestData', isEqualTo: true)
            .limit(1)
            .get();
    return snapshot.docs.isNotEmpty;
  }

  /// 테스트 팀 + 팀원 데이터 생성
  Future<String> seedTestData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인 상태에서만 시드 데이터를 생성할 수 있습니다.');
    }

    final String leaderUid = user.uid;
    final int scheduleYear = DateHelper.getScheduleYear(DateTime.now());
    const String churchId = 'somang';

    // 현재 유저의 이름 가져오기
    final userDoc = await _firestore.collection('users').doc(leaderUid).get();
    final String leaderName =
        userDoc.exists
            ? (userDoc.data()?['name'] ?? '테스트팀장')
            : '테스트팀장';

    LoggerUtil.info('[DEBUG SEED] 테스트 데이터 생성 시작');

    // ─── 1. 팀 생성 ─────────────────────────────────────────────────
    final teamRef = _firestore.collection('teams').doc();
    final String teamId = teamRef.id;

    await teamRef.set({
      'name': '테스트 1팀',
      'churchId': churchId,
      'year': scheduleYear,
      'leaderUid': leaderUid,
      'leaderName': leaderName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      '_isTestData': true, // ⚠️ 테스트 데이터 식별용 플래그
    });

    LoggerUtil.info('[DEBUG SEED] 팀 생성 완료: $teamId');

    // ─── 2. 팀장의 member_year_profile 업데이트 ──────────────────────
    await _firestore
        .collection('member_year_profiles')
        .doc(scheduleYear.toString())
        .collection('users')
        .doc(leaderUid)
        .set({
          'uid': leaderUid,
          'scheduleYear': scheduleYear,
          'churchId': churchId,
          'teamIds': [teamId],
          'isTeamLeader': true,
          'updatedAt': FieldValue.serverTimestamp(),
          '_isTestData': true,
        }, SetOptions(merge: true));

    // ─── 3. 가상 팀원 생성 ──────────────────────────────────────────
    final List<_FakeMember> fakeMembers = [
      _FakeMember(name: '김믿음', phone: '+8201011111111', completedDays: 42),
      _FakeMember(name: '이소망', phone: '+8201022222222', completedDays: 28),
      _FakeMember(name: '박사랑', phone: '+8201033333333', completedDays: 15),
    ];

    for (final member in fakeMembers) {
      final String fakeUid = 'test_${member.name}_$scheduleYear';

      // users 컬렉션에 가상 유저 생성
      await _firestore.collection('users').doc(fakeUid).set({
        'uid': fakeUid,
        'phoneNumber': member.phone,
        'name': member.name,
        'churchId': churchId,
        'role': 'member',
        'isActive': true,
        'isTestUser': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        '_isTestData': true,
      });

      // member_year_profiles에 팀 배정
      await _firestore
          .collection('member_year_profiles')
          .doc(scheduleYear.toString())
          .collection('users')
          .doc(fakeUid)
          .set({
            'uid': fakeUid,
            'scheduleYear': scheduleYear,
            'churchId': churchId,
            'teamIds': [teamId],
            'isTeamLeader': false,
            'updatedAt': FieldValue.serverTimestamp(),
            '_isTestData': true,
          });

      // 통독 통계 생성
      await _firestore.doc('users/$fakeUid/stats/$scheduleYear').set({
        'total_days_completed': member.completedDays,
        'streak_current': (member.completedDays % 7) + 1,
        'streak_max': 12,
        'last_completed_date': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 이번 주 완료 데이터 일부 생성 (진행상황 시각화 테스트용)
      await _seedWeeklyCompletions(
        fakeUid: fakeUid,
        scheduleYear: scheduleYear,
        completedDaysThisWeek: member.completedDays % 5, // 0~4일
      );

      LoggerUtil.info('[DEBUG SEED] 가상 팀원 생성: ${member.name} ($fakeUid)');
    }

    LoggerUtil.info('[DEBUG SEED] 테스트 데이터 생성 완료');
    return teamId;
  }

  /// 이번 주 완료 데이터 시드
  Future<void> _seedWeeklyCompletions({
    required String fakeUid,
    required int scheduleYear,
    required int completedDaysThisWeek,
  }) async {
    final DateTime monday = DateHelper.getThisWeekMonday();

    for (int day = 1; day <= completedDaysThisWeek; day++) {
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

      final String docId = '${scheduleYear}_${currentWeek}_$currentDay';
      await _firestore
          .collection('users/$fakeUid/completions')
          .doc(docId)
          .set({
            'date': dateForDay.toIso8601String(),
            'year': scheduleYear,
            'week': currentWeek,
            'day': currentDay,
            'readings': [],
            'createdAt': FieldValue.serverTimestamp(),
          });
    }
  }

  /// ⚠️ DEBUG ONLY – 복합 케이스 테스트 데이터 생성
  ///
  /// 검증 시나리오:
  /// - 현재 유저: 팀A 팀장 + 팀B 팀장 (다중 팀 팀장)
  /// - test_부팀장: 팀C 팀장 + 팀A 팀원 (팀장+팀원 겸직)
  /// - test_중복멤버: 팀A + 팀B 동시 소속 (여러 팀 중복 멤버)
  Future<void> seedComplexTestData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인 상태에서만 시드 데이터를 생성할 수 있습니다.');
    }

    final String leaderUid = user.uid;
    final int scheduleYear = DateHelper.getScheduleYear(DateTime.now());
    const String churchId = 'somang';

    final userDoc = await _firestore.collection('users').doc(leaderUid).get();
    final String leaderName =
        userDoc.exists ? (userDoc.data()?['name'] ?? '테스트팀장') : '테스트팀장';

    final String subLeaderUid = 'test_부팀장_$scheduleYear';
    final String dupMemberUid = 'test_중복멤버_$scheduleYear';

    LoggerUtil.info('[DEBUG SEED] 복합 케이스 테스트 데이터 생성 시작');

    // ─── 1. 팀 3개 생성 ────────────────────────────────────────────
    final teamARef = _firestore.collection('teams').doc();
    final teamBRef = _firestore.collection('teams').doc();
    final teamCRef = _firestore.collection('teams').doc();
    final String teamAId = teamARef.id;
    final String teamBId = teamBRef.id;
    final String teamCId = teamCRef.id;

    await Future.wait([
      teamARef.set({
        'name': '복합테스트 A팀 (현재유저 팀장)',
        'churchId': churchId,
        'year': scheduleYear,
        'leaderUid': leaderUid,
        'leaderName': leaderName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        '_isTestData': true,
        '_isComplexTestData': true,
      }),
      teamBRef.set({
        'name': '복합테스트 B팀 (현재유저 팀장)',
        'churchId': churchId,
        'year': scheduleYear,
        'leaderUid': leaderUid,
        'leaderName': leaderName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        '_isTestData': true,
        '_isComplexTestData': true,
      }),
      teamCRef.set({
        'name': '복합테스트 C팀 (부팀장 팀장)',
        'churchId': churchId,
        'year': scheduleYear,
        'leaderUid': subLeaderUid,
        'leaderName': '부팀장',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        '_isTestData': true,
        '_isComplexTestData': true,
      }),
    ]);

    LoggerUtil.info('[DEBUG SEED] 팀 3개 생성 완료: A=$teamAId, B=$teamBId, C=$teamCId');

    // ─── 2. 현재 유저 member_year_profile 업데이트 (A + B팀 팀장) ──
    final memberProfilesRef = _firestore
        .collection('member_year_profiles')
        .doc(scheduleYear.toString())
        .collection('users');

    await memberProfilesRef.doc(leaderUid).set({
      'uid': leaderUid,
      'scheduleYear': scheduleYear,
      'churchId': churchId,
      'teamIds': FieldValue.arrayUnion([teamAId, teamBId]),
      'isTeamLeader': true,
      'updatedAt': FieldValue.serverTimestamp(),
      '_isTestData': true,
    }, SetOptions(merge: true));

    // ─── 3. 가상 유저 생성 ─────────────────────────────────────────

    // 3a. test_부팀장: C팀 팀장 + A팀 팀원
    await _createFakeUser(
      uid: subLeaderUid,
      name: '부팀장',
      phone: '+8201044444444',
      churchId: churchId,
      scheduleYear: scheduleYear,
    );
    await memberProfilesRef.doc(subLeaderUid).set({
      'uid': subLeaderUid,
      'scheduleYear': scheduleYear,
      'churchId': churchId,
      'teamIds': [teamAId, teamCId],
      'isTeamLeader': false, // uid==leaderUid 비교로 팀별 판별
      'updatedAt': FieldValue.serverTimestamp(),
      '_isTestData': true,
    });
    await _seedStats(subLeaderUid, scheduleYear, completedDays: 35);
    await _seedWeeklyCompletions(
      fakeUid: subLeaderUid,
      scheduleYear: scheduleYear,
      completedDaysThisWeek: 3,
    );
    LoggerUtil.info('[DEBUG SEED] test_부팀장 생성 (A팀 팀원 + C팀 팀장)');

    // 3b. test_중복멤버: A팀 + B팀 동시 소속
    await _createFakeUser(
      uid: dupMemberUid,
      name: '중복멤버',
      phone: '+8201055555555',
      churchId: churchId,
      scheduleYear: scheduleYear,
    );
    await memberProfilesRef.doc(dupMemberUid).set({
      'uid': dupMemberUid,
      'scheduleYear': scheduleYear,
      'churchId': churchId,
      'teamIds': [teamAId, teamBId],
      'isTeamLeader': false,
      'updatedAt': FieldValue.serverTimestamp(),
      '_isTestData': true,
    });
    await _seedStats(dupMemberUid, scheduleYear, completedDays: 20);
    await _seedWeeklyCompletions(
      fakeUid: dupMemberUid,
      scheduleYear: scheduleYear,
      completedDaysThisWeek: 2,
    );
    LoggerUtil.info('[DEBUG SEED] test_중복멤버 생성 (A팀 + B팀 동시 소속)');

    // 3c. A팀 일반 팀원 2명
    for (final m in [
      _FakeMember(name: '김믿음A', phone: '+8201011111112', completedDays: 42),
      _FakeMember(name: '이소망A', phone: '+8201022222212', completedDays: 28),
    ]) {
      final fakeUid = 'test_${m.name}_$scheduleYear';
      await _createFakeUser(
        uid: fakeUid,
        name: m.name,
        phone: m.phone,
        churchId: churchId,
        scheduleYear: scheduleYear,
      );
      await memberProfilesRef.doc(fakeUid).set({
        'uid': fakeUid,
        'scheduleYear': scheduleYear,
        'churchId': churchId,
        'teamIds': [teamAId],
        'isTeamLeader': false,
        'updatedAt': FieldValue.serverTimestamp(),
        '_isTestData': true,
      });
      await _seedStats(fakeUid, scheduleYear, completedDays: m.completedDays);
      await _seedWeeklyCompletions(
        fakeUid: fakeUid,
        scheduleYear: scheduleYear,
        completedDaysThisWeek: m.completedDays % 5,
      );
    }

    // 3d. B팀 일반 팀원 1명
    final memberBUid = 'test_박사랑B_$scheduleYear';
    await _createFakeUser(
      uid: memberBUid,
      name: '박사랑B',
      phone: '+8201033333312',
      churchId: churchId,
      scheduleYear: scheduleYear,
    );
    await memberProfilesRef.doc(memberBUid).set({
      'uid': memberBUid,
      'scheduleYear': scheduleYear,
      'churchId': churchId,
      'teamIds': [teamBId],
      'isTeamLeader': false,
      'updatedAt': FieldValue.serverTimestamp(),
      '_isTestData': true,
    });
    await _seedStats(memberBUid, scheduleYear, completedDays: 15);
    await _seedWeeklyCompletions(
      fakeUid: memberBUid,
      scheduleYear: scheduleYear,
      completedDaysThisWeek: 0,
    );

    // 3e. C팀 일반 팀원 2명
    for (final m in [
      _FakeMember(name: '최성심', phone: '+8201066666666', completedDays: 30),
      _FakeMember(name: '정은혜', phone: '+8201077777777', completedDays: 10),
    ]) {
      final fakeUid = 'test_${m.name}_$scheduleYear';
      await _createFakeUser(
        uid: fakeUid,
        name: m.name,
        phone: m.phone,
        churchId: churchId,
        scheduleYear: scheduleYear,
      );
      await memberProfilesRef.doc(fakeUid).set({
        'uid': fakeUid,
        'scheduleYear': scheduleYear,
        'churchId': churchId,
        'teamIds': [teamCId],
        'isTeamLeader': false,
        'updatedAt': FieldValue.serverTimestamp(),
        '_isTestData': true,
      });
      await _seedStats(fakeUid, scheduleYear, completedDays: m.completedDays);
      await _seedWeeklyCompletions(
        fakeUid: fakeUid,
        scheduleYear: scheduleYear,
        completedDaysThisWeek: m.completedDays % 5,
      );
    }

    LoggerUtil.info('[DEBUG SEED] 복합 케이스 테스트 데이터 생성 완료');
  }

  Future<void> _createFakeUser({
    required String uid,
    required String name,
    required String phone,
    required String churchId,
    required int scheduleYear,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'phoneNumber': phone,
      'name': name,
      'churchId': churchId,
      'role': 'member',
      'isActive': true,
      'isTestUser': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      '_isTestData': true,
    });
  }

  Future<void> _seedStats(
    String uid,
    int scheduleYear, {
    required int completedDays,
  }) async {
    await _firestore.doc('users/$uid/stats/$scheduleYear').set({
      'total_days_completed': completedDays,
      'streak_current': (completedDays % 7) + 1,
      'streak_max': 12,
      'last_completed_date': DateTime.now().toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ⚠️ 테스트 데이터 전체 삭제
  Future<void> removeTestData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final int scheduleYear = DateHelper.getScheduleYear(DateTime.now());

    LoggerUtil.info('[DEBUG SEED] 테스트 데이터 삭제 시작');

    // 1. 테스트 팀 조회
    final teamsSnapshot =
        await _firestore
            .collection('teams')
            .where('_isTestData', isEqualTo: true)
            .get();

    for (final teamDoc in teamsSnapshot.docs) {
      final String teamId = teamDoc.id;

      // 2. 해당 팀의 member_year_profiles 에서 테스트 데이터 삭제
      final membersSnapshot =
          await _firestore
              .collection('member_year_profiles')
              .doc(scheduleYear.toString())
              .collection('users')
              .where('teamIds', arrayContains: teamId)
              .where('_isTestData', isEqualTo: true)
              .get();

      for (final memberDoc in membersSnapshot.docs) {
        final String memberUid = memberDoc.id;

        // 가상 유저의 completions 삭제
        if (memberUid.startsWith('test_')) {
          final completions =
              await _firestore
                  .collection('users/$memberUid/completions')
                  .get();
          for (final c in completions.docs) {
            await c.reference.delete();
          }
          // 가상 유저의 stats 삭제
          final stats =
              await _firestore.collection('users/$memberUid/stats').get();
          for (final s in stats.docs) {
            await s.reference.delete();
          }
          // 가상 유저 문서 삭제
          await _firestore.collection('users').doc(memberUid).delete();
        }

        // member_year_profile 삭제
        await memberDoc.reference.delete();
      }

      // 3. 팀장의 member_year_profile에서 teamIds만 초기화 (문서 자체는 유지)
      await _firestore
          .collection('member_year_profiles')
          .doc(scheduleYear.toString())
          .collection('users')
          .doc(uid)
          .update({
            'teamIds': FieldValue.arrayRemove([teamId]),
            'isTeamLeader': false,
            '_isTestData': FieldValue.delete(),
          });

      // 4. 팀 문서 삭제
      await teamDoc.reference.delete();
    }

    LoggerUtil.info('[DEBUG SEED] 테스트 데이터 삭제 완료');
  }
}

/// 가상 팀원 정보 (내부 사용)
class _FakeMember {
  final String name;
  final String phone;
  final int completedDays;

  const _FakeMember({
    required this.name,
    required this.phone,
    required this.completedDays,
  });
}

