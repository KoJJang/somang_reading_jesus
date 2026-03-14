import 'package:reading_jesus_somang/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import '../../../data/services/reading_service.dart';
import '../../../data/models/reading_completion.dart';
import '../../../features/services/reading_plan_service.dart';
import '../../../core/utils/date_helper.dart';

class CompletionCard extends StatefulWidget {
  final VoidCallback? onCompletionChanged;

  const CompletionCard({super.key, this.onCompletionChanged});

  @override
  State<CompletionCard> createState() => _CompletionCardState();
}

class _CompletionCardState extends State<CompletionCard> {
  bool _isCompletedToday = false;
  bool _isLoading = true;
  bool _isRestDay = false;
  final _readingService = ReadingService();

  @override
  void initState() {
    super.initState();
    _checkTodayCompletion();
  }

  Future<void> _checkTodayCompletion() async {
    setState(() {
      _isLoading = true;
    });

    final today = DateTime.now();

    final isRestDay =
        today.weekday == DateTime.sunday ||
        DateHelper.isBreakWeek(today) ||
        DateHelper.isBeforeScheduleStart(today) ||
        DateHelper.isAfterScheduleEnd(today);

    // 쉬는 날(일요일/휴식주/일정 범위 외)이면 완료 체크 불필요
    if (isRestDay) {
      if (mounted) {
        setState(() {
          _isCompletedToday = false;
          _isRestDay = true;
          _isLoading = false;
        });
      }
      return;
    }

    final plan = await ReadingPlanService().getTodaysPlan();
    if (plan == null) {
      if (mounted) {
        setState(() {
          _isCompletedToday = false;
          _isRestDay = true;
          _isLoading = false;
        });
      }
      return;
    }
    final scheduleYear = ReadingPlanService.scheduleYearForDate(today);
    final isCompleted = await _readingService.isCompleted(
      scheduleYear,
      plan.week,
      plan.day,
    );

    if (mounted) {
      setState(() {
        _isCompletedToday = isCompleted;
        _isRestDay = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsCompleted() async {
    final today = DateTime.now();

    // 쉬는 날이면 완료 처리 불가
    if (_isRestDay ||
        today.weekday == DateTime.sunday ||
        DateHelper.isBreakWeek(today) ||
        DateHelper.isBeforeScheduleStart(today) ||
        DateHelper.isAfterScheduleEnd(today)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오늘은 쉬는 날입니다'),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
      return;
    }

    final plan = await ReadingPlanService().getTodaysPlan();
    if (plan != null) {
      final scheduleYear = ReadingPlanService.scheduleYearForDate(today);
      final completion = ReadingCompletion(
        date: today,
        year: scheduleYear,
        week: plan.week,
        day: plan.day,
        readings: plan.readings,
      );

      setState(() {
        _isLoading = true;
      });

      await _readingService.markAsCompleted(completion);

      if (mounted) {
        setState(() {
          _isCompletedToday = true;
          _isLoading = false;
        });

        // 부모 위젯에 완료 상태 변경 알림
        widget.onCompletionChanged?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오늘의 말씀을 완료했습니다!'),
            duration: Duration(milliseconds: 1500),
            backgroundColor: AppColors.completed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_isRestDay) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('오늘은 쉬는 날입니다'),
              duration: Duration(milliseconds: 800),
            ),
          );
          return;
        }
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.completedSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color:
                    _isCompletedToday
                        ? AppColors.completed
                        : AppColors.completed,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '완료',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color:
                    _isCompletedToday ? AppColors.completed : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isCompletedToday
                  ? '오늘 읽기 완료!'
                  : (_isRestDay ? '오늘은 쉬는 날입니다' : '오늘 읽으셨나요?'),
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // 외부에서 완료 상태를 새로고침할 수 있는 메서드
  void refreshCompletion() {
    _checkTodayCompletion();
  }
}
