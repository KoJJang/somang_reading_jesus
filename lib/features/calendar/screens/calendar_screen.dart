import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../features/services/reading_plan_service.dart';
import '../../../features/services/models/reading_plan.dart';
import '../../../data/services/reading_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/logger_util.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  ReadingPlan? _selectedDayPlan;
  Map<DateTime, bool> _completionStatus = {};
  Map<String, int> _monthStatus = {'completed': 0, 'total': 0, 'remaining': 0};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadReadingPlan(_selectedDay!);
    initializeDateFormatting('ko_KR');
    _loadMonthCompletions(_focusedDay);
  }

  Future<void> _loadReadingPlan(DateTime date) async {
    try {
      final plan = await ReadingPlanService().getPlanForDate(date);
      setState(() {
        _selectedDayPlan = plan;
      });
    } catch (e, stackTrace) {
      LoggerUtil.error('Failed to load reading plan', e, stackTrace);
      if (mounted) {
        LoggerUtil.showErrorSnackBar(context, '읽기 계획을 불러오는데 실패했습니다.');
      }
    }
  }

  // 월간 통독 현황 계산
  void _calculateMonthStatus(DateTime month) {
    int completed = 0;
    int total = 0;
    int remaining = 0;

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    for (
      var date = startDate;
      date.isBefore(endDate.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      // 일요일이거나 읽기 계획이 없는 날은 제외
      if (date.weekday == DateTime.sunday) continue;

      final dateKey = DateTime(date.year, date.month, date.day);
      final isFutureDate = date.isAfter(DateTime.now());

      if (isFutureDate) {
        remaining++;
      } else {
        total++;
        if (_completionStatus[dateKey] == true) {
          completed++;
        }
      }
    }

    setState(() {
      _monthStatus = {
        'completed': completed,
        'total': total,
        'remaining': remaining,
      };
    });
  }

  Future<void> _loadMonthCompletions(DateTime month) async {
    try {
      final service = ReadingService();
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      _completionStatus.clear();
      for (
        var date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))
      ) {
        final plan = await ReadingPlanService().getPlanForDate(date);
        if (plan != null) {
          final isCompleted = await service.isCompleted(
            ReadingPlanService.startYear,
            plan.week,
            plan.day,
          );
          if (isCompleted) {
            final dateKey = DateTime(date.year, date.month, date.day);
            _completionStatus[dateKey] = true;
          }
        }
      }
      _calculateMonthStatus(month);
    } catch (e, stackTrace) {
      LoggerUtil.error('Failed to load month completions', e, stackTrace);
      if (mounted) {
        LoggerUtil.showErrorSnackBar(context, '완료 상태를 불러오는데 실패했습니다.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _monthStatus['total'] ?? 0;
    final completed = _monthStatus['completed'] ?? 0;
    final completionRate = total > 0 ? (completed / total * 100).round() : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '통독 일정',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppSizes.fontXXL,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
              ),
              child: Column(
                children: [
                  // 달력
                  TableCalendar(
                    firstDay: DateTime(2025, 1, 20),
                    lastDay: DateTime(2025, 12, 31),
                    focusedDay: _focusedDay,
                    locale: 'ko_KR',
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: CalendarFormat.month,
                    availableGestures: AvailableGestures.none,
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: TextStyle(
                        fontSize: AppSizes.fontXL,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, date, _) {
                        return _buildCalendarCell(date);
                      },
                      todayBuilder: (context, date, _) {
                        return _buildCalendarCell(date, isToday: true);
                      },
                      selectedBuilder: (context, date, _) {
                        return _buildCalendarCell(date);
                      },
                      dowBuilder: (context, day) {
                        final text = DateFormat.E('ko_KR').format(day);
                        return Center(
                          child: Text(
                            text,
                            style: TextStyle(
                              color:
                                  day.weekday == DateTime.sunday
                                      ? Colors.red
                                      : day.weekday == DateTime.saturday
                                      ? Colors.blue
                                      : const Color(0xFF111827),
                            ),
                          ),
                        );
                      },
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      weekendTextStyle: const TextStyle().copyWith(
                        color: Colors.red,
                      ),
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _loadReadingPlan(selectedDay);
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                      _loadMonthCompletions(focusedDay);
                    },
                  ),
                  // 색상 태그 설명
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingS,
                      vertical: AppSizes.paddingS,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _ColorTag(color: Colors.green[50]!, label: '읽음'),
                        const SizedBox(width: 16),
                        _ColorTag(color: Colors.amber[50]!, label: '읽지 않음'),
                        const SizedBox(width: 16),
                        _ColorTag(color: Colors.grey[100]!, label: '예정'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedDayPlan != null)
              _DailyReadingPlan(plan: _selectedDayPlan!),
            // 월간 통독 현황
            _MonthlyReadingStatus(
              completionRate: completionRate,
              completed: _monthStatus['completed'] ?? 0,
              remaining: _monthStatus['remaining'] ?? 0,
            ),
            const SizedBox(height: AppSizes.paddingM), // 하단 여백 추가
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCell(DateTime date, {bool isToday = false}) {
    if (date.weekday == DateTime.sunday) {
      return Center(
        child: Text('${date.day}', style: TextStyle(color: Colors.grey[400])),
      );
    }

    final dateKey = DateTime(date.year, date.month, date.day);
    final isCompleted = _completionStatus[dateKey] ?? false;
    final isSelected = isSameDay(date, _selectedDay);
    // 내일 자정을 기준으로 미래 날짜 체크
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final isFutureDate = date.compareTo(tomorrow) >= 0;

    return Center(
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isFutureDate
                  ? Colors.grey[100]
                  : isCompleted
                  ? Colors.green[50]
                  : Colors.amber[50],
          border:
              isSelected
                  ? Border.all(color: const Color(0xFF4F46E5), width: 1.5)
                  : null,
        ),
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(
              color:
                  isSelected
                      ? const Color(0xFF4F46E5)
                      : isCompleted
                      ? const Color(0xFF059669)
                      : const Color(0xFF111827),
              fontWeight: isCompleted || isSelected ? FontWeight.bold : null,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyReadingPlan extends StatelessWidget {
  final ReadingPlan plan;

  const _DailyReadingPlan({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${plan.week}주 ${plan.day}일차',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 2),
          ...plan.readings.map((reading) {
            final endText =
                reading['start'] == reading['end']
                    ? '${reading['start']}장'
                    : '${reading['start']}-${reading['end']}장';
            return Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(
                '${reading['book']} $endText',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 66, 58, 209),
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (plan.readings.isNotEmpty) {
                  final firstReading = plan.readings[0];
                  final readingsWithMeta =
                      plan.readings.map((r) {
                        final reading = Map<String, dynamic>.from(r);
                        reading['week'] = plan.week;
                        reading['day'] = plan.day;
                        return reading;
                      }).toList();

                  Navigator.pushNamed(
                    context,
                    '/bible',
                    arguments: {
                      'book': firstReading['book'],
                      'chapter': firstReading['start'] as int,
                      'endChapter': firstReading['end'] as int,
                      'readings': readingsWithMeta,
                    },
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                '지금 읽기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyReadingStatus extends StatelessWidget {
  final int completionRate;
  final int completed;
  final int remaining;

  const _MonthlyReadingStatus({
    required this.completionRate,
    required this.completed,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 달 진행률',
            style: TextStyle(
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$completionRate%',
                      style: TextStyle(
                        fontSize: AppSizes.fontXXL,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '완료율',
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$completed일',
                      style: TextStyle(
                        fontSize: AppSizes.fontXXL,
                        fontWeight: FontWeight.w700,
                        color: AppColors.completed,
                      ),
                    ),
                    Text(
                      '읽은 날',
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$remaining일',
                      style: TextStyle(
                        fontSize: AppSizes.fontXXL,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '남은 날',
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorTag extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorTag({Key? key, required this.color, required this.label})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }
}
