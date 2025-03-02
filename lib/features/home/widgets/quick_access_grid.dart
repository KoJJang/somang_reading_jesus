import 'package:flutter/material.dart';
import '../../../data/services/reading_service.dart';
import '../../../data/models/reading_completion.dart';
import '../../../features/services/reading_plan_service.dart';

class QuickAccessGrid extends StatefulWidget {
  const QuickAccessGrid({super.key});

  @override
  State<QuickAccessGrid> createState() => _QuickAccessGridState();
}

class _QuickAccessGridState extends State<QuickAccessGrid> {
  bool _isCompletedToday = false;
  bool _isLoading = true;
  final _readingService = ReadingService();

  @override
  void initState() {
    super.initState();
    _checkTodayCompletion();
  }

  Future<void> _checkTodayCompletion() async {
    final plan = await ReadingPlanService().getTodaysPlan();
    final isCompleted = await _readingService.isCompleted(
      ReadingPlanService.startYear,
      plan?.week ?? 0,
      plan?.day ?? 0,
    );
    if (mounted) {
      setState(() {
        _isCompletedToday = isCompleted;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildGridItem(
            icon: Icons.calendar_today_outlined,
            iconColor: const Color(0xFFD97706),
            iconBackground: const Color(0xFFFEF3C7),
            title: '통독 일정',
            subtitle: '날짜별 읽기 분량',
            onTap: () => Navigator.pushNamed(context, '/calendar'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildGridItem(
                    icon: Icons.assignment_turned_in_outlined,
                    iconColor:
                        _isCompletedToday
                            ? const Color(0xFF059669)
                            : const Color(0xFF6B7280),
                    iconBackground: const Color(0xFFD1FAE5),
                    title: '완료',
                    titleColor:
                        _isCompletedToday
                            ? const Color(0xFF059669)
                            : const Color(0xFF111827),
                    subtitle: _isCompletedToday ? '오늘 읽기 완료!' : '오늘 읽으셨나요?',
                    onTap: () {
                      if (_isCompletedToday) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('이미 오늘의 말씀을 완료하셨습니다'),
                            duration: Duration(milliseconds: 500),
                          ),
                        );
                        return;
                      }
                      _markAsCompleted();
                    },
                  ),
        ),
      ],
    );
  }

  Future<void> _markAsCompleted() async {
    final plan = await ReadingPlanService().getTodaysPlan();
    if (plan != null) {
      final completion = ReadingCompletion(
        date: DateTime.now(),
        year: DateTime.now().year,
        week: plan.week,
        day: plan.day,
        readings: plan.readings,
      );
      await _readingService.markAsCompleted(completion);
      if (context.mounted) {
        setState(() {
          _isCompletedToday = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오늘의 말씀을 완료했습니다!'),
            duration: Duration(milliseconds: 500),
          ),
        );
      }
    }
  }

  Widget _buildGridItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Color? subtitleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: titleColor ?? const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: subtitleColor ?? const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
