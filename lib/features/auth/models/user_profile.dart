import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { member, leader, admin }

class UserProfile {
  final String uid;
  final String phoneNumber;
  final String name;
  final DateTime? birthDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isTestUser;
  final String churchId;
  final String? affiliation;
  final UserRole role;
  final String? memo;
  final bool isActive;

  UserProfile({
    required this.uid,
    required this.phoneNumber,
    required this.name,
    this.birthDate,
    this.isTestUser = false,
    this.churchId = 'somang',
    this.affiliation,
    this.role = UserRole.member,
    this.memo,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  static DateTime _parseTimestampOrNow(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }

  static DateTime? _parseBirthDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return defaultValue;
  }

  static UserRole _parseRole(dynamic value) {
    final String raw = (value ?? '').toString();
    if (raw == 'admin') return UserRole.admin;
    if (raw == 'leader') return UserRole.leader;
    return UserRole.member;
  }

  static String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.leader:
        return 'leader';
      case UserRole.member:
        return 'member';
    }
  }

  // Firestore에서 데이터를 가져올 때 사용하는 팩토리 생성자
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final birthDateValue = map['birthDate'];
    final DateTime? birthDate = _parseBirthDate(birthDateValue);

    final String name = (map['name'] ?? map['displayName'] ?? map['userName'] ?? '').toString().trim();
    final String phone = (map['phoneNumber'] ?? map['phone'] ?? '').toString();

    return UserProfile(
      uid: (map['uid'] ?? '').toString(),
      phoneNumber: phone,
      name: name,
      birthDate: birthDate,
      isTestUser: _parseBool(map['isTestUser']),
      churchId: map['churchId'] ?? 'somang',
      affiliation: map['affiliation'],
      role: _parseRole(map['role']),
      memo: map['memo'],
      isActive: _parseBool(map['isActive'], defaultValue: true),
      createdAt: _parseTimestampOrNow(map['createdAt']),
      updatedAt: _parseTimestampOrNow(map['updatedAt']),
    );
  }

  // Firestore에 데이터를 저장할 때 사용하는 메서드
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'phoneNumber': phoneNumber,
      'name': name,
      'createdAt': createdAt,
      'updatedAt': DateTime.now(),
      'isTestUser': isTestUser,
      'churchId': churchId,
      'role': _roleToString(role),
      'isActive': isActive,
    };

    // birthDate가 null이 아닌 경우에만 추가
    if (birthDate != null) {
      map['birthDate'] = birthDate;
    }
    if (affiliation != null) {
      map['affiliation'] = affiliation;
    }
    if (memo != null) {
      map['memo'] = memo;
    }

    return map;
  }

  // 프로필 정보 업데이트 시 사용하는 메서드
  UserProfile copyWith({
    String? name,
    DateTime? birthDate,
    bool? isTestUser,
    String? churchId,
    String? affiliation,
    UserRole? role,
    String? memo,
    bool? isActive,
  }) {
    return UserProfile(
      uid: uid,
      phoneNumber: phoneNumber,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      isTestUser: isTestUser ?? this.isTestUser,
      churchId: churchId ?? this.churchId,
      affiliation: affiliation ?? this.affiliation,
      role: role ?? this.role,
      memo: memo ?? this.memo,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
