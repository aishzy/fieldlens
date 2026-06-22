import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import '../models/inspection_report_model.dart';

class DatabaseHelper {
  static const _databaseName = 'dilapidation_survey.db';
  static const _databaseVersion = 1;

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

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
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

    await db.execute('''
      CREATE TABLE $inspectionReportsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        item_number TEXT NOT NULL,
        photo_path TEXT NOT NULL,
        defect_type TEXT NOT NULL,
        defect_code TEXT NOT NULL,
        location TEXT NOT NULL,
        inspector_comments TEXT NOT NULL,
        impact_category TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(user_id) REFERENCES $usersTable(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_user_id ON $inspectionReportsTable(user_id)
    ''');
  }

  static Future<void> initDatabase() async {
    await database;
  }

  // User operations
  static Future<bool> createUser(UserModel user) async {
    try {
      final db = await database;
      await db.insert(
        usersTable,
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return true;
    } catch (e) {
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

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  static Future<UserModel?> getUserById(String id) async {
    final db = await database;
    final maps = await db.query(
      usersTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  // Inspection operations
  static Future<bool> saveInspectionReport(InspectionReportModel report) async {
    try {
      final db = await database;
      await db.insert(
        inspectionReportsTable,
        report.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<InspectionReportModel>> getInspectionsByUserId(String userId) async {
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

  static Future<bool> updateInspectionReport(InspectionReportModel report) async {
    try {
      final db = await database;
      final changes = await db.update(
        inspectionReportsTable,
        report.toMap(),
        where: 'id = ?',
        whereArgs: [report.id],
      );
      return changes > 0;
    } catch (e) {
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
    } catch (e) {
      return false;
    }
  }

  static Future<void> deleteAllData() async {
    final db = await database;
    await db.delete(inspectionReportsTable);
    await db.delete(usersTable);
  }
}
