import 'dart:convert';
import 'package:flutter/material.dart';
import '../../auth/models/user_profile.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final UserProfile user;

  const AdminUserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Pretty print JSON
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    final String prettyJson = encoder.convert(user.toMap());

    return Scaffold(
      appBar: AppBar(title: Text(user.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Profile Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              prettyJson,
              style: const TextStyle(fontFamily: 'Courier', fontSize: 14),
            ),
            // 추후 통독 진행률 등 추가 정보를 여기에 표시할 수 있음
          ],
        ),
      ),
    );
  }
}
