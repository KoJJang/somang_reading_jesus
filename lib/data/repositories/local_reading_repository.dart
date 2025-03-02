import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';
import '../models/reading_completion.dart';
import '../services/database_service.dart';
import 'reading_completion_repository.dart';

/// SQLite 기반의 로컬 통독 완료 데이터 저장소
class LocalReadingRepository implements ReadingCompletionRepository {
  static const String tableName = 'reading_completions';
  final DatabaseService _databaseService = DatabaseService();
  final _logger = Logger();

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

  /// 테이블 생성 (데이터베이스 초기화 시 호출)
  Future<void> createTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableName (
          date TEXT PRIMARY KEY,
          year INTEGER,
          week INTEGER,
          day INTEGER,
          readings TEXT
        )
      ''');
      _logger.i('통독 완료 테이블 생성 완료');
    } catch (e) {
      _logger.e('통독 완료 테이블 생성 중 오류: $e');
      rethrow;
    }
  }
}
