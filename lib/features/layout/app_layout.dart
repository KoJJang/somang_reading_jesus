import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/screens/phone_auth_screen.dart';
import '../auth/screens/profile_screen.dart';
import '../auth/controllers/user_service.dart';

class AppLayout extends StatefulWidget {
  final Widget child;

  const AppLayout({super.key, required this.child});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  bool _isAuthenticated = false;
  late Stream<User?> _authStateStream;
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = _auth.currentUser != null;
    _authStateStream = _auth.authStateChanges();
    _authStateStream.listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    setState(() {
      _isAuthenticated = user != null;
    });
    if (user == null) {
      setState(() {
        _displayName = null;
      });
      return;
    }
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    try {
      final profile = await _userService.getUserProfile();
      if (!mounted) return;
      setState(() {
        _displayName =
            (profile?.name.trim().isNotEmpty == true) ? profile!.name : null;
      });
    } catch (_) {
      // ignore: avoid_catches_without_on_clauses
      if (!mounted) return;
      setState(() {
        _displayName = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: () {
            // 홈 화면으로 이동
            // Navigator.of(
            //   context,
            // ).pushNamedAndRemoveUntil('/', (route) => false);
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/images/icon.png',
                  width: 28,
                  height: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '리딩 지저스',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  fontFamily: 'Pretendard',
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '소망 교회',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  fontFamily: 'Pretendard',
                  // 상단 정렬
                  height: 2.2,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Profile icon
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                // Show profile or navigate to authentication screen based on auth status
                if (_isAuthenticated) {
                  _showProfileMenu(context);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PhoneAuthScreen(),
                    ),
                  ).then((_) {
                    // Refresh state when returning from authentication screen
                    setState(() {
                      _isAuthenticated = _auth.currentUser != null;
                    });
                  });
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor:
                    _isAuthenticated
                        ? Colors.blue.shade100
                        : Colors.grey.shade200,
                child: Icon(
                  _isAuthenticated ? Icons.person : Icons.person_outline,
                  color: _isAuthenticated ? Colors.blue : Colors.grey,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: widget.child,
    );
  }

  // Show profile menu with user info and logout option
  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User info section
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(
                        Icons.person,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName ??
                                _auth.currentUser?.displayName ??
                                '인증된 사용자',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_auth.currentUser?.phoneNumber ?? ""}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Profile button
              ListTile(
                leading: const Icon(Icons.account_circle, color: Colors.blue),
                title: const Text('프로필 정보'),
                onTap: () {
                  Navigator.pop(context); // Close the bottom sheet

                  // Navigate to profile screen with check for authentication
                  if (_isAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  } else {
                    // If somehow user is not authenticated when tapping profile
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('로그인이 필요합니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),

              // Logout button
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context); // Close the bottom sheet first

                  await _auth.signOut();
                  setState(() {
                    _isAuthenticated = false;
                  });

                  if (context.mounted) {
                    // Use post-frame callback for showing SnackBar
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('로그아웃 되었습니다'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
