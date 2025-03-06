import 'package:flutter/material.dart';
import '../../../data/services/reading_service.dart';
import '../../../features/services/reading_plan_service.dart';
import '../../../features/services/models/reading_plan.dart';

class WeeklyProgressCard extends StatefulWidget {
  const WeeklyProgressCard({super.key});

  @override
  State<WeeklyProgressCard> createState() => WeeklyProgressCardState();
}

class WeeklyProgressCardState extends State<WeeklyProgressCard> {
  bool _isLoading = true;
  int _completedDays = 0;
  int _totalDaysThisWeek = 0;
  int _currentWeek = 0;
  double _progressPercentage = 0.0;
  final _readingService = ReadingService();
  final _daysOfWeek = ['월', '화', '수', '목', '금', '토'];

  @override
  void initState() {
    super.initState();
    loadWeeklyProgress();
  }

  Future<void> loadWeeklyProgress() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 오늘의 계획을 가져와서 현재 주차를 파악
      final todayPlan = await ReadingPlanService().getTodaysPlan();
      if (todayPlan == null) {
        // 오늘이 일요일이거나 계획이 없는 경우
        setState(() {
          _isLoading = false;
          _progressPercentage = 0.0;
          _completedDays = 0;
          _totalDaysThisWeek = 0;
        });
        return;
      }

      _currentWeek = todayPlan.week;

      // 현재 요일 (1-월, 2-화, ... 6-토, 7-일)
      final currentDayOfWeek = DateTime.now().weekday;

      // 이번 주의 현재 요일까지의 총 날짜 수 (일요일 제외)
      _totalDaysThisWeek = currentDayOfWeek == 7 ? 6 : currentDayOfWeek;

      // 이번 주 각 요일별 완료 여부 확인
      int completedCount = 0;
      for (int day = 1; day <= _totalDaysThisWeek; day++) {
        final isCompleted = await _readingService.isCompleted(
          ReadingPlanService.startYear,
          todayPlan.week,
          day,
        );
        if (isCompleted) {
          completedCount++;
        }
      }

      // 진행률 계산 (현재 요일까지만)
      double progress = 0.0;
      if (_totalDaysThisWeek > 0) {
        progress = completedCount / _totalDaysThisWeek;
      }

      if (mounted) {
        setState(() {
          _completedDays = completedCount;
          _progressPercentage = progress;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _progressPercentage = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = (_progressPercentage * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const Text(
        //   '이번 주 진행 현황',
        //   style: TextStyle(
        //     fontSize: 18,
        //     fontWeight: FontWeight.w500,
        //     color: Color(0xFF111827),
        //   ),
        // ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child:
              _isLoading
                  ? const Center(
                    child: SizedBox(
                      height: 100,
                      child: CircularProgressIndicator(),
                    ),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 주차 및 진행률 정보
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_currentWeek주차',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          Text(
                            '$progressPercent% 완료',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color:
                                  progressPercent == 100
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 진행 게이지
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              flex: (_progressPercentage * 100).round(),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF4F46E5),
                                      progressPercent == 100
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF818CF8),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            Flexible(
                              flex: 100 - (_progressPercentage * 100).round(),
                              child: Container(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 요일별 완료 상태 표시
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(6, (index) {
                          // 요일 값 (1부터 시작)
                          final day = index + 1;

                          // 이번 주의 현재 요일까지만 활성화
                          final isActive = day <= _totalDaysThisWeek;

                          // 완료 여부 (완료한 날 수가 현재 날짜 이상이면 완료로 간주)
                          final isCompleted = _completedDays >= day;

                          return _buildDayCircle(
                            _daysOfWeek[index],
                            isActive: isActive,
                            isCompleted: isCompleted,
                          );
                        }),
                      ),

                      // 하단 상태 설명
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '현재 ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '$_completedDays일',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          Text(
                            ' / $_totalDaysThisWeek일 완료',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildDayCircle(
    String dayText, {
    required bool isActive,
    required bool isCompleted,
  }) {
    final Color bgColor;
    final Color textColor;

    if (!isActive) {
      // 아직 요일이 오지 않음 (미래)
      bgColor = const Color(0xFFF3F4F6);
      textColor = const Color(0xFF9CA3AF);
    } else if (isCompleted) {
      // 완료됨
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF059669);
    } else {
      // 완료되지 않음 (빨간색에서 노란색으로 변경)
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFF59E0B);
    }

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Center(
            child: Text(
              dayText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
