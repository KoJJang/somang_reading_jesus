import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../controllers/user_service.dart';
import '../../../core/constants/theme.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _userService = UserService();
  bool _isLoading = false;
  String? _errorMessage;

  // 날짜 형식 포맷터
  final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  // 날짜 문자열을 DateTime으로 파싱
  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    try {
      // 하이픈(-) 없이 8자리 숫자인 경우 (YYYYMMDD)
      if (value.length == 8 && int.tryParse(value) != null) {
        final year = int.parse(value.substring(0, 4));
        final month = int.parse(value.substring(4, 6));
        final day = int.parse(value.substring(6, 8));
        return DateTime(year, month, day);
      }

      // 하이픈 포함된 형식 (YYYY-MM-DD)
      return _dateFormat.parse(value);
    } catch (e) {
      return null;
    }
  }

  // 날짜 문자열 자동 포맷팅
  String _formatDateInput(String value) {
    // 숫자가 아닌 문자 제거
    final numericValue = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (numericValue.isEmpty) return '';

    // 년도 (YYYY)
    if (numericValue.length <= 4) {
      return numericValue;
    }

    // 년도-월 (YYYY-MM)
    if (numericValue.length <= 6) {
      return '${numericValue.substring(0, 4)}-${numericValue.substring(4)}';
    }

    // 년도-월-일 (YYYY-MM-DD)
    return '${numericValue.substring(0, 4)}-${numericValue.substring(4, 6)}-${numericValue.substring(6, min(8, numericValue.length))}';
  }

  // 유효한 날짜인지 확인
  bool _isValidDate(String value) {
    // 비어있으면 유효하다고 간주 (선택 사항이므로)
    if (value.trim().isEmpty) {
      return true;
    }

    final date = _parseDate(value);
    if (date == null) return false;

    // 현재보다 미래 날짜인지 확인
    final now = DateTime.now();
    if (date.isAfter(now)) return false;

    // 너무 과거 날짜인지 확인 (예: 150년 이상)
    final minDate = DateTime(now.year - 150);
    if (date.isBefore(minDate)) return false;

    // 월과 일이 올바른 범위인지 확인
    final year = date.year;
    final month = date.month;
    final day = date.day;

    if (month < 1 || month > 12) return false;

    // 각 월의 마지막 날 확인
    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > daysInMonth) return false;

    return true;
  }

  // 프로필 저장
  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    DateTime? birthDate;
    final dateStr = _birthDateController.text.trim();

    // 생년월일이 입력된 경우에만 파싱
    if (dateStr.isNotEmpty) {
      birthDate = _parseDate(dateStr);
      if (birthDate == null && dateStr.isNotEmpty) {
        setState(() {
          _errorMessage = '올바른 날짜 형식이 아닙니다. YYYY-MM-DD 형식으로 입력해주세요.';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _userService.saveUserProfile(
        name: _nameController.text.trim(),
        birthDate: birthDate,
      );

      if (mounted) {
        // 성공시 홈 화면으로 이동
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '프로필 저장 중 오류가 발생했습니다: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기에 따른 패딩 조정
    final screenSize = MediaQuery.of(context).size;
    final horizontalPadding = screenSize.width > 600 ? 100.0 : 20.0;

    return Scaffold(
      appBar: AppBar(title: const Text('프로필 설정'), elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 20.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '거의 다 왔습니다!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '더 나은 서비스를 위해 아래 정보를 입력해주세요.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // 이름 입력 필드
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '이름을 입력해주세요';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // 생년월일 입력 필드 (직접 타이핑)
                    TextFormField(
                      controller: _birthDateController,
                      decoration: const InputDecoration(
                        labelText: '생년월일 (선택사항)',
                        hintText: 'YYYY-MM-DD (예: 1990-01-01)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                        helperText: '선택사항: YYYY-MM-DD 형식으로 입력해주세요.',
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                        LengthLimitingTextInputFormatter(
                          10,
                        ), // YYYY-MM-DD는 최대 10자
                      ],
                      onChanged: (value) {
                        // 자동 포맷팅 적용
                        final formatted = _formatDateInput(value);
                        if (formatted != value) {
                          _birthDateController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        }
                      },
                      validator: (value) {
                        // 비어있으면 통과 (선택 사항)
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        if (!_isValidDate(value)) {
                          return '올바른 날짜 형식이 아닙니다. YYYY-MM-DD 형식으로 입력해주세요.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // 저장 버튼
                    SizedBox(
                      height: 50, // 버튼 높이 고정
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  '프로필 저장하기',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
