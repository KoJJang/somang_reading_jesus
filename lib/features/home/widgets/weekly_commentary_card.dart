import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../features/services/rjesus_service.dart';
import '../../../features/services/models/rjesus_content.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/logger_util.dart';

class WeeklyCommentaryCard extends StatelessWidget {
  const WeeklyCommentaryCard({super.key});

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
          final commentary =
              await RJesusService.instance.getThisWeeksCommentary();
          if (commentary != null) {
            _launchYouTube(commentary.url);
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
                  Flexible(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.library_books,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '주간 해설',
                            style: TextStyle(
                              fontSize: AppSizes.fontL,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: AppSizes.iconS,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<WeeklyCommentary?>(
                future: RJesusService.instance.getThisWeeksCommentary(),
                builder: (context, snapshot) {
                  // 에러 발생 시
                  if (snapshot.hasError) {
                    LoggerUtil.error(
                      'Failed to load weekly commentary',
                      snapshot.error,
                    );
                    return Text(
                      '주간 해설을 불러오는데 실패했습니다',
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

                  // 주간 해설이 없는 경우
                  if (!snapshot.hasData || snapshot.data == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '해설이 준비 중입니다',
                          style: TextStyle(
                            fontSize: AppSizes.fontXL,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '곧 업데이트 예정입니다',
                          style: TextStyle(
                            fontSize: AppSizes.fontM,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }

                  final commentary = snapshot.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목 표시
                      Text(
                        commentary.title,
                        style: TextStyle(
                          fontSize: AppSizes.fontXL,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 유튜브 링크 정보
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSizes.paddingS,
                              vertical: AppSizes.paddingXS,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusM,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.blue,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '주간 해설',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontS,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${commentary.volume}권 ${commentary.chapter}강',
                              style: TextStyle(
                                fontSize: AppSizes.fontM,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '깊이 있는 성경 해설을 들어보세요',
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          color: AppColors.textSecondary,
                        ),
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

  Future<void> _launchYouTube(String url) async {
    try {
      final Uri uri = Uri.parse(url);

      // 플랫폼 기본값으로 시도 (가장 호환성 좋음)
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (e) {
      // 실패하면 인앱 브라우저로 시도
      try {
        final Uri uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (fallbackError) {
        LoggerUtil.error('Failed to launch URL', {
          'url': url,
          'originalError': e.toString(),
          'fallbackError': fallbackError.toString(),
        });
      }
    }
  }
}
