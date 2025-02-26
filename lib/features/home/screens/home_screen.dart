import 'package:flutter/material.dart';
import '../widgets/reading_card.dart';
import '../widgets/daily_plan.dart';
import '../widgets/history_section.dart';
import '../../../data/services/completion_service.dart';
import '../../../data/models/reading_completion.dart';
import '../../../features/services/reading_plan_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCompletedToday = false;
  bool _isLoading = true;
  final _completionService = CompletionService();

  @override
  void initState() {
    super.initState();
    _checkTodayCompletion();
  }

  Future<void> _checkTodayCompletion() async {
    final plan = await ReadingPlanService().getTodaysPlan();
    final isCompleted = await _completionService.isCompleted(
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
      await _completionService.markAsCompleted(completion);
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 오늘의 말씀 카드 (이전 디자인)
            const ReadingCard(),
            const SizedBox(height: 4),
            // 통독 일정과 완료 그리드
            Row(
              children: [
                // 통독 일정
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/calendar');
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
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: Color(0xFFFCD34D),
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '통독 일정',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '날짜별 읽기 분량',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // 완료
                Expanded(
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : GestureDetector(
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
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.check_circle_outline,
                                      color:
                                          _isCompletedToday
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF22C55E),
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
                                          _isCompletedToday
                                              ? const Color(0xFF059669)
                                              : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isCompletedToday
                                        ? '오늘 읽기 완료!'
                                        : '오늘 읽으셨나요?',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 오늘의 말씀 (이전 디자인)
            const DailyPlan(),
            const SizedBox(height: 24),
            const HistorySection(),
          ],
        ),
      ),
    );
  }
}
