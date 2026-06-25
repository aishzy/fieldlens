import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/inspection_report_model.dart';
import '../models/user_model.dart';

class DatabaseHelper {
  static const _databaseName = 'dilapidation_survey.db';
  static const _databaseVersion = 6;

  static const String usersTable = 'users';
  static const String inspectionReportsTable = 'inspection_reports';

  static Database? _database;

  static Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _createInspectionTable(Database db) async {
    await db.execute('''
      CREATE TABLE $inspectionReportsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        item_number TEXT NOT NULL,
        photo_path TEXT NOT NULL,
        photo_paths TEXT NOT NULL,
        defect_type TEXT NOT NULL,
        defect_code TEXT NOT NULL,
        location TEXT NOT NULL,
        inspector_comments TEXT NOT NULL,
        impact_category TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'No Defect',
        ref_no TEXT NOT NULL DEFAULT '',
        section TEXT NOT NULL DEFAULT '',
        scope_internal INTEGER DEFAULT 0,
        scope_external INTEGER DEFAULT 0,
        scope_me INTEGER DEFAULT 0,
        scope_public_facilities INTEGER DEFAULT 0,
        selected_defect_codes TEXT NOT NULL DEFAULT '[]',
        latitude REAL,
        longitude REAL,
        address TEXT,
        timestamp TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        inspection_mode TEXT NOT NULL DEFAULT 'defect',
        FOREIGN KEY(user_id) REFERENCES $usersTable(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_inspections_user_id ON $inspectionReportsTable(user_id)
    ''');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $usersTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        inspector_id TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await _createInspectionTable(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN photo_paths TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN status TEXT NOT NULL DEFAULT 'No Defect'",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN latitude REAL",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN longitude REAL",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN address TEXT",
      );
      await db.execute(
        "UPDATE $inspectionReportsTable SET photo_paths = '[\"' || REPLACE(photo_path, '\"', '\\\"') || '\"]' WHERE photo_path IS NOT NULL AND photo_path != ''",
      );
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN ref_no TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN section TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN scope_internal INTEGER DEFAULT 0",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN scope_external INTEGER DEFAULT 0",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN scope_me INTEGER DEFAULT 0",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN scope_public_facilities INTEGER DEFAULT 0",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN selected_defect_codes TEXT NOT NULL DEFAULT '[]'",
      );
    }

    if (oldVersion < 5) {
      final inspections = await db.query(inspectionReportsTable);
      await db.execute('DROP TABLE IF EXISTS ${inspectionReportsTable}_legacy');
      await db.execute(
        'ALTER TABLE $inspectionReportsTable RENAME TO ${inspectionReportsTable}_legacy',
      );
      await _createInspectionTable(db);

      for (final row in inspections) {
        await db.insert(
          inspectionReportsTable,
          _migrateInspectionRow(row),
        );
      }

      await db.execute('DROP TABLE IF EXISTS ${inspectionReportsTable}_legacy');
      await db.execute('DROP TABLE IF EXISTS sessions');
    }

    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN inspection_mode TEXT NOT NULL DEFAULT 'defect'",
      );
    }
  }

  static Map<String, dynamic> _migrateInspectionRow(
    Map<String, dynamic> row,
  ) {
    final photoPaths = _parseLegacyPhotoPaths(row);
    final defectCodes = _parseLegacyList(row['selected_defect_codes']);

    return {
      'id': row['id'],
      'user_id': row['user_id'],
      'item_number': row['item_number'] ?? '',
      'photo_path': photoPaths.isNotEmpty ? photoPaths.first : '',
      'photo_paths': jsonEncode(photoPaths),
      'defect_type': row['defect_type'] ?? 'General',
      'defect_code': row['defect_code'] ?? 'ND0',
      'location': row['location'] ?? '',
      'inspector_comments': row['inspector_comments'] ?? '',
      'impact_category': row['impact_category'] ?? 'Minor',
      'status': row['status'] ?? 'No Defect',
      'ref_no': row['ref_no'] ?? '',
      'section': row['section'] ?? '',
      'scope_internal': _boolInt(row['scope_internal']),
      'scope_external': _boolInt(row['scope_external']),
      'scope_me': _boolInt(row['scope_me']),
      'scope_public_facilities': _boolInt(row['scope_public_facilities']),
      'selected_defect_codes': jsonEncode(defectCodes),
      'latitude': row['latitude'],
      'longitude': row['longitude'],
      'address': row['address'],
      'timestamp': row['timestamp'] ?? DateTime.now().toIso8601String(),
      'is_synced': _boolInt(row['is_synced']),
    };
  }

  static List<String> _parseLegacyPhotoPaths(Map<String, dynamic> row) {
    final rawPhotoPaths = row['photo_paths'];
    if (rawPhotoPaths is String && rawPhotoPaths.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPhotoPaths);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    final legacyPhotoPath = row['photo_path'];
    if (legacyPhotoPath is String && legacyPhotoPath.isNotEmpty) {
      return [legacyPhotoPath];
    }

    return const [];
  }

  static List<String> _parseLegacyList(dynamic value) {
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  static int _boolInt(dynamic value) {
    if (value == true || value == 1) return 1;
    return 0;
  }

  static Future<void> initDatabase() async {
    await database;
  }

  static Future<bool> createUser(UserModel user) async {
    try {
      final db = await database;
      await db.insert(
        usersTable,
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<UserModel?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      usersTable,
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  static Future<UserModel?> getUserById(String id) async {
    final db = await database;
    final maps = await db.query(
      usersTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  static Future<bool> saveInspectionReport(InspectionReportModel report) async {
    try {
      final db = await database;
      await db.insert(
        inspectionReportsTable,
        report.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<InspectionReportModel>> getInspectionsByUserId(
    String userId,
  ) async {
    final db = await database;
    final maps = await db.query(
      inspectionReportsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return List.generate(
      maps.length,
      (i) => InspectionReportModel.fromMap(maps[i]),
    );
  }

  static Future<List<InspectionReportModel>> getAllInspections() async {
    final db = await database;
    final maps = await db.query(
      inspectionReportsTable,
      orderBy: 'timestamp DESC',
    );
    return List.generate(
      maps.length,
      (i) => InspectionReportModel.fromMap(maps[i]),
    );
  }

  static Future<InspectionReportModel?> getInspectionById(String id) async {
    final db = await database;
    final maps = await db.query(
      inspectionReportsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return InspectionReportModel.fromMap(maps.first);
  }

  static Future<int> getInspectionCount(String userId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) as count FROM $inspectionReportsTable WHERE user_id = ?',
        [userId],
      ),
    );
    return count ?? 0;
  }

  static Future<bool> updateInspectionReport(
    InspectionReportModel report,
  ) async {
    try {
      final db = await database;
      final changes = await db.update(
        inspectionReportsTable,
        report.toMap(),
        where: 'id = ?',
        whereArgs: [report.id],
      );
      return changes > 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteInspectionReport(String id) async {
    try {
      final db = await database;
      await db.delete(
        inspectionReportsTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> generateNextReportNumber() async {
    final db = await database;
    final year = DateTime.now().year.toString();
    final count = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $inspectionReportsTable WHERE timestamp LIKE ?',
            ['$year-%'],
          ),
        ) ??
        0;
    final next = (count + 1).toString().padLeft(3, '0');
    return 'FL-$year-$next';
  }

  static Future<void> deleteAllData() async {
    final db = await database;
    await db.delete(inspectionReportsTable);
    await db.delete(usersTable);
  }
}
