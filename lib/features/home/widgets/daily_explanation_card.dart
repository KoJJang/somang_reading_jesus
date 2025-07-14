import 'package:flutter/material.dart';
import '../../../features/services/rjesus_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class DailyExplanationCard extends StatelessWidget {
  const DailyExplanationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: RJesusService.instance.getTodaysReading(),
      builder: (context, snapshot) {
        final hasReading = snapshot.hasData && snapshot.data != null;

        return GestureDetector(
          onTap:
              hasReading
                  ? () {
                    _showImageDialog(context);
                  }
                  : null,
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image, color: Colors.green, size: 20),
                ),
                const SizedBox(height: 12),
                const Text(
                  '일별 해설',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  hasReading ? '탭하여 크게 보기' : '오늘은 쉬는 날입니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: hasReading ? Colors.black54 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('오늘의 해설'),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.paddingM),
                      child: FutureBuilder<String?>(
                        future:
                            RJesusService.instance
                                .getTodaysExplanationImagePath(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data == null) {
                            return Container(
                              color: AppColors.textSecondary.withOpacity(0.1),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '오늘의 해설 이미지가 준비되지 않았습니다',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: AppSizes.fontL,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return InteractiveViewer(
                            child: Image.asset(
                              snapshot.data!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // 로컬 이미지 실패 시 네트워크 이미지로 폴백
                                return FutureBuilder<String?>(
                                  future:
                                      RJesusService.instance
                                          .getTodaysExplanationImageUrl(),
                                  builder: (context, urlSnapshot) {
                                    if (urlSnapshot.hasData &&
                                        urlSnapshot.data != null) {
                                      return Image.network(
                                        urlSnapshot.data!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Container(
                                            color: AppColors.textSecondary
                                                .withOpacity(0.1),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.image_not_supported,
                                                  size: 64,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  '오늘의 해설 이미지가 준비되지 않았습니다',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: AppSizes.fontL,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    }
                                    return Container(
                                      color: AppColors.textSecondary
                                          .withOpacity(0.1),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image_not_supported,
                                            size: 64,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            '오늘의 해설 이미지가 준비되지 않았습니다',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: AppSizes.fontL,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
