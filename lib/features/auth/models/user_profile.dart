import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String phoneNumber;
  final String name;
  final DateTime birthDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.uid,
    required this.phoneNumber,
    required this.name,
    required this.birthDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : this.createdAt = createdAt ?? DateTime.now(),
       this.updatedAt = updatedAt ?? DateTime.now();

  // Firestore에서 데이터를 가져올 때 사용하는 팩토리 생성자
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      name: map['name'] ?? '',
      birthDate: (map['birthDate'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Firestore에 데이터를 저장할 때 사용하는 메서드
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'name': name,
      'birthDate': birthDate,
      'createdAt': createdAt,
      'updatedAt': DateTime.now(),
    };
  }

  // 프로필 정보 업데이트 시 사용하는 메서드
  UserProfile copyWith({String? name, DateTime? birthDate}) {
    return UserProfile(
      uid: this.uid,
      phoneNumber: this.phoneNumber,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      createdAt: this.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
