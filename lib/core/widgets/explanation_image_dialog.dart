import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class ExplanationImageDialog extends StatelessWidget {
  final String title;
  final Future<String?> imagePathFuture;
  final Future<String?> imageUrlFuture;

  const ExplanationImageDialog({
    super.key,
    required this.title,
    required this.imagePathFuture,
    required this.imageUrlFuture,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            color: Colors.white,
          ),
          child: SizedBox(
            width: size.width * 0.95,
            height: size.height * 0.9,
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.share),
                          onPressed: () => _shareImage(),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: FutureBuilder<String?>(
                      future: imagePathFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final localPath = snapshot.data;
                        if (localPath == null || localPath.isEmpty) {
                          return _EmptyExplanation();
                        }

                        return InteractiveViewer(
                          child: Image.asset(
                            localPath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return FutureBuilder<String?>(
                                future: imageUrlFuture,
                                builder: (context, urlSnapshot) {
                                  final url = urlSnapshot.data;
                                  if (urlSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (url == null || url.isEmpty) {
                                    return _EmptyExplanation();
                                  }
                                  return Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _EmptyExplanation();
                                    },
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
      ),
    );
  }

  Future<void> _shareImage() async {
    if (!kIsWeb) {
      final path = await imagePathFuture;
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
    final url = await imageUrlFuture;
    if (url != null) Share.share(url);
  }
}

class _EmptyExplanation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            '해설 이미지가 준비되지 않았습니다',
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
}
