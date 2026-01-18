import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // Add kIsWeb
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // Add web package
import '../models/bible_verse.dart';
import 'package:logger/logger.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _bibleDatabase;
  static Database? _userDatabase;
  final _logger = Logger(); // logger 인스턴스 생성

  // 팩토리 생성자
  factory DatabaseService() {
    return _instance;
  }

  // private 생성자
  DatabaseService._internal();

  // 초기화 메서드
  Future<void> initialize() async {
    if (kIsWeb) {
      // Use web factory
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // FFI 초기화
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // 데이터베이스 초기화
    await userDatabase;
  }

  // 성경 DB getter
  Future<Database> get bibleDatabase async {
    if (_bibleDatabase != null) return _bibleDatabase!;
    _bibleDatabase = await _initBibleDatabase();
    return _bibleDatabase!;
  }

  // 사용자 DB getter
  Future<Database> get userDatabase async {
    if (_userDatabase != null) return _userDatabase!;
    _userDatabase = await _initUserDatabase();
    return _userDatabase!;
  }

  Future<Database> _initBibleDatabase() async {
    try {
      await initialize();

      // Web Implementation
      if (kIsWeb) {
        // Warning: This creates an empty DB if not exists.
        // Pre-populating on web requires writing to IndexedDB or VFS which is complex
        // without proper setup. For now, we avoid the crash.
        // Ideally, we imports the bytes via a specialized web loader.
        _logger.w(
          'Web Bible DB initialization: Pre-population not fully supported yet in this quick fix.',
        );
        return await openDatabase('bible2.db');
      }

      String path = join(await getDatabasesPath(), 'bible2.db');
      _logger.d('Bible DB Path: $path');

      if (!await File(path).exists()) {
        _logger.i('Copying Bible DB file from assets...');
        ByteData data = await rootBundle.load('assets/data/bible2.db');
        List<int> bytes = data.buffer.asUint8List();
        await File(path).writeAsBytes(bytes);
        _logger.i('Bible DB file copied successfully');
      } else {
        _logger.i('Bible DB file already exists');
      }

      return await openDatabase(path, readOnly: true);
    } catch (e) {
      _logger.e('Error initializing Bible database: $e');
      rethrow;
    }
  }

  Future<Database> _initUserDatabase() async {
    try {
      String path = 'user_data.db';
      if (!kIsWeb) {
        path = join(await getDatabasesPath(), 'user_data.db');
        _logger.d(
          'User DB absolute path: ${File(path).absolute.path}',
        ); // 절대 경로 출력
      }

      return await openDatabase(
        path,
        version: 2, // 버전 증가
        onCreate: (db, version) async {
          _logger.i('Creating user database tables...');
          // 통독 완료 테이블 생성
          await db.execute('''
            CREATE TABLE reading_completions (
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
            CREATE TABLE IF NOT EXISTS sync_settings (
              uid TEXT PRIMARY KEY,
              last_sync_time TEXT,
              auto_sync INTEGER DEFAULT 0
            )
          ''');

          _logger.i('User database tables created successfully');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          _logger.i('Upgrading database from v$oldVersion to v$newVersion');
          if (oldVersion < 2) {
            // 기존 테이블에 uid 컬럼 추가 시도
            try {
              await db.execute(
                "ALTER TABLE reading_completions ADD COLUMN uid TEXT DEFAULT 'local_user'",
              );
              _logger.i('Added uid column to reading_completions table');
            } catch (e) {
              _logger.e('Error adding uid column: $e');
            }

            // UNIQUE 제약 조건을 다시 생성하기 위해 테이블 구조 수정
            try {
              // 1. 기존 테이블 이름 변경
              await db.execute(
                "ALTER TABLE reading_completions RENAME TO reading_completions_old",
              );

              // 2. 새 테이블 생성
              await db.execute('''
                CREATE TABLE reading_completions (
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

              // 3. 데이터 복사
              await db.execute('''
                INSERT INTO reading_completions (date, year, week, day, readings, uid)
                SELECT date, year, week, day, readings, uid FROM reading_completions_old
              ''');

              // 4. 이전 테이블 삭제
              await db.execute("DROP TABLE reading_completions_old");

              _logger.i('Successfully restructured reading_completions table');
            } catch (e) {
              _logger.e('Error restructuring reading_completions table: $e');
            }

            // 동기화 설정 테이블 생성
            try {
              await db.execute('''
                CREATE TABLE IF NOT EXISTS sync_settings (
                  uid TEXT PRIMARY KEY,
                  last_sync_time TEXT,
                  auto_sync INTEGER DEFAULT 0
                )
              ''');
              _logger.i('Created sync_settings table');
            } catch (e) {
              _logger.e('Error creating sync_settings table: $e');
            }
          }
        },
      );
    } catch (e) {
      _logger.e('Error initializing user database: $e');
      rethrow;
    }
  }

  // 성경 구절 조회 메서드들
  Future<List<BibleVerse>> getVersesByChapter(int book, int chapter) async {
    try {
      final db = await bibleDatabase;
      final List<Map<String, dynamic>> maps = await db.query(
        'bible2',
        where: 'book = ? AND chapter = ?',
        whereArgs: [book, chapter],
        orderBy: 'paragraph',
      );

      return maps.map((map) => BibleVerse.fromMap(map)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // 특정 구절 가져오기
  Future<BibleVerse?> getVerse(int book, int chapter, int paragraph) async {
    final db = await bibleDatabase;
    final List<Map<String, dynamic>> maps = await db.query(
      'bible2',
      where: 'book = ? AND chapter = ? AND paragraph = ?',
      whereArgs: [book, chapter, paragraph],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return BibleVerse.fromMap(maps.first);
  }

  // 책의 마지막 장 번호 가져오기
  Future<int?> getLastChapterNumber(int book) async {
    try {
      final db = await bibleDatabase;
      final result = await db.rawQuery(
        'SELECT MAX(chapter) as lastChapter FROM bible2 WHERE book = ?',
        [book],
      );
      return result.first['lastChapter'] as int?;
    } catch (e) {
      return null;
    }
  }

  // 다음 책 정보 가져오기
  Future<Map<String, dynamic>?> getNextBook(int currentBook) async {
    try {
      final db = await bibleDatabase;
      final result = await db.query(
        'bible2',
        where: 'book = ?',
        whereArgs: [currentBook + 1],
        groupBy: 'book',
        columns: ['book', 'long_label'],
      );

      if (result.isEmpty) return null;

      // 결과를 원하는 형식으로 변환
      return {
        'book': result.first['book'],
        'longLabel': result.first['long_label'],
      };
    } catch (e) {
      return null;
    }
  }

  // 이전 책 정보 가져오기
  Future<Map<String, dynamic>?> getPreviousBook(int currentBook) async {
    try {
      final db = await bibleDatabase;
      final result = await db.query(
        'bible2',
        where: 'book = ?',
        whereArgs: [currentBook - 1],
        groupBy: 'book',
        columns: ['book', 'long_label'],
      );

      if (result.isEmpty) return null;

      // 이전 책의 마지막 장 번호도 함께 가져오기
      final lastChapter = await getLastChapterNumber(currentBook - 1);

      return {
        'book': result.first['book'],
        'longLabel': result.first['long_label'],
        'lastChapter': lastChapter,
      };
    } catch (e) {
      _logger.e('Error getting previous book: $e');
      return null;
    }
  }

  Future<int?> getBookIdByName(String bookName) async {
    final db = await bibleDatabase;
    final result = await db.query(
      'bible2',
      columns: ['book'],
      where: 'long_label = ?',
      whereArgs: [bookName],
      groupBy: 'book',
    );
    if (result.isEmpty) return null;
    return result.first['book'] as int;
  }

  Future<String?> getFirstVerse(int book, int chapter) async {
    final db = await bibleDatabase;
    final result = await db.query(
      'bible2',
      columns: ['sentence'],
      where: 'book = ? AND chapter = ? AND paragraph = 1',
      whereArgs: [book, chapter],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['sentence'] as String;
  }
}
