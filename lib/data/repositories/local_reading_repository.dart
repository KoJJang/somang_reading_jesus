import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';
import '../models/reading_completion.dart';
import '../services/database_service.dart';
import 'reading_completion_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SQLite 기반의 로컬 통독 완료 데이터 저장소
class LocalReadingRepository implements ReadingCompletionRepository {
  static const String tableName = 'reading_completions';
  static const String syncSettingsTable = 'sync_settings';
  final DatabaseService _databaseService = DatabaseService();
  final _logger = Logger();

  // 현재 사용중인 UID (null이면 비로그인 상태)
  String? _currentUid;

  // 현재 UID 설정
  void setCurrentUid(String? uid) {
    _currentUid = uid;
  }

  // 데이터베이스 초기화 시 호출, 필요한 마이그레이션 수행
  Future<void> initialize() async {
    try {
      final db = await _databaseService.userDatabase;

      // uid 컬럼이 있는지 확인
      final result = await db.rawQuery("PRAGMA table_info($tableName)");
      bool hasUidColumn = false;

      for (var column in result) {
        if (column['name'] == 'uid') {
          hasUidColumn = true;
          break;
        }
      }

      // uid 컬럼이 없으면 추가
      if (!hasUidColumn) {
        _logger.i('uid 컬럼 추가를 위한 마이그레이션 시작');
        await db.execute(
          "ALTER TABLE $tableName ADD COLUMN uid TEXT DEFAULT 'local_user'",
        );
        _logger.i('uid 컬럼 추가 완료');
      }
    } catch (e) {
      _logger.e('데이터베이스 마이그레이션 중 오류: $e');
    }
  }

  @override
  Future<void> markAsCompleted(ReadingCompletion completion) async {
    try {
      final db = await _databaseService.userDatabase;
      await db.insert(tableName, {
        'date': completion.date.toIso8601String(),
        'year': completion.year,
        'week': completion.week,
        'day': completion.day,
        'readings': completion.readings.toString(),
        'uid': _currentUid ?? 'local_user', // UID가 없으면 로컬 사용자로 기록
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      _logger.i('로컬에 통독 완료 데이터 저장: ${completion.date}');
    } catch (e) {
      _logger.e('통독 완료 표시 중 오류: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isCompleted(int year, int week, int day) async {
    try {
      final db = await _databaseService.userDatabase;
      // 임시로 uid 필터 제거하고 기본 조건으로만 쿼리
      final result = await db.query(
        tableName,
        where: "year = ? AND week = ? AND day = ?",
        whereArgs: [year, week, day],
      );
      return result.isNotEmpty;
    } catch (e) {
      _logger.e('완료 상태 확인 중 오류: $e');
      return false;
    }
  }

  @override
  Future<List<ReadingCompletion>> getCompletions() async {
    try {
      final db = await _databaseService.userDatabase;
      // 임시로 uid 필터 제거
      final results = await db.query(
        tableName,
        orderBy: 'year DESC, week DESC, day DESC',
      );

      return results.map((map) {
        // readings 필드를 문자열에서 List<Map<String, dynamic>>으로 변환
        List<Map<String, dynamic>> readingsList = [];
        // TODO: 저장 방식에 따라 파싱 로직 구현 필요

        // 임시 변환 로직 (실제 DB 데이터 형식에 맞게 조정 필요)
        return ReadingCompletion(
          date: DateTime.parse(map['date'] as String),
          year: map['year'] as int,
          week: map['week'] as int,
          day: map['day'] as int,
          readings: readingsList,
        );
      }).toList();
    } catch (e) {
      _logger.e('완료 데이터 조회 중 오류: $e');
      return [];
    }
  }

  @override
  Future<List<ReadingCompletion>> getCompletionsByYear(int year) async {
    try {
      final db = await _databaseService.userDatabase;
      // 임시로 uid 필터 제거
      final results = await db.query(
        tableName,
        where: 'year = ?',
        whereArgs: [year],
        orderBy: 'week ASC, day ASC',
      );

      return results.map((map) {
        // readings 필드를 문자열에서 List<Map<String, dynamic>>으로 변환
        List<Map<String, dynamic>> readingsList = [];
        // TODO: 저장 방식에 따라 파싱 로직 구현 필요

        return ReadingCompletion(
          date: DateTime.parse(map['date'] as String),
          year: map['year'] as int,
          week: map['week'] as int,
          day: map['day'] as int,
          readings: readingsList,
        );
      }).toList();
    } catch (e) {
      _logger.e('연도별 완료 데이터 조회 중 오류: $e');
      return [];
    }
  }

  /// 지정된 사용자 ID로 마지막 동기화 시간 저장
  Future<void> saveLastSyncTime(String uid, DateTime time) async {
    try {
      final prefs = await _getPrefs();
      final key = 'last_sync_$uid';
      await prefs.setString(key, time.toIso8601String());
    } catch (e) {
      _logger.e('마지막 동기화 시간 저장 중 오류: $e');
    }
  }

  /// 지정된 사용자 ID의 마지막 동기화 시간 로드
  Future<DateTime?> loadLastSyncTime(String uid) async {
    try {
      final prefs = await _getPrefs();
      final key = 'last_sync_$uid';
      final timeStr = prefs.getString(key);
      if (timeStr != null) {
        return DateTime.parse(timeStr);
      }
      return null;
    } catch (e) {
      _logger.e('마지막 동기화 시간 로드 중 오류: $e');
      return null;
    }
  }

  /// 모든 완료 데이터 삭제
  Future<void> deleteAllCompletions() async {
    try {
      final db = await _databaseService.userDatabase;
      await db.delete(tableName);
      _logger.i('모든 통독 완료 데이터 삭제 완료');
    } catch (e) {
      _logger.e('통독 완료 데이터 삭제 중 오류: $e');
      rethrow;
    }
  }

  // SharedPreferences 인스턴스 가져오기
  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  /// 테이블 생성 (데이터베이스 초기화 시 호출)
  Future<void> createTable(Database db) async {
    try {
      // 통독 완료 테이블 생성
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT,
          year INTEGER,
          week INTEGER,
          day INTEGER,
          readings TEXT,
          uid TEXT,
          UNIQUE(date, uid)
        )
      ''');

      // 동기화 설정 테이블 생성
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $syncSettingsTable (
          uid TEXT PRIMARY KEY,
          last_sync_time TEXT,
          auto_sync INTEGER DEFAULT 0
        )
      ''');

      _logger.i('데이터베이스 테이블 생성 완료');
    } catch (e) {
      _logger.e('테이블 생성 중 오류: $e');
      rethrow;
    }
  }

  /// 자동 동기화 설정 저장
  Future<void> saveAutoSyncSetting(String uid, bool enabled) async {
    try {
      final db = await _databaseService.userDatabase;
      await db.insert(syncSettingsTable, {
        'uid': uid,
        'auto_sync': enabled ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      _logger.e('자동 동기화 설정 저장 중 오류: $e');
    }
  }

  /// 자동 동기화 설정 조회
  Future<bool> getAutoSyncSetting(String uid) async {
    try {
      final db = await _databaseService.userDatabase;
      final result = await db.query(
        syncSettingsTable,
        where: "uid = ?",
        whereArgs: [uid],
      );

      if (result.isNotEmpty) {
        final autoSync = result.first['auto_sync'] as int;
        return autoSync == 1;
      }
      return false; // 기본값은 비활성화
    } catch (e) {
      _logger.e('자동 동기화 설정 조회 중 오류: $e');
      return false;
    }
  }
}
