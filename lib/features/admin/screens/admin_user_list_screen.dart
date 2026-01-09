import 'package:flutter/material.dart';
import '../../auth/controllers/user_service.dart';
import '../../auth/models/user_profile.dart';
import 'admin_user_detail_screen.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final UserService _userService = UserService();
  List<UserProfile> _allUsers = [];
  List<UserProfile> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _userService.getAllUsers();
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '사용자 목록을 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = _allUsers;
      });
    } else {
      setState(() {
        _filteredUsers =
            _allUsers.where((user) {
              final nameLower = user.name.toLowerCase();
              final phoneLower = user.phoneNumber.toLowerCase();
              final searchLower = query.toLowerCase();
              return nameLower.contains(searchLower) ||
                  phoneLower.contains(searchLower);
            }).toList();
      });
    }
  }

  String _formatPhoneNumber(String phoneNumber) {
    // 1. +82 제거 및 0으로 대체
    String formatted = phoneNumber.replaceFirst('+82', '0');

    // 2. 숫자만 남기기
    formatted = formatted.replaceAll(RegExp(r'[^0-9]'), '');

    // 3. 010-0000-0000 포맷 (11자리)
    if (formatted.length == 11 && formatted.startsWith('010')) {
      return '${formatted.substring(0, 3)}-${formatted.substring(3, 7)}-${formatted.substring(7)}';
    }
    // 3-1. 010-000-0000 (구형 번호 등 10자리)
    if (formatted.length == 10) {
      return '${formatted.substring(0, 3)}-${formatted.substring(3, 6)}-${formatted.substring(6)}';
    }

    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용자 관리')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: '검색 (이름, 전화번호)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterUsers,
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              user.name.isNotEmpty ? user.name[0] : '?',
                            ),
                          ),
                          title: Text(
                            '${user.name} ${user.role == UserRole.admin ? '(관리자)' : ''}',
                            style: TextStyle(
                              fontWeight:
                                  user.role == UserRole.admin
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(_formatPhoneNumber(user.phoneNumber)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        AdminUserDetailScreen(user: user),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
