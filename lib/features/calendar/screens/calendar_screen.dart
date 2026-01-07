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
import '../../../features/services/rjesus_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/reading_completion.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/explanation_image_dialog.dart';

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
  Map<String, int> _monthStatus = {
    'completed': 0,
    'total': 0,
    'remaining': 0,
    'missed': 0,
  };
  bool _isCompletedSelectedDay = false;
  bool _isLoading = false;
  final _readingService = ReadingService();
  late int _viewYear;

  DateTime get _calendarFirstDay => DateTime(_viewYear, 1, 1);
  DateTime get _calendarLastDay => DateTime(_viewYear, 12, 31);

  @override
  void initState() {
    super.initState();
    _viewYear = _focusedDay.year;
    _selectedDay = _focusedDay;
    _loadReadingPlan(_selectedDay!);
    initializeDateFormatting('ko_KR');
    _loadMonthCompletions(_focusedDay);
    _checkSelectedDayCompletion();
  }

  void _setViewYear(int year) {
    final scheduleStart = DateHelper.getScheduleStartDateForYear(year);
    setState(() {
      _viewYear = year;
      _focusedDay = scheduleStart;
      _selectedDay = scheduleStart;
      _selectedDayPlan = null;
      _isCompletedSelectedDay = false;
      _completionStatus = {};
    });

    _loadReadingPlan(_selectedDay!);
    _loadMonthCompletions(_focusedDay);
  }

  Future<void> _loadReadingPlan(DateTime date) async {
    try {
      final plan = await ReadingPlanService().getPlanForDate(date);
      setState(() {
        _selectedDayPlan = plan;
      });

      // 선택된 날짜의 완료 상태 확인
      if (plan != null) {
        final scheduleYear = ReadingPlanService.scheduleYearForDate(date);
        final isCompleted = await _readingService.isCompleted(
          scheduleYear,
          plan.week,
          plan.day,
        );
        setState(() {
          _isCompletedSelectedDay = isCompleted;
        });
      }
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
    int missed = 0;

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    for (
      var date = startDate;
      date.isBefore(endDate.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      // 일요일, 휴식 주, 일정 종료 후, 일정 시작 전은 제외
      if (date.weekday == DateTime.sunday ||
          DateHelper.isBreakWeek(date) ||
          DateHelper.isAfterScheduleEnd(date) ||
          DateHelper.isBeforeScheduleStart(date)) {
        continue;
      }

      final dateKey = DateTime(date.year, date.month, date.day);
      final isCompleted = _completionStatus[dateKey] == true;

      // ✅ 전체 달의 “읽어야 할 날”을 분모(total)로 사용
      total++;
      if (isCompleted) {
        completed++;
      } else {
        final isFutureDate = dateKey.isAfter(todayKey);
        if (isFutureDate) {
          remaining++;
        } else {
          missed++;
        }
      }
    }

    setState(() {
      _monthStatus = {
        'completed': completed,
        'total': total,
        'remaining': remaining,
        'missed': missed,
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
          final scheduleYear = ReadingPlanService.scheduleYearForDate(date);
          final isCompleted = await service.isCompleted(
            scheduleYear,
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

  Future<void> _checkSelectedDayCompletion() async {
    if (_selectedDayPlan != null) {
      final date = _selectedDay ?? DateTime.now();
      final scheduleYear = ReadingPlanService.scheduleYearForDate(date);
      final isCompleted = await _readingService.isCompleted(
        scheduleYear,
        _selectedDayPlan!.week,
        _selectedDayPlan!.day,
      );
      setState(() {
        _isCompletedSelectedDay = isCompleted;
      });
    }
  }

  Future<void> _markSelectedDayCompleted() async {
    if (_selectedDayPlan != null && _selectedDay != null) {
      setState(() {
        _isLoading = true;
      });

      final scheduleYear = ReadingPlanService.scheduleYearForDate(
        _selectedDay!,
      );
      final completion = ReadingCompletion(
        date: _selectedDay!,
        year: scheduleYear,
        week: _selectedDayPlan!.week,
        day: _selectedDayPlan!.day,
        readings: _selectedDayPlan!.readings,
      );

      await _readingService.markAsCompleted(completion);

      // 완료 상태 업데이트
      final dateKey = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
      );
      _completionStatus[dateKey] = true;

      setState(() {
        _isCompletedSelectedDay = true;
        _isLoading = false;
      });

      // 월간 상태도 다시 계산
      _calculateMonthStatus(_focusedDay);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${DateFormat('MM월 dd일').format(_selectedDay!)} 말씀을 완료했습니다!',
            ),
            duration: const Duration(milliseconds: 1500),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    }
  }

  Future<void> _unmarkSelectedDayCompleted() async {
    if (_selectedDayPlan != null && _selectedDay != null) {
      setState(() {
        _isLoading = true;
      });

      final scheduleYear = ReadingPlanService.scheduleYearForDate(
        _selectedDay!,
      );
      await _readingService.unmarkCompleted(
        scheduleYear,
        _selectedDayPlan!.week,
        _selectedDayPlan!.day,
      );

      final dateKey = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
      );
      _completionStatus.remove(dateKey);

      setState(() {
        _isCompletedSelectedDay = false;
        _isLoading = false;
      });

      _calculateMonthStatus(_focusedDay);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${DateFormat('MM월 dd일').format(_selectedDay!)} 완료를 취소했습니다.',
            ),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _monthStatus['total'] ?? 0;
    final completed = _monthStatus['completed'] ?? 0;
    var completionRate = total > 0 ? (completed / total * 100).round() : 0;
    completionRate = completionRate > 100 ? 100 : completionRate;

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
        actions: [
          if (DateHelper.availableScheduleYears.isNotEmpty)
            PopupMenuButton<int>(
              initialValue: _viewYear,
              onSelected: _setViewYear,
              itemBuilder:
                  (context) =>
                      DateHelper.availableScheduleYears
                          .map(
                            (year) => PopupMenuItem<int>(
                              value: year,
                              child: Text('$year'),
                            ),
                          )
                          .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    '$_viewYear',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
                    firstDay: _calendarFirstDay,
                    lastDay: _calendarLastDay,
                    focusedDay: _focusedDay,
                    locale: 'ko_KR',
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: CalendarFormat.month,
                    availableGestures: AvailableGestures.none,
                    enabledDayPredicate: (day) {
                      if (day.weekday == DateTime.sunday) return false;
                      if (DateHelper.isBreakWeek(day)) return false;
                      if (DateHelper.isAfterScheduleEnd(day)) return false;
                      if (DateHelper.isBeforeScheduleStart(day)) return false;
                      return true;
                    },
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
              _SelectedDayActions(
                plan: _selectedDayPlan!,
                selectedDay: _selectedDay!,
                isCompleted: _isCompletedSelectedDay,
                isLoading: _isLoading,
                onMarkCompleted: _markSelectedDayCompleted,
                onUnmarkCompleted: _unmarkSelectedDayCompleted,
              )
            else if (_selectedDay != null &&
                DateHelper.isBreakWeek(_selectedDay!))
              _BreakWeekMessage(selectedDay: _selectedDay!),
            // 월간 통독 현황
            _MonthlyReadingStatus(
              completionRate: completionRate,
              completed: _monthStatus['completed'] ?? 0,
              remaining: _monthStatus['remaining'] ?? 0,
              missed: _monthStatus['missed'] ?? 0,
              total: _monthStatus['total'] ?? 0,
            ),
            const SizedBox(height: AppSizes.paddingM), // 하단 여백 추가
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCell(DateTime date, {bool isToday = false}) {
    // 일요일, 휴식 주, 일정 종료 후, 일정 시작 전은 회색으로 표시 (선택 불가)
    if (date.weekday == DateTime.sunday ||
        DateHelper.isBreakWeek(date) ||
        DateHelper.isAfterScheduleEnd(date) ||
        DateHelper.isBeforeScheduleStart(date)) {
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
              isCompleted
                  ? Colors.green[50]
                  : isFutureDate
                  ? Colors.grey[100]
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

class _SelectedDayActions extends StatelessWidget {
  final ReadingPlan plan;
  final DateTime selectedDay;
  final bool isCompleted;
  final bool isLoading;
  final Function() onMarkCompleted;
  final Function() onUnmarkCompleted;

  const _SelectedDayActions({
    required this.plan,
    required this.selectedDay,
    required this.isCompleted,
    required this.isLoading,
    required this.onMarkCompleted,
    required this.onUnmarkCompleted,
  });

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
          // 날짜와 권/강/일차 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 읽기 범위
              Text(
                plan.readings.length == 1
                    ? '${plan.readings[0]['book']} ${plan.readings[0]['start']}-${plan.readings[0]['end']}장'
                    : '${plan.readings.first['book']} ${plan.readings.first['start']}장- ${plan.readings.last['book']} ${plan.readings.last['end']}장',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              FutureBuilder(
                future: RJesusService.instance.getReadingByDate(selectedDay),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final reading = snapshot.data!;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${reading.volume}권 ${reading.chapter}강 ${reading.day}일차',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // const SizedBox(height: 5),

          // 액션 버튼들 (그리드)
          Row(
            children: [
              // 오늘의 말씀 (유튜브)
              Expanded(
                child: _ActionButton(
                  icon: Icons.play_circle_filled,
                  iconColor: Colors.red,
                  iconBackground: Colors.red.withOpacity(0.1),
                  title: '오늘의 말씀',
                  subtitle: '오디오 바이블',
                  onTap: () async {
                    final reading = await RJesusService.instance
                        .getReadingByDate(selectedDay);
                    if (reading != null) {
                      try {
                        final Uri uri = Uri.parse(reading.url);
                        await launchUrl(uri, mode: LaunchMode.platformDefault);
                      } catch (e) {
                        try {
                          final Uri uri = Uri.parse(reading.url);
                          await launchUrl(
                            uri,
                            mode: LaunchMode.inAppBrowserView,
                          );
                        } catch (fallbackError) {
                          LoggerUtil.error('Failed to launch URL', {
                            'url': reading.url,
                            'originalError': e.toString(),
                            'fallbackError': fallbackError.toString(),
                          });
                        }
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // 일별 해설
              Expanded(
                child: _ActionButton(
                  icon: Icons.image,
                  iconColor: Colors.green,
                  iconBackground: Colors.green.withOpacity(0.1),
                  title: '일별 해설',
                  subtitle: '해설 이미지',
                  onTap: () => _showExplanationDialog(context, selectedDay),
                ),
              ),
              const SizedBox(width: 8),

              // 완료
              Expanded(
                child: _ActionButton(
                  icon:
                      isCompleted
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                  iconColor:
                      isCompleted
                          ? const Color(0xFF059669)
                          : const Color(0xFF6B7280),
                  iconBackground:
                      isCompleted
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                  title: '완료',
                  subtitle: isCompleted ? '취소하기' : '완료하기',
                  isLoading: isLoading,
                  onTap: () {
                    if (isCompleted) {
                      onUnmarkCompleted();
                    } else {
                      onMarkCompleted();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExplanationDialog(BuildContext context, DateTime date) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ExplanationImageDialog(
          title: '${DateFormat('MM월 dd일').format(date)} 해설',
          imagePathFuture: _getExplanationImagePath(date),
          imageUrlFuture: Future.value(
            RJesusService.instance.getDailyExplanationImageUrl(date),
          ),
        );
      },
    );
  }

  Future<String?> _getExplanationImagePath(DateTime date) async {
    final reading = await RJesusService.instance.getReadingByDate(date);
    if (reading != null) {
      final volume = reading.volume;
      final chapter = reading.chapter;
      final day = reading.day;

      final folderName = '${volume}권${chapter}강';
      final fileName = '${volume}권${chapter}강_성경읽기_${day}.jpg';

      return 'assets/images/summary/$folderName/$fileName';
    }
    return null;
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyReadingStatus extends StatelessWidget {
  final int completionRate;
  final int completed;
  final int remaining;
  final int missed;
  final int total;

  const _MonthlyReadingStatus({
    required this.completionRate,
    required this.completed,
    required this.remaining,
    required this.missed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = total > 0 ? completed / total : 0;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  '이번 달 진행률',
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completionRate%',
                style: TextStyle(
                  fontSize: AppSizes.fontXL,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 10,
              backgroundColor: Colors.grey.withOpacity(0.15),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '읽은 날 $completed일 · 남은 날 $remaining일 · 안 읽은 $missed일',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppSizes.fontM,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakWeekMessage extends StatelessWidget {
  final DateTime selectedDay;

  const _BreakWeekMessage({required this.selectedDay});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSizes.paddingM),
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MM월 dd일').format(selectedDay),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '휴식 주간',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '이번 주는 편안한 휴식을 취하세요',
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
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
