import 'package:flutter/material.dart';
import '../../../features/services/reading_plan_service.dart';
import '../../../features/services/models/reading_plan.dart';
import '../../../data/services/database_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/logger_util.dart';

class ReadingCard extends StatelessWidget {
  const ReadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        onTap: () async {
          final plan = await ReadingPlanService().getTodaysPlan();
          if (plan != null && context.mounted) {
            final readings = plan.readings;
            if (readings.isNotEmpty) {
              // 각 reading에 week와 day 정보 추가
              final readingsWithMeta =
                  readings.map((r) {
                    final reading = Map<String, dynamic>.from(r);
                    reading['week'] = plan.week;
                    reading['day'] = plan.day;
                    return reading;
                  }).toList();

              Navigator.pushNamed(
                context,
                '/bible',
                arguments: {
                  'book': readings[0]['book'],
                  'chapter': readings[0]['start'] as int,
                  'endChapter': readings[0]['end'] as int,
                  'readings': readingsWithMeta,
                },
              );
            }
          }
        },
        child: Padding(
          padding: EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '오늘의 말씀',
                    style: TextStyle(
                      fontSize: AppSizes.fontL,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: AppSizes.iconS,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FutureBuilder<ReadingPlan?>(
                future: ReadingPlanService().getTodaysPlan(),
                builder: (context, snapshot) {
                  // 에러 발생 시
                  if (snapshot.hasError) {
                    LoggerUtil.error(
                      'Failed to load reading plan',
                      snapshot.error,
                    );
                    return Text(
                      '읽기 계획을 불러오는데 실패했습니다',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        color: AppColors.errorBackground,
                      ),
                    );
                  }

                  // 로딩 중
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 읽기 계획이 없는 경우 (일요일 등)
                  if (!snapshot.hasData || snapshot.data == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '오늘은 쉬는 날입니다',
                          style: TextStyle(
                            fontSize: AppSizes.fontXXL + 4,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '주일은 교회에서 예배드리는 날입니다',
                          style: TextStyle(
                            fontSize: AppSizes.fontM,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }

                  final plan = snapshot.data!;
                  final readings = plan.readings;

                  // 읽기 범위 텍스트 생성
                  String readingText;
                  Widget? badgeWidget;

                  if (readings.length > 1) {
                    // 첫 번째 책만 메인 텍스트로 표시
                    final firstReading = readings[0];
                    readingText =
                        '${firstReading['book']} ${firstReading['start']}-${firstReading['end']}장';

                    // 두 번째 책은 뱃지로 표시
                    badgeWidget = Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingS,
                        vertical: AppSizes.paddingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                      child: Text(
                        '+ ${readings[1]['book']}',
                        style: TextStyle(
                          fontSize: AppSizes.fontS,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  } else {
                    // 한 구절만 있는 경우
                    final reading = readings[0];
                    readingText =
                        reading['start'] == reading['end']
                            ? '${reading['book']} ${reading['start']}장'
                            : '${reading['book']} ${reading['start']}-${reading['end']}장';
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            readingText,
                            style: TextStyle(
                              fontSize: AppSizes.fontXXL + 4,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          if (badgeWidget != null) badgeWidget,
                        ],
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<String?>(
                        future: DatabaseService()
                            .getBookIdByName(readings[0]['book'])
                            .then((bookId) async {
                              if (bookId != null) {
                                return DatabaseService().getFirstVerse(
                                  bookId,
                                  readings[0]['start'],
                                );
                              }
                              return null;
                            }),
                        builder: (context, verseSnapshot) {
                          if (verseSnapshot.hasData &&
                              verseSnapshot.data != null) {
                            return Text(
                              verseSnapshot.data!,
                              style: TextStyle(
                                fontSize: AppSizes.fontL,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
