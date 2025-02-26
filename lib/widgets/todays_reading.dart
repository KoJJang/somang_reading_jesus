import 'package:flutter/material.dart';
import '../data/services/reading_plan_service.dart';
import '../data/models/reading_plan.dart';

class TodaysReading extends StatelessWidget {
  const TodaysReading({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReadingPlan?>(
      future: ReadingPlanService().getTodaysPlan(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        final plan = snapshot.data;
        if (plan == null) {
          return const Text('시작일을 설정해주세요');
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 읽기 분량',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('${plan.week}주차 ${plan.day}일차'),
                Text('${plan.volume}권 ${plan.chapter}강'),
                const SizedBox(height: 8),
                Text(
                  '${plan.bookName} ${plan.startChapter}-${plan.endChapter}장',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: plan.progress),
                Text('전체 진도율: ${(plan.progress * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ),
        );
      },
    );
  }
}
