// =============================================================================
// ⚠️  임시 – 실제 팀 데이터 임포트 (Excel → Firestore)
// =============================================================================
//
// 2026년 팀 신청서 Excel을 JSON으로 변환한 데이터를 Firestore에 반영합니다.
// - 이름으로 users 컬렉션 매칭
// - teams, member_year_profiles 생성/업데이트
//
// 사용: ProfileScreen 디버그 섹션의 "실제 팀 데이터 임포트" 버튼
// 삭제 시점: 관리자 웹앱에서 팀 운영 투입 후
// =============================================================================

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/logger_util.dart';

/// 실제 팀 데이터 임포트 결과
class RealTeamImportResult {
  final int teamsCreated;
  final int leadersMatched;
  final int leadersNotFound;
  final int membersMatched;
  final int membersNotFound;
  final List<String> errors;

  const RealTeamImportResult({
    required this.teamsCreated,
    required this.leadersMatched,
    required this.leadersNotFound,
    required this.membersMatched,
    required this.membersNotFound,
    required this.errors,
  });

  String get summary =>
      '팀 $teamsCreated개 생성 | 팀장: $leadersMatched명 매칭, $leadersNotFound명 미발견 | '
      '팀원: $membersMatched명 매칭, $membersNotFound명 미발견';
}

/// Excel에서 변환한 JSON 기반 실제 팀 데이터 임포트
class RealTeamDataImporter {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _scheduleYear = 2026;
  static const String _churchId = 'somang';
  static const String _assetPath = 'assets/data/teams_2026.json';

  /// 이름 정규화 (공백 축소, 앞뒤 trim)
  static String _normalizeName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 전화번호 정규화: 하이픈/공백 제거, +82 변환 등 여러 형식 시도
  static List<String> _phoneVariants(String phone) {
    final stripped = phone.replaceAll(RegExp(r'[\s\-]'), '');
    final variants = <String>{stripped};
    // 010... → +8210...
    if (stripped.startsWith('010')) {
      variants.add('+82${stripped.substring(1)}');
    }
    // +8210... → 010...
    if (stripped.startsWith('+82')) {
      variants.add('0${stripped.substring(3)}');
    }
    return variants.toList();
  }

  /// 전화번호로 유저 검색 (동명이인 구분용) — 여러 형식 시도
  Future<String?> _findUserUidByPhone(String phone) async {
    if (phone.isEmpty) return null;
    for (final variant in _phoneVariants(phone)) {
      final snapshot = await _firestore
          .collection('users')
          .where('churchId', isEqualTo: _churchId)
          .where('phoneNumber', isEqualTo: variant)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first.id;
    }
    return null;
  }

  /// 유저 검색: 전화번호 우선 → 이름 정확 일치 → 이름 정규화 재시도
  Future<String?> _findUserUid({required String name, String? phone}) async {
    if (phone != null && phone.isNotEmpty) {
      final uid = await _findUserUidByPhone(phone);
      if (uid != null) return uid;
    }
    return _findUserUidByName(name);
  }

  /// 이름으로 유저 검색 (정확 일치 우선, 정규화된 이름으로 재시도)
  Future<String?> _findUserUidByName(String name) async {
    if (name.isEmpty) return null;

    // 1) 정확 일치
    String? uid = await _findUserUidExact(name);
    if (uid != null) return uid;

    // 2) 정규화된 이름으로 재시도
    final normalized = _normalizeName(name);
    if (normalized != name) {
      uid = await _findUserUidExact(normalized);
    }
    return uid;
  }

