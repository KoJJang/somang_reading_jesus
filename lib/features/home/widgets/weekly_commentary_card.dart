import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../features/services/rjesus_service.dart';
import '../../../features/services/models/rjesus_content.dart';
import '../../../core/utils/logger_util.dart';
import '../../../core/widgets/youtube_player_screen.dart';

class WeeklyCommentaryCard extends StatelessWidget {
  const WeeklyCommentaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final commentary =
            await RJesusService.instance.getThisWeeksCommentary();
        if (commentary == null) return;
        final videoId = commentary.youtubeId;
        if (videoId != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => YoutubePlayerScreen(
                videoId: videoId,
                title: commentary.title,
              ),
            ),
          );
        } else {
          try {
            final Uri uri = Uri.parse(commentary.url);
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          } catch (e) {
            try {
              final Uri uri = Uri.parse(commentary.url);
              await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
            } catch (fallbackError) {
              LoggerUtil.error('Failed to launch URL', {
                'url': commentary.url,
                'originalError': e.toString(),
                'fallbackError': fallbackError.toString(),
              });
            }
          }
        }
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
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.library_books,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '주간 해설',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () async {
                    final commentary = await RJesusService.instance.getThisWeeksCommentary();
                    if (commentary != null) Share.share(commentary.url);
                  },
                  child: const Icon(Icons.share, size: 18, color: Colors.black38),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FutureBuilder<WeeklyCommentary?>(
              future: RJesusService.instance.getThisWeeksCommentary(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final commentary = snapshot.data!;
                  return Text(
                    '${commentary.volume}권 ${commentary.chapter}강',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  );
                }
                return const Text(
                  '오늘은 쉬는 날입니다',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
