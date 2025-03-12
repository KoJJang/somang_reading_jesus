import 'package:flutter/material.dart';

class DailyPlan extends StatelessWidget {
  const DailyPlan({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.church_outlined,
              color: Color(0xFF4F46E5),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '리딩 지저스',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '그리스도 중심으로 성경 읽기',
                  style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                ),
                const Text(
                  '함께 말씀 통독을 시작해보세요!',
                  style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
