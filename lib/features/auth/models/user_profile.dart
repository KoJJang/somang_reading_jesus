import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String phoneNumber;
  final String name;
  final DateTime? birthDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isTestUser;

  UserProfile({
    required this.uid,
    required this.phoneNumber,
    required this.name,
    this.birthDate,
    this.isTestUser = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : this.createdAt = createdAt ?? DateTime.now(),
       this.updatedAt = updatedAt ?? DateTime.now();

  // Firestore에서 데이터를 가져올 때 사용하는 팩토리 생성자
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    // birthDate가 없을 수 있으므로 조건부로 처리
    final birthDateValue = map['birthDate'];
    final DateTime? birthDate =
        birthDateValue != null ? (birthDateValue as Timestamp).toDate() : null;

    return UserProfile(
      uid: map['uid'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      name: map['name'] ?? '',
      birthDate: birthDate,
      isTestUser: map['isTestUser'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
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
    };

    // birthDate가 null이 아닌 경우에만 추가
    if (birthDate != null) {
      map['birthDate'] = birthDate;
    }

    return map;
  }

  // 프로필 정보 업데이트 시 사용하는 메서드
  UserProfile copyWith({String? name, DateTime? birthDate, bool? isTestUser}) {
    return UserProfile(
      uid: this.uid,
      phoneNumber: this.phoneNumber,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      isTestUser: isTestUser ?? this.isTestUser,
      createdAt: this.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
