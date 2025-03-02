import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../controllers/user_service.dart';
import '../models/user_profile.dart';
import '../../../core/constants/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserProfile? _userProfile;
  bool _isLoading = true;
  final _dateFormat = DateFormat('yyyy년 MM월 dd일');

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    // Listen to authentication state changes
    _auth.authStateChanges().listen((User? user) {
      if (mounted) {
        if (user == null) {
          // User logged out, navigate back safely
          if (Navigator.of(context).canPop()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pop();
            });
          }
        } else {
          // User logged in, refresh profile
          _loadUserProfile();
        }
      }
    });
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    if (_auth.currentUser != null) {
      final profile = await _userService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _userProfile = null;
          _isLoading = false;
        });

        // No need to navigate or show snackbar here
        // The authStateChanges listener will handle navigation for unauthenticated users
      }
    }
  }

  Future<void> _signOut() async {
    // Sign out without navigating directly
    await _auth.signOut();

    // Only show snackbar, let the auth state listener handle navigation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그아웃 되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );

      // No explicit navigation here - authStateChanges listener will handle it
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 프로필'),
        actions: [
          // 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _signOut,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userProfile == null
              ? const Center(child: Text('프로필 정보가 없습니다'))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 프로필 이미지
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, size: 70, color: Colors.white),
                    ),
                    const SizedBox(height: 24),

                    // 사용자 이름
                    Text(
                      _userProfile!.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 전화번호
                    Text(
                      _userProfile!.phoneNumber,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),

                    // 프로필 정보 카드
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '기본 정보',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 생년월일
                          _buildProfileItem(
                            Icons.cake,
                            '생년월일',
                            _dateFormat.format(_userProfile!.birthDate),
                          ),

                          const Divider(height: 24),

                          // 계정 생성일
                          _buildProfileItem(
                            Icons.calendar_today,
                            '가입일',
                            _dateFormat.format(_userProfile!.createdAt),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 프로필 수정 버튼
                    ElevatedButton.icon(
                      onPressed: () {
                        // 프로필 수정 화면으로 이동
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (context) => EditProfileScreen(profile: _userProfile),
                        //   ),
                        // );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('프로필 수정'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}
