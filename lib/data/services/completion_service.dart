import 'package:sqflite/sqflite.dart';
import '../models/reading_completion.dart';
import 'database_service.dart';
import 'package:logger/logger.dart';

class CompletionService {
  static const String tableName = 'reading_completions';
  final DatabaseService _databaseService = DatabaseService();
  final _logger = Logger();

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
      _logger.i('Reading completions table created successfully');
    } catch (e) {
      _logger.e('Error creating reading completions table: $e');
      rethrow;
    }
  }

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
      _logger.i('Marked reading as completed for date: ${completion.date}');
    } catch (e) {
      _logger.e('Error marking reading as completed: $e');
      rethrow;
    }
  }

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
      _logger.e('Error checking completion status: $e');
      return false;
    }
  }

  Future<List<ReadingCompletion>> getCompletions() async {
    try {
      final db = await _databaseService.userDatabase;
      final results = await db.query(
        tableName,
        orderBy: 'year DESC, week DESC, day DESC',
      );
      return results.map((map) => ReadingCompletion.fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error getting completions: $e');
      return [];
    }
  }
}
