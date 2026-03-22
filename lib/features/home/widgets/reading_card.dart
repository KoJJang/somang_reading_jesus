import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../features/services/rjesus_service.dart';
import '../../../features/services/models/rjesus_content.dart';
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
          final todaysReading = await RJesusService.instance.getTodaysReading();
          if (todaysReading != null) {
            _launchYouTube(todaysReading.url);
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
                  Row(
                    children: [
                      Text(
                        '오늘의 말씀',
                        style: TextStyle(
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.share,
                          size: AppSizes.iconS,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () async {
                          final reading = await RJesusService.instance.getTodaysReading();
                          if (reading != null) Share.share(reading.url);
                        },
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: AppSizes.iconS,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<DailyReading?>(
                future: RJesusService.instance.getTodaysReading(),
                builder: (context, snapshot) {
                  // 에러 발생 시
                  if (snapshot.hasError) {
                    LoggerUtil.error(
                      'Failed to load RJesus reading',
                      snapshot.error,
                    );
                    return Text(
                      '오늘의 강의를 불러오는데 실패했습니다',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        color: AppColors.errorDark,
                      ),
                    );
                  }

                  // 로딩 중
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 오늘의 강의가 없는 경우
                  if (!snapshot.hasData || snapshot.data == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '오늘은 쉬는 날입니다',
                          style: TextStyle(
                            fontSize: AppSizes.fontXXL,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '편안한 휴식을 취하세요 ⛪️',
                          style: TextStyle(
                            fontSize: AppSizes.fontM,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }

                  final reading = snapshot.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목 표시
                      Text(
                        reading.title,
                        style: TextStyle(
                          fontSize: AppSizes.fontXXL,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 유튜브 링크 정보
                      Text(
                        '탭하여 유튜브에서 말씀 듣기',
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
