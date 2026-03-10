import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reading_jesus_somang/core/utils/date_helper.dart';
import 'package:reading_jesus_somang/features/team/services/team_service.dart';

void main() {
  // 현재 스케줄 연도를 실제 서비스와 동일하게 사용
  final int year = DateHelper.getScheduleYear(DateTime.now());
  final String yearStr = year.toString();

  late FakeFirebaseFirestore fs;

  setUp(() => fs = FakeFirebaseFirestore());

  // ─── 헬퍼 ─────────────────────────────────────────────────────────────────

  /// teams/{id} 생성 후 teamId 반환
  Future<String> makeTeam({
    required String name,
    required String leaderUid,
  }) async {
    final ref = fs.collection('teams').doc();
    await ref.set({
      'name': name,
      'churchId': 'somang',
      'year': year,
      'leaderUid': leaderUid,
      'leaderName': name,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
    return ref.id;
  }

  /// member_year_profiles/{year}/users/{uid} 설정
  Future<void> setProfile(String uid, Map<String, dynamic> data) =>
      fs.collection('member_year_profiles').doc(yearStr).collection('users').doc(uid).set(data);

  /// users/{uid} 설정
  Future<void> setUser(String uid, String name) =>
      fs.collection('users').doc(uid).set({'uid': uid, 'name': name, 'phoneNumber': ''});

  /// member_year_profiles/{year}/users/{uid} 읽기
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await fs.collection('member_year_profiles').doc(yearStr).collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  TeamService service(String uid) => TeamService(firestore: fs, testCurrentUid: uid);

  // ─── getMyTeams() ──────────────────────────────────────────────────────────

  group('getMyTeams()', () {
    test('프로필 문서 없음 → 빈 리스트', () async {
      expect(await service('uid1').getMyTeams(), isEmpty);
    });

    test('teamIds 빈 배열 → 빈 리스트', () async {
      await setProfile('uid1', {'teamIds': [], 'isTeamLeader': false});
      expect(await service('uid1').getMyTeams(), isEmpty);
    });

    test('teamIds 1개 → 팀 1개 반환', () async {
      final tid = await makeTeam(name: '강정순 팀', leaderUid: 'uid1');
      await setProfile('uid1', {'teamIds': [tid], 'isTeamLeader': true});

      final teams = await service('uid1').getMyTeams();

      expect(teams.length, 1);
      expect(teams.first.teamId, tid);
      expect(teams.first.name, '강정순 팀');
    });

    test('teamIds 3개 → 팀 3개 모두 반환', () async {
      final t1 = await makeTeam(name: '박진주 팀A', leaderUid: 'uid1');
      final t2 = await makeTeam(name: '박진주 팀B', leaderUid: 'uid1');
      final t3 = await makeTeam(name: '박진주 팀C', leaderUid: 'uid1');
      await setProfile('uid1', {'teamIds': [t1, t2, t3], 'isTeamLeader': true});

      final teams = await service('uid1').getMyTeams();

      expect(teams.length, 3);
      expect(teams.map((t) => t.teamId).toSet(), {t1, t2, t3});
    });

    test('구버전 teamId(String) 필드 → 폴백으로 팀 1개 반환', () async {
      final tid = await makeTeam(name: '이규한 팀', leaderUid: 'uid1');
      await setProfile('uid1', {'teamId': tid, 'isTeamLeader': true}); // old field

      final teams = await service('uid1').getMyTeams();

      expect(teams.length, 1);
      expect(teams.first.teamId, tid);
    });

    test('teamIds에 있는 팀 문서가 삭제된 경우 → 해당 팀 제외 후 반환', () async {
      final existing = await makeTeam(name: '살아있는 팀', leaderUid: 'uid1');
      await setProfile('uid1', {
        'teamIds': [existing, 'ghost_team_id'],
        'isTeamLeader': true,
      });

      final teams = await service('uid1').getMyTeams();

      expect(teams.length, 1);
      expect(teams.first.teamId, existing);
    });
  });

  // ─── addMemberToTeam() ────────────────────────────────────────────────────

  group('addMemberToTeam()', () {
    test('기존 teamIds에 새 teamId를 arrayUnion으로 추가', () async {
      const leaderUid = 'leader1';
      const memberUid = 'member1';
      final existingTid = await makeTeam(name: '기존 팀', leaderUid: leaderUid);
      final newTid = await makeTeam(name: '새 팀', leaderUid: leaderUid);

      await setProfile(memberUid, {'uid': memberUid, 'teamIds': [existingTid], 'isTeamLeader': false});

      await service(leaderUid).addMemberToTeam(teamId: newTid, memberUid: memberUid);

      final profile = await getProfile(memberUid);
      final teamIds = List<String>.from(profile!['teamIds'] as List);
      expect(teamIds, containsAll([existingTid, newTid]));
      expect(teamIds.length, 2);
    });

    test('중복 추가 시 teamIds 길이 변화 없음 (arrayUnion 멱등성)', () async {
      const leaderUid = 'leader1';
      const memberUid = 'member1';
      final tid = await makeTeam(name: '팀', leaderUid: leaderUid);

      await setProfile(memberUid, {'uid': memberUid, 'teamIds': [tid], 'isTeamLeader': false});

      await service(leaderUid).addMemberToTeam(teamId: tid, memberUid: memberUid);

      final profile = await getProfile(memberUid);
      expect((profile!['teamIds'] as List).length, 1);
    });

    test('팀장이 다른 팀 팀원으로 추가될 때 isTeamLeader 덮어쓰지 않음', () async {
      const shinUid = 'shin_jiyoung';
      const leeUid = 'lee_gyuhan';
      final shinTeamId = await makeTeam(name: '신지영 팀', leaderUid: shinUid);
      final leeTeamId = await makeTeam(name: '이규한 팀', leaderUid: leeUid);

      // 신지영은 이미 본인 팀 팀장
      await setProfile(shinUid, {'uid': shinUid, 'teamIds': [shinTeamId], 'isTeamLeader': true});

      // 이규한이 신지영을 자기 팀 팀원으로 추가
      await service(leeUid).addMemberToTeam(teamId: leeTeamId, memberUid: shinUid);

      final profile = await getProfile(shinUid);
      expect(profile!['isTeamLeader'], isTrue); // 팀장 상태 유지
      final teamIds = List<String>.from(profile['teamIds'] as List);
      expect(teamIds, containsAll([shinTeamId, leeTeamId])); // 양쪽 팀 모두 포함
    });
  });

  // ─── removeMemberFromTeam() ───────────────────────────────────────────────

  group('removeMemberFromTeam()', () {
    test('2개 팀 중 1개만 arrayRemove로 제거, 나머지 유지', () async {
      const leaderUid = 'leader1';
      const memberUid = 'member1';
      final t1 = await makeTeam(name: '팀A', leaderUid: leaderUid);
      final t2 = await makeTeam(name: '팀B', leaderUid: leaderUid);

      await setProfile(memberUid, {'uid': memberUid, 'teamIds': [t1, t2], 'isTeamLeader': false});

      await service(leaderUid).removeMemberFromTeam(teamId: t1, memberUid: memberUid);

      final profile = await getProfile(memberUid);
      final teamIds = List<String>.from(profile!['teamIds'] as List);
      expect(teamIds, [t2]);
      expect(teamIds, isNot(contains(t1)));
    });

    test('3개 팀 중 중간 팀 제거 시 나머지 2개 유지', () async {
      const leaderUid = 'leader1';
      const memberUid = 'goo_seongmo';
      final t1 = await makeTeam(name: '팀A', leaderUid: leaderUid);
      final t2 = await makeTeam(name: '팀B', leaderUid: leaderUid);
      final t3 = await makeTeam(name: '팀C', leaderUid: leaderUid);

      await setProfile(memberUid, {'uid': memberUid, 'teamIds': [t1, t2, t3], 'isTeamLeader': false});

      await service(leaderUid).removeMemberFromTeam(teamId: t2, memberUid: memberUid);

      final profile = await getProfile(memberUid);
      final teamIds = List<String>.from(profile!['teamIds'] as List);
      expect(teamIds, containsAll([t1, t3]));
      expect(teamIds, isNot(contains(t2)));
    });
  });

  // ─── getTeamMembersWithProgress() ────────────────────────────────────────

  group('getTeamMembersWithProgress()', () {
    test('teamIds arrayContains로 해당 팀원만 반환', () async {
      const leaderUid = 'leader1';
      const memberUid = 'member1';
      const outsiderUid = 'outsider1';
      final tid = await makeTeam(name: '강정순 팀', leaderUid: leaderUid);
      final otherTid = await makeTeam(name: '다른 팀', leaderUid: 'other_leader');

      await setUser(leaderUid, '강정순');
      await setUser(memberUid, '고영남');
      await setUser(outsiderUid, '외부인');

      await setProfile(leaderUid, {'teamIds': [tid], 'isTeamLeader': true});
      await setProfile(memberUid, {'teamIds': [tid], 'isTeamLeader': false});
      await setProfile(outsiderUid, {'teamIds': [otherTid], 'isTeamLeader': false}); // 다른 팀

      final members = await service(leaderUid).getTeamMembersWithProgress(teamId: tid);

      expect(members.map((m) => m.uid).toSet(), {leaderUid, memberUid});
      expect(members.map((m) => m.uid), isNot(contains(outsiderUid)));
    });

    test('isTeamLeader: 팀의 leaderUid인 경우만 true', () async {
      const leaderUid = 'leader1';
      const memberUid = 'member1';
      final tid = await makeTeam(name: '강정순 팀', leaderUid: leaderUid);

      await setUser(leaderUid, '강정순');
      await setUser(memberUid, '고영남');
      await setProfile(leaderUid, {'teamIds': [tid], 'isTeamLeader': true});
      await setProfile(memberUid, {'teamIds': [tid], 'isTeamLeader': false});

      final members = await service(leaderUid).getTeamMembersWithProgress(teamId: tid);
      final leader = members.firstWhere((m) => m.uid == leaderUid);
      final member = members.firstWhere((m) => m.uid == memberUid);

      expect(leader.isTeamLeader, isTrue);
      expect(member.isTeamLeader, isFalse);
    });

    test('팀장이 먼저, 나머지는 이름순 정렬', () async {
      const leaderUid = 'leader1';
      final tid = await makeTeam(name: '팀', leaderUid: leaderUid);

      await setUser(leaderUid, '팀장');
      await setUser('m_c', '다멤버');
      await setUser('m_a', '가멤버');
      await setUser('m_b', '나멤버');

      await setProfile(leaderUid, {'teamIds': [tid], 'isTeamLeader': true});
      for (final uid in ['m_a', 'm_b', 'm_c']) {
        await setProfile(uid, {'teamIds': [tid], 'isTeamLeader': false});
      }

      final members = await service(leaderUid).getTeamMembersWithProgress(teamId: tid);

      expect(members.first.uid, leaderUid); // 팀장 최상단
      expect(members.map((m) => m.name).skip(1).toList(), ['가멤버', '나멤버', '다멤버']);
    });

    test('존재하지 않는 팀 → 빈 리스트', () async {
      final members = await service('uid1').getTeamMembersWithProgress(teamId: 'ghost_id');
      expect(members, isEmpty);
    });
  });

  // ─── 복합 실제 케이스 ──────────────────────────────────────────────────────

  group('실제 데이터 복합 케이스', () {
    test('박진주: 5팀 팀장 + 다른 팀 팀원 → getMyTeams 6개', () async {
      const parkUid = 'park_jinjoo';
      final leadingTeams = await Future.wait([
        makeTeam(name: '박진주 팀1', leaderUid: parkUid),
        makeTeam(name: '박진주 팀2', leaderUid: parkUid),
        makeTeam(name: '박진주 팀3', leaderUid: parkUid),
        makeTeam(name: '박진주 팀4', leaderUid: parkUid),
        makeTeam(name: '박진주 팀5', leaderUid: parkUid),
      ]);
      final memberOfTid = await makeTeam(name: '양용철 팀', leaderUid: 'yang_uid');

      await setProfile(parkUid, {
        'teamIds': [...leadingTeams, memberOfTid],
        'isTeamLeader': true,
      });

      final teams = await service(parkUid).getMyTeams();
      expect(teams.length, 6);
      expect(teams.map((t) => t.teamId).toSet(), {...leadingTeams, memberOfTid});
    });

    test('신지영: 이규한 팀 팀원 + 본인 팀 팀장 → 각 팀에서 isTeamLeader 정확히 판별', () async {
      const shinUid = 'shin_jiyoung';
      const leeUid = 'lee_gyuhan';
      final shinTeamId = await makeTeam(name: '신지영 팀', leaderUid: shinUid);
      final leeTeamId = await makeTeam(name: '이규한 팀', leaderUid: leeUid);

      await setUser(shinUid, '신지영');
      await setUser(leeUid, '이규한');

      // 신지영은 본인 팀 팀장 + 이규한 팀 팀원
      await setProfile(shinUid, {'teamIds': [shinTeamId, leeTeamId], 'isTeamLeader': true});
      await setProfile(leeUid, {'teamIds': [leeTeamId], 'isTeamLeader': true});

      // 이규한 팀에서 신지영은 팀원 (isTeamLeader = false)
      final leeMembers = await service(leeUid).getTeamMembersWithProgress(teamId: leeTeamId);
      final shinInLeeTeam = leeMembers.firstWhere((m) => m.uid == shinUid);
      expect(shinInLeeTeam.isTeamLeader, isFalse);

      // 신지영 팀에서 신지영은 팀장 (isTeamLeader = true)
      final shinMembers = await service(shinUid).getTeamMembersWithProgress(teamId: shinTeamId);
      final shinInShinTeam = shinMembers.firstWhere((m) => m.uid == shinUid);
      expect(shinInShinTeam.isTeamLeader, isTrue);
    });

    test('구성모: 3개 팀 동시 소속 → getMyTeams 3개, 각 팀 멤버 쿼리에서 모두 등장', () async {
      const gooUid = 'goo_seongmo';
      final t1 = await makeTeam(name: '신지영 팀A', leaderUid: 'shin1');
      final t2 = await makeTeam(name: '신지영 팀B', leaderUid: 'shin2');
      final t3 = await makeTeam(name: '이규한 팀', leaderUid: 'lee1');

      await setUser(gooUid, '구성모');
      for (final uid in ['shin1', 'shin2', 'lee1']) {
        await setUser(uid, uid);
      }

      await setProfile(gooUid, {'teamIds': [t1, t2, t3], 'isTeamLeader': false});
      await setProfile('shin1', {'teamIds': [t1], 'isTeamLeader': true});
      await setProfile('shin2', {'teamIds': [t2], 'isTeamLeader': true});
      await setProfile('lee1', {'teamIds': [t3], 'isTeamLeader': true});

      // 구성모 본인 기준
      final myTeams = await service(gooUid).getMyTeams();
      expect(myTeams.length, 3);

      // 각 팀 멤버 조회에서 구성모가 등장
      for (final tid in [t1, t2, t3]) {
        final leaderUid = {'$t1': 'shin1', '$t2': 'shin2', '$t3': 'lee1'}[tid]!;
        final members = await service(leaderUid).getTeamMembersWithProgress(teamId: tid);
        expect(members.map((m) => m.uid), contains(gooUid));
      }
    });

    test('이희정: 자기 이름이 팀원에 등록된 경우 (self-reference) → 자기 팀에서 팀장으로만 등장', () async {
      const heeUid = 'lee_heejeong';
      final tid = await makeTeam(name: '이희정 팀', leaderUid: heeUid);

      await setUser(heeUid, '이희정');
      // 팀장 본인만 teamIds에 포함 (자기 자신 팀원 등록은 importer에서 skip됨)
      await setProfile(heeUid, {'teamIds': [tid], 'isTeamLeader': true});

      final members = await service(heeUid).getTeamMembersWithProgress(teamId: tid);
      expect(members.length, 1);
      expect(members.first.uid, heeUid);
      expect(members.first.isTeamLeader, isTrue);
    });
  });
}