  Future<String?> _findUserUidExact(String name) async {
    final snapshot = await _firestore
        .collection('users')
        .where('churchId', isEqualTo: _churchId)
        .where('name', isEqualTo: name)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  /// manualAdd: true 항목만 임포트
  Future<RealTeamImportResult> importManualEntriesFromAssets() async {
    return _importFromAssets(manualOnly: true);
  }

  /// assets/data/teams_2026.json 로드 및 임포트
  Future<RealTeamImportResult> importFromAssets() async {
    return _importFromAssets(manualOnly: false);
  }

  Future<RealTeamImportResult> _importFromAssets({required bool manualOnly}) async {
    final errors = <String>[];
    int teamsCreated = 0;
    int leadersMatched = 0;
    int leadersNotFound = 0;
    int membersMatched = 0;
    int membersNotFound = 0;

    String jsonString;
    try {
      jsonString = await rootBundle.loadString(_assetPath);
    } catch (e) {
      LoggerUtil.error('팀 데이터 JSON 로드 실패: $e');
      return RealTeamImportResult(
        teamsCreated: 0,
        leadersMatched: 0,
        leadersNotFound: 0,
        membersMatched: 0,
        membersNotFound: 0,
        errors: ['JSON 파일을 불러올 수 없습니다: $e'],
      );
    }

    List<dynamic> teamsJson;
    try {
      teamsJson = jsonDecode(jsonString) as List<dynamic>;
    } catch (e) {
      return RealTeamImportResult(
        teamsCreated: 0,
        leadersMatched: 0,
        leadersNotFound: 0,
        membersMatched: 0,
        membersNotFound: 0,
        errors: ['JSON 파싱 실패: $e'],
      );
    }

    // manualOnly 모드: manualAdd: true 항목만 처리
    if (manualOnly) {
      teamsJson = teamsJson
          .where((e) => (e as Map<String, dynamic>)['manualAdd'] == true)
          .toList();
    }

    // 팀장 이름 등장 횟수 사전 집계 (동명이인 팀 이름 넘버링용)
    final leaderNameCount = <String, int>{};
    for (final teamData in teamsJson) {
      final name = ((teamData as Map<String, dynamic>)['leaderName'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) leaderNameCount[name] = (leaderNameCount[name] ?? 0) + 1;
    }
    final leaderNameIndex = <String, int>{};

    final yearStr = _scheduleYear.toString();
    final memberProfilesRef = _firestore
        .collection('member_year_profiles')
        .doc(yearStr)
        .collection('users');

    for (final teamData in teamsJson) {
      final map = teamData as Map<String, dynamic>;
      final leaderName = (map['leaderName'] ?? '').toString().trim();
      final leaderPhone = (map['leaderPhone'] ?? '').toString().trim();
      final memberNamesRaw = map['memberNames'];
      final memberNames = (memberNamesRaw is List)
          ? (memberNamesRaw)
              .map((e) => (e ?? '').toString().trim())
              .where((s) => s.isNotEmpty)
              .toList()
          : <String>[];
      final memberPhonesRaw = map['memberPhones'];
      final memberPhones = (memberPhonesRaw is List)
          ? memberPhonesRaw.map((e) => (e ?? '').toString().trim()).toList()
          : <String>[];

      if (leaderName.isEmpty) continue;

      // 팀장 검색 (전화번호 우선)
      final leaderUid = await _findUserUid(name: leaderName, phone: leaderPhone.isEmpty ? null : leaderPhone);
      if (leaderUid == null) {
        leadersNotFound++;
        errors.add('팀장 미발견: $leaderName');
        continue;
      }
      leadersMatched++;

      // 팀장 이름 조회 (users 문서에서)
      final leaderDoc = await _firestore.collection('users').doc(leaderUid).get();
      final leaderDisplayName = leaderDoc.data()?['name'] ?? leaderName;

      // 팀 이름: 동명이인 팀장이면 -1, -2, ... 넘버링
      leaderNameIndex[leaderName] = (leaderNameIndex[leaderName] ?? 0) + 1;
      final int idx = leaderNameIndex[leaderName]!;
      final bool hasDuplicate = (leaderNameCount[leaderName] ?? 1) > 1;
      final String teamName = hasDuplicate
          ? '$leaderDisplayName 팀-$idx'
          : '$leaderDisplayName 팀';

      // 팀 생성
      final teamRef = _firestore.collection('teams').doc();
      final teamId = teamRef.id;

      await teamRef.set({
        'name': teamName,
        'churchId': _churchId,
        'year': _scheduleYear,
        'leaderUid': leaderUid,
        'leaderName': leaderDisplayName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      teamsCreated++;

      // 팀장 member_year_profile
      await memberProfilesRef.doc(leaderUid).set({
        'uid': leaderUid,
        'scheduleYear': _scheduleYear,
        'churchId': _churchId,
        'teamIds': FieldValue.arrayUnion([teamId]),
        'isTeamLeader': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 팀원 추가
      for (int mi = 0; mi < memberNames.length; mi++) {
        final memberName = memberNames[mi];
        if (memberName.isEmpty) continue;
        final memberPhone = mi < memberPhones.length ? memberPhones[mi] : null;

        final memberUid = await _findUserUid(
          name: memberName,
          phone: (memberPhone?.isNotEmpty == true) ? memberPhone : null,
        );
        if (memberUid == null) {
          membersNotFound++;
          errors.add('팀원 미발견: $memberName (팀: $teamName)');
          continue;
        }

        // 자기 자신 스킵 (팀장이 본인 팀 팀원으로 등록된 경우)
        if (memberUid == leaderUid) continue;

        membersMatched++;
        await memberProfilesRef.doc(memberUid).set({
          'uid': memberUid,
          'scheduleYear': _scheduleYear,
          'churchId': _churchId,
          'teamIds': FieldValue.arrayUnion([teamId]),
          // isTeamLeader는 건드리지 않음 — 팀장 본인이 다른 팀 팀원으로 등록될 수 있음
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      LoggerUtil.info('[IMPORT] 팀 생성: $leaderDisplayName ($teamId)');
    }

    return RealTeamImportResult(
      teamsCreated: teamsCreated,
      leadersMatched: leadersMatched,
      leadersNotFound: leadersNotFound,
      membersMatched: membersMatched,
      membersNotFound: membersNotFound,
      errors: errors,
    );
  }
}
