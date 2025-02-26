import 'package:flutter/material.dart';

class HistorySection extends StatelessWidget {
  const HistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final historyItems = [
      {'title': '요한복음 3장', 'time': '오늘'},
      {'title': '시편 23편', 'time': '어제'},
      {'title': '잠언 1장', 'time': '2일 전'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '최근 기록',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: historyItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = historyItems[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.history,
                        size: 20,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item['title']!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item['time']!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
} 