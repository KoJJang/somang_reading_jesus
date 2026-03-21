import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../features/services/rjesus_service.dart';
import '../../../core/widgets/explanation_image_dialog.dart';

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '일별 해설',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (hasReading)
                      GestureDetector(
                        onTap: () => _shareImage(),
                        child: const Icon(Icons.share, size: 18, color: Colors.black38),
                      ),
                  ],
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

  Future<void> _shareImage() async {
    if (!kIsWeb) {
      final path = await RJesusService.instance.getTodaysExplanationImagePath();
      if (path != null) {
        try {
          final bytes = await rootBundle.load(path);
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/explanation.jpg')
            ..writeAsBytesSync(bytes.buffer.asUint8List());
          await Share.shareXFiles([XFile(file.path)]);
          return;
        } catch (_) {}
      }
    }
    final url = await RJesusService.instance.getTodaysExplanationImageUrl();
    if (url != null) Share.share(url);
  }

  void _showImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ExplanationImageDialog(
          title: '오늘의 해설',
          imagePathFuture:
              RJesusService.instance.getTodaysExplanationImagePath(),
          imageUrlFuture: RJesusService.instance.getTodaysExplanationImageUrl(),
        );
      },
    );
  }
}
