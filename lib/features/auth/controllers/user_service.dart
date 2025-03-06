import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 사용자의 UID 얻기
  String? get currentUserId => _auth.currentUser?.uid;

  // 현재 사용자의 전화번호 얻기
  String? get currentUserPhone => _auth.currentUser?.phoneNumber;

  // 사용자 컬렉션 레퍼런스
  CollectionReference get _usersCollection => _firestore.collection('users');

  // 현재 사용자의 문서 레퍼런스
  DocumentReference? get _currentUserDoc =>
      currentUserId != null ? _usersCollection.doc(currentUserId) : null;

  // 사용자 프로필 생성 또는 업데이트
  Future<void> saveUserProfile({
    required String name,
    required DateTime birthDate,
  }) async {
    if (currentUserId == null || currentUserPhone == null) {
      throw Exception('사용자가 인증되지 않았습니다.');
    }

    // 이미 프로필이 있는지 확인
    final docSnapshot = await _currentUserDoc!.get();

    if (docSnapshot.exists) {
      // 기존 데이터 가져오기
      final userData = docSnapshot.data() as Map<String, dynamic>;
      final existingProfile = UserProfile.fromMap(userData);

      // 프로필 업데이트
      final updatedProfile = existingProfile.copyWith(
        name: name,
        birthDate: birthDate,
      );

      await _currentUserDoc!.update(updatedProfile.toMap());
    } else {
      // 새 프로필 생성
      final newProfile = UserProfile(
        uid: currentUserId!,
        phoneNumber: currentUserPhone!,
        name: name,
        birthDate: birthDate,
      );

      await _currentUserDoc!.set(newProfile.toMap());
    }
  }

  // 회원 데이터 삭제
  Future<void> deleteUserData() async {
    if (currentUserId == null) {
      throw Exception('사용자가 인증되지 않았습니다.');
    }

    try {
      // 트랜잭션 내에서 사용자 관련 데이터 모두 삭제
      await _firestore.runTransaction((transaction) async {
        // 1. 사용자 프로필 문서 삭제
        transaction.delete(_currentUserDoc!);

        // 2. 통독 완료 데이터 삭제
        final completionsRef = _currentUserDoc!.collection('completions');
        final completionsSnapshot = await completionsRef.get();
        for (final doc in completionsSnapshot.docs) {
          transaction.delete(doc.reference);
        }

        // 3. 통계 데이터 삭제
        final statsRef = _currentUserDoc!.collection('stats');
        final statsSnapshot = await statsRef.get();
        for (final doc in statsSnapshot.docs) {
          transaction.delete(doc.reference);
        }

        // 4. 기타 사용자 관련 데이터 삭제
        // (필요한 경우 추가 컬렉션 삭제 코드 추가)
      });
    } catch (e) {
      throw Exception('사용자 데이터 삭제 중 오류가 발생했습니다: $e');
    }
  }

  // 사용자 프로필 가져오기
  Future<UserProfile?> getUserProfile() async {
    if (currentUserId == null) {
      return null;
    }

    try {
      final docSnapshot = await _currentUserDoc!.get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;
        return UserProfile.fromMap(userData);
      }

      return null;
    } catch (e) {
      print('사용자 프로필 가져오기 오류: $e');
      return null;
    }
  }

  // 사용자 프로필 실시간 구독
  Stream<UserProfile?> userProfileStream() {
    if (currentUserId == null) {
      return Stream.value(null);
    }

    return _currentUserDoc!.snapshots().map((snapshot) {
      if (snapshot.exists) {
        final userData = snapshot.data() as Map<String, dynamic>;
        return UserProfile.fromMap(userData);
      }
      return null;
    });
  }

  // 사용자 프로필이 존재하는지 확인
  Future<bool> hasUserProfile() async {
    if (currentUserId == null) {
      return false;
    }

    final docSnapshot = await _currentUserDoc!.get();
    return docSnapshot.exists;
  }
}
