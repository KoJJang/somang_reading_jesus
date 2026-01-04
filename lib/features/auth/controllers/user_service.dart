import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../../../core/utils/logger_util.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 사용자의 UID 얻기
  String? get currentUserId => _auth.currentUser?.uid;

  // 현재 사용자의 전화번호 얻기
  String? get currentUserPhone {
    final user = _auth.currentUser;
    if (user?.phoneNumber != null) {
      return user!.phoneNumber;
    }
    return null;
  }

  // 사용자 컬렉션 레퍼런스
  CollectionReference get _usersCollection => _firestore.collection('users');

  // 현재 사용자의 문서 레퍼런스
  DocumentReference? get _currentUserDoc =>
      currentUserId != null ? _usersCollection.doc(currentUserId) : null;

  // 사용자 프로필 생성 또는 업데이트
  Future<void> saveUserProfile({
    required String name,
    DateTime? birthDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      LoggerUtil.error('사용자가 인증되지 않은 상태에서 프로필 저장 시도');
      throw Exception('사용자가 인증되지 않았습니다.');
    }

    if (currentUserId == null || user.phoneNumber == null) {
      LoggerUtil.error('사용자 정보 부족: uid=${user.uid}, phone=${user.phoneNumber}');
      throw Exception('사용자 정보가 부족합니다.');
    }

    try {
      // 이미 프로필이 있는지 확인
      final docSnapshot = await _currentUserDoc!.get();

      if (docSnapshot.exists) {
        // 기존 데이터 가져오기
        final userData = docSnapshot.data() as Map<String, dynamic>;
        final existingProfile = UserProfile.fromMap(userData);

        // 프로필 업데이트
        final updatedProfile = existingProfile.copyWith(
          name: name,
          birthDate: birthDate ?? existingProfile.birthDate,
        );

        LoggerUtil.info('사용자 프로필 업데이트: $currentUserId');
        // ✅ merge로 업데이트하여, 앱/관리자 웹에서 추가한 필드를 덮어쓰지 않도록 보장
        await _currentUserDoc!.set(updatedProfile.toMap(), SetOptions(merge: true));
      } else {
        // 새 프로필 생성
        final Map<String, dynamic> profileData = UserProfile(
          uid: currentUserId!,
          phoneNumber: user.phoneNumber ?? '',
          name: name,
        ).toMap();

        // 생년월일이 제공된 경우에만 추가
        if (birthDate != null) {
          profileData['birthDate'] = birthDate;
        }

        LoggerUtil.info('새 사용자 프로필 생성: $currentUserId');
        await _currentUserDoc!.set(profileData, SetOptions(merge: true));
      }
    } catch (e) {
      LoggerUtil.error('프로필 저장 중 오류: $e');
      throw Exception('프로필 저장 중 오류가 발생했습니다: $e');
    }
  }

  // 회원 데이터 삭제
  Future<void> deleteUserData() async {
    if (currentUserId == null) {
      LoggerUtil.error('사용자가 인증되지 않은 상태에서 데이터 삭제 시도');
      throw Exception('사용자가 인증되지 않았습니다.');
    }

    try {
      LoggerUtil.info('사용자 데이터 삭제 시작: $currentUserId');
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
      LoggerUtil.info('사용자 데이터 삭제 완료: $currentUserId');
    } catch (e) {
      LoggerUtil.error('사용자 데이터 삭제 중 오류: $e');
      throw Exception('사용자 데이터 삭제 중 오류가 발생했습니다: $e');
    }
  }

  // 사용자 프로필 가져오기
  Future<UserProfile?> getUserProfile() async {
    if (currentUserId == null) {
      LoggerUtil.info('인증되지 않은 상태에서 프로필 조회 시도');
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
      LoggerUtil.error('사용자 프로필 가져오기 오류: $e');
      return null;
    }
  }

  // 사용자 프로필 실시간 구독
  Stream<UserProfile?> userProfileStream() {
    if (currentUserId == null) {
      LoggerUtil.info('인증되지 않은 상태에서 프로필 스트림 구독 시도');
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
      LoggerUtil.info('인증되지 않은 상태에서 프로필 존재 여부 확인 시도');
      return false;
    }

    try {
      final docSnapshot = await _currentUserDoc!.get();
      return docSnapshot.exists;
    } catch (e) {
      LoggerUtil.error('프로필 존재 여부 확인 중 오류: $e');
      return false;
    }
  }

  // 인증과 프로필 모두 완료되었는지 확인
  Future<bool> isAuthenticationComplete() async {
    // 인증 여부 확인
    if (currentUserId == null) {
      return false;
    }

    // 프로필 여부 확인
    return await hasUserProfile();
  }
}
