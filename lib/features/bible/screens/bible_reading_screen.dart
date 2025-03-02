import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../data/models/bible_verse.dart';
import '../../../data/services/database_service.dart';
import '../../../data/services/reading_service.dart';
import '../../../core/utils/logger_util.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../features/services/reading_plan_service.dart';
import '../../../data/models/reading_completion.dart';

class BibleReadingScreen extends StatefulWidget {
  final String book;
  final int chapter;
  final int endChapter;
  final List<Map<String, dynamic>> readings;

  const BibleReadingScreen({
    super.key,
    required this.book,
    required this.chapter,
    required this.endChapter,
    required this.readings,
  });

  @override
  State<BibleReadingScreen> createState() => _BibleReadingScreenState();
}

class _BibleReadingScreenState extends State<BibleReadingScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final _readingService = ReadingService();
  final _logger = Logger();
  List<BibleVerse> verses = [];
  bool isLoading = true;
  bool _isCompletedToday = false;
  late int currentBook;
  late int currentChapter;
  int? lastChapter;

  @override
  void initState() {
    super.initState();
    _initializeBook();
    _checkCompletionStatus();
  }

  Future<void> _checkCompletionStatus() async {
    try {
      // 현재 읽고 있는 말씀의 week, day 정보를 가져오기 위해 첫 번째 reading 사용
      final reading = widget.readings[0];
      final isCompleted = await _readingService.isCompleted(
        ReadingPlanService.startYear,
        reading['week'] as int,
        reading['day'] as int,
      );

      if (mounted) {
        setState(() {
          _isCompletedToday = isCompleted;
        });
      }
    } catch (e) {
      LoggerUtil.error('Failed to check completion status', e);
    }
  }

  Future<void> _initializeBook() async {
    final bookId = await _databaseService.getBookIdByName(widget.book);
    if (bookId != null) {
      setState(() {
        currentBook = bookId;
        currentChapter = widget.chapter;
      });
      _loadVerses();
      _loadLastChapter();
    }
  }

  Future<void> _loadVerses() async {
    try {
      setState(() => isLoading = true);
      final loadedVerses = await _databaseService.getVersesByChapter(
        currentBook,
        currentChapter,
      );
      setState(() {
        verses = loadedVerses;
        isLoading = false;
      });
    } catch (e) {
      _logger.e('Error loading verses: $e');
      setState(() => isLoading = false);
      if (mounted) {
        LoggerUtil.showErrorSnackBar(context, '말씀을 불러오는 중 오류가 발생했습니다');
      }
    }
  }

  Future<void> _loadLastChapter() async {
    final last = await _databaseService.getLastChapterNumber(currentBook);
    setState(() {
      lastChapter = last;
    });
  }

  // 현재가 마지막 장인지 확인
  bool get _isLastChapter {
    if (currentChapter < widget.endChapter) return false;
    if (widget.readings.length > 1) return false;
    return true;
  }

  // 완료 처리 메서드
  Future<void> _handleCompletion() async {
    try {
      final reading = widget.readings[0];
      final week = reading['week'];
      final day = reading['day'];

      if (week == null || day == null) {
        if (mounted) {
          LoggerUtil.showErrorSnackBar(context, '완료 처리에 필요한 정보가 없습니다');
        }
        return;
      }

      final completion = ReadingCompletion(
        date: DateTime.now(),
        year: DateTime.now().year,
        week: week,
        day: day,
        readings: widget.readings,
      );

      await _readingService.markAsCompleted(completion);
      if (mounted) {
        setState(() {
          _isCompletedToday = true;
        });
        final message = '$week주차 $day일차 말씀을 완료했습니다';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e, stackTrace) {
      LoggerUtil.error('Failed to mark as completed', e, stackTrace);
      if (mounted) {
        LoggerUtil.showErrorSnackBar(context, '완료 처리 중 오류가 발생했습니다');
      }
    }
  }

  // 이전 장 버튼 활성화 여부 확인
  bool get _canGoToPrevious {
    if (currentBook != _getFirstBookId()) return false;
    return currentChapter > widget.chapter;
  }

  // 다음 장 버튼 활성화 여부 확인
  bool get _canGoToNext {
    if (currentChapter < widget.endChapter) return true;
    return widget.readings.length > 1;
  }

  // 첫 번째 책의 ID 가져오기
  int _getFirstBookId() {
    return currentBook;
  }

  Future<void> _handlePreviousChapter() async {
    if (!_canGoToPrevious) return;

    if (currentChapter > widget.chapter) {
      _navigateToChapter(currentBook, currentChapter - 1);
    }
  }

  Future<void> _handleNextChapter() async {
    if (currentChapter < widget.endChapter) {
      _navigateToChapter(currentBook, currentChapter + 1);
    } else if (widget.readings.length > 1) {
      final nextReading = widget.readings[1];
      final nextBookId = await _databaseService.getBookIdByName(
        nextReading['book'],
      );
      if (nextBookId != null) {
        if (!mounted) return;
        final shouldNavigate =
            await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('다음 책으로 이동'),
                    content: Text('${nextReading['book']}(으)로 이어서 읽으시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('이동'),
                      ),
                    ],
                  ),
            ) ??
            false;

        if (shouldNavigate) {
          _navigateToChapter(nextBookId, nextReading['start']);
        }
      }
    }
  }

  void _navigateToChapter(int bookNum, int chapterNum) {
    setState(() {
      currentBook = bookNum;
      currentChapter = chapterNum;
      lastChapter = null;
    });
    _loadVerses();
    _loadLastChapter();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          verses.isNotEmpty
              ? '${verses[0].longLabel} ${currentChapter}장'
              : '성경 읽기',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppSizes.fontXXL,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.bookmark_border,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              // TODO: 북마크 기능 구현
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(AppSizes.paddingL),
        itemCount: verses.length,
        itemBuilder: (context, index) {
          final verse = verses[index];
          return Padding(
            padding: EdgeInsets.only(bottom: AppSizes.paddingS),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${verse.paragraph} ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppSizes.fontM,
                    ),
                  ),
                  TextSpan(
                    text: verse.sentence,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppSizes.fontL,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(AppSizes.paddingM),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavigationButton(
                icon: Icons.arrow_back_ios,
                label: '이전 장',
                onPressed: _canGoToPrevious ? _handlePreviousChapter : null,
              ),
              Container(height: 32, width: 1, color: const Color(0xFFE5E7EB)),
              if (_isLastChapter)
                _NavigationButton(
                  icon: Icons.check_circle_outline,
                  label: _isCompletedToday ? '완료됨' : '완료',
                  onPressed: _isCompletedToday ? null : _handleCompletion,
                  color:
                      _isCompletedToday
                          ? AppColors.completed.withOpacity(0.5)
                          : AppColors.completed,
                )
              else
                _NavigationButton(
                  icon: Icons.arrow_forward_ios,
                  label: '다음 장',
                  onPressed: _canGoToNext ? _handleNextChapter : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const _NavigationButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? AppColors.primary;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: onPressed != null ? buttonColor : AppColors.textTertiary,
        size: AppSizes.iconM,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: onPressed != null ? buttonColor : AppColors.textTertiary,
          fontSize: AppSizes.fontM,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
