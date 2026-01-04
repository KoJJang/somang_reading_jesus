import 'package:flutter/services.dart';
import 'models/rjesus_content.dart';
import '../../core/utils/date_helper.dart';
import 'reading_plan_service.dart';

class RJesusService {
  static RJesusService? _instance;
  static RJesusService get instance => _instance ??= RJesusService._();
  RJesusService._();

  List<DailyReading>? _dailyReadings;
  List<WeeklyCommentary>? _weeklyCommentaries;

  // 일별 읽기 데이터 로드
  Future<List<DailyReading>> getDailyReadings() async {
    if (_dailyReadings != null) return _dailyReadings!;

    try {
      final csvString = await rootBundle.loadString('assets/data/url_list.csv');
      final lines = csvString.split('\n');

      _dailyReadings = [];
      for (int i = 1; i < lines.length; i++) {
        // 헤더 제외
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          try {
            _dailyReadings!.add(DailyReading.fromCsv(line));
          } catch (e) {
            print('Error parsing daily reading line $i: $line - $e');
          }
        }
      }

      return _dailyReadings!;
    } catch (e) {
      print('Error loading daily readings: $e');
      return [];
    }
  }

  // 주간 해설 데이터 로드
  Future<List<WeeklyCommentary>> getWeeklyCommentaries() async {
    if (_weeklyCommentaries != null) return _weeklyCommentaries!;

    try {
      final csvString = await rootBundle.loadString(
        'assets/data/url_list2.csv',
      );
      final lines = csvString.split('\n');

      _weeklyCommentaries = [];
      for (int i = 1; i < lines.length; i++) {
        // 헤더 제외
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          try {
            _weeklyCommentaries!.add(WeeklyCommentary.fromCsv(line));
          } catch (e) {
            print('Error parsing weekly commentary line $i: $line - $e');
          }
        }
      }

      return _weeklyCommentaries!;
    } catch (e) {
      print('Error loading weekly commentaries: $e');
      return [];
    }
  }

  // 오늘의 읽기 데이터 가져오기
  Future<DailyReading?> getTodaysReading() async {
    return getReadingByDate(DateTime.now());
  }

  // 특정 날짜의 읽기 데이터 가져오기
  Future<DailyReading?> getReadingByDate(DateTime date) async {
    // 일요일/휴식 주/일정 범위 밖은 읽기 없음
    if (date.weekday == DateTime.sunday ||
        DateHelper.isBreakWeek(date) ||
        DateHelper.isBeforeScheduleStart(date) ||
        DateHelper.isAfterScheduleEnd(date)) {
      return null;
    }

    // ✅ 핵심 수정:
    // `url_list.csv`는 2025 날짜로 되어 있으므로, 2026에서는 날짜 매칭이 불가능합니다.
    // 대신 "주차/일차"로 인덱스를 계산해서 동일 커리큘럼의 행을 가져옵니다.
    final plan = await ReadingPlanService().getPlanForDate(date);
    if (plan == null) return null;

    final readings = await getDailyReadings();
    final index = (plan.week - 1) * 6 + (plan.day - 1); // 0-based
    if (index < 0 || index >= readings.length) return null;

    return readings[index];
  }

  // 이번 주 해설 가져오기 (오늘의 읽기와 같은 권/장 기준)
  Future<WeeklyCommentary?> getThisWeeksCommentary() async {
    final commentaries = await getWeeklyCommentaries();
    final todaysReading = await getTodaysReading();

    // 오늘의 읽기가 없으면 null 반환
    if (todaysReading == null) {
      return null;
    }

    // 오늘의 읽기와 같은 권/장에 해당하는 주간 해설 찾기
    for (final commentary in commentaries) {
      if (commentary.volume == todaysReading.volume &&
          commentary.chapter == todaysReading.chapter) {
        return commentary;
      }
    }

    return null;
  }

  // 일별 설명 이미지 URL 생성
  String getDailyExplanationImageUrl(DateTime date) {
    // 휴식 주를 고려한 조정된 날짜 사용
    final adjustedDate = DateHelper.getAdjustedDate(date);
    final dateStr =
        "${adjustedDate.year}-${adjustedDate.month.toString().padLeft(2, '0')}-${adjustedDate.day.toString().padLeft(2, '0')}";
    return 'https://raw.githubusercontent.com/inspiratives/RJesus/main/Summary/$dateStr.png';
  }

  // 오늘의 읽기 일정에 맞는 일별 설명 이미지 경로 생성 (로컬 assets)
  Future<String?> getTodaysExplanationImagePath() async {
    final todaysReading = await getTodaysReading();
    if (todaysReading != null) {
      // 로컬 assets 경로 생성
      // 예: assets/images/summary/4권1강/4권1강_성경읽기_2.jpg
      final volume = todaysReading.volume;
      final chapter = todaysReading.chapter;
      final day = todaysReading.day;

      final folderName = '${volume}권${chapter}강';
      final fileName = '${volume}권${chapter}강_성경읽기_${day}.jpg';

      return 'assets/images/summary/$folderName/$fileName';
    }
    return null;
  }

  // 오늘의 읽기 일정에 맞는 일별 설명 이미지 URL 생성 (GitHub - 백업용)
  Future<String?> getTodaysExplanationImageUrl() async {
    final todaysReading = await getTodaysReading();
    if (todaysReading != null) {
      // GitHub 저장소의 실제 파일 구조에 맞게 URL 생성
      // 예: https://raw.githubusercontent.com/inspiratives/RJesus/main/Summary/4권%20성경읽기/4권1강/4권1강_성경읽기_2.jpg
      final volume = todaysReading.volume;
      final chapter = todaysReading.chapter;
      final day = todaysReading.day;

      final folderName = '${volume}권%20성경읽기';
      final subfolderName = '${volume}권${chapter}강';
      final fileName = '${volume}권${chapter}강_성경읽기_${day}.jpg';

      return 'https://raw.githubusercontent.com/inspiratives/RJesus/main/Summary/$folderName/$subfolderName/$fileName';
    }
    return null;
  }

  // 캐시 초기화 (필요시)
  void clearCache() {
    _dailyReadings = null;
    _weeklyCommentaries = null;
  }
}
