// SQLite DB service
// lib/services/local_db_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDBService {
  static Database? _database;

  /// 데이터베이스 인스턴스 반환
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// DB 초기화 및 테이블 생성
  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'summary.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 진료요약 테이블 생성
        await db.execute('''
          CREATE TABLE summaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_name TEXT,
            chart_number TEXT,
            created_at TEXT,
            content TEXT
          )
        ''');
      },
    );
  }

  /// 요약 기록 저장
  Future<void> saveSummary(String patientName, String chartNumber, String content) async {
    final db = await database;
    await db.insert(
      'summaries',
      {
        'patient_name': patientName,
        'chart_number': chartNumber,
        'created_at': DateTime.now().toIso8601String(),
        'content': content,
      },
    );
  }

  /// 전체 요약 기록 조회
  Future<List<Map<String, dynamic>>> getSummaries() async {
    final db = await database;
    return await db.query(
      'summaries',
      orderBy: 'created_at DESC',
    );
  }

  /// 이름 또는 차트번호로 검색
  Future<List<Map<String, dynamic>>> searchSummaries({String? name, String? chart}) async {
    final db = await database;
    String where = '';
    List<String> args = [];

    if (name != null && name.isNotEmpty) {
      where += 'patient_name LIKE ?';
      args.add('%\$name%');
    }
    if (chart != null && chart.isNotEmpty) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'chart_number LIKE ?';
      args.add('%\$chart%');
    }

    return await db.query(
      'summaries',
      where: where.isNotEmpty ? where : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
    );
  }
}