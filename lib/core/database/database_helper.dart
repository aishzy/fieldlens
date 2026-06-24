import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import '../models/inspection_report_model.dart';

class DatabaseHelper {
  static const _databaseName = 'dilapidation_survey.db';
  static const _databaseVersion = 4;

  static const String usersTable = 'users';
  static const String sessionsTable = 'sessions';
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
      onUpgrade: _onUpgrade,
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
      CREATE TABLE $sessionsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        session_name TEXT NOT NULL,
        project_name TEXT NOT NULL,
        site_location TEXT NOT NULL,
        inspection_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES $usersTable(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $inspectionReportsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
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
        FOREIGN KEY(user_id) REFERENCES $usersTable(id),
        FOREIGN KEY(session_id) REFERENCES $sessionsTable(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_user_id ON $inspectionReportsTable(user_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_session_id ON $inspectionReportsTable(session_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_sessions_user_id ON $sessionsTable(user_id)
    ''');
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
        "ALTER TABLE $inspectionReportsTable ADD COLUMN project_name TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN project_code TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN project_site_location TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN report_number TEXT NOT NULL DEFAULT ''",
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
    if (oldVersion < 4) {
      // Create sessions table
      await db.execute('''
        CREATE TABLE $sessionsTable (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          session_name TEXT NOT NULL,
          project_name TEXT NOT NULL,
          site_location TEXT NOT NULL,
          inspection_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY(user_id) REFERENCES $usersTable(id)
        )
      ''');

      // Add session_id column to inspection_reports
      await db.execute(
        "ALTER TABLE $inspectionReportsTable ADD COLUMN session_id TEXT NOT NULL DEFAULT ''",
      );

      // Create default sessions and migrate existing inspections
      final users = await db.query(usersTable);
      for (final userRow in users) {
        final userId = userRow['id'] as String;
        
        // Get all inspections for this user
        final inspections = await db.query(
          inspectionReportsTable,
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        if (inspections.isNotEmpty) {
          // Create a default session for existing inspections
          final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
          await db.insert(sessionsTable, {
            'id': sessionId,
            'user_id': userId,
            'session_name': 'Default Session',
            'project_name': 'Migrated',
            'site_location': 'Migrated',
            'inspection_date': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          });

          // Update inspections to reference this session
          await db.update(
            inspectionReportsTable,
            {'session_id': sessionId},
            where: 'user_id = ?',
            whereArgs: [userId],
          );
        }
      }

      // Create indexes
      await db.execute('''
        CREATE INDEX idx_session_id ON $inspectionReportsTable(session_id)
      ''');
      await db.execute('''
        CREATE INDEX idx_sessions_user_id ON $sessionsTable(user_id)
      ''');
    }
  }

  static Future<void> initDatabase() async {
    await database;
  }

  // Session operations
  static Future<bool> createSession(Map<String, dynamic> sessionData) async {
    try {
      final db = await database;
      await db.insert(
        sessionsTable,
        sessionData,
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getSessionsByUserId(
      String userId) async {
    final db = await database;
    return await db.query(
      sessionsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  static Future<Map<String, dynamic>?> getSessionById(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      sessionsTable,
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  static Future<bool> updateSession(Map<String, dynamic> sessionData) async {
    try {
      final db = await database;
      final changes = await db.update(
        sessionsTable,
        sessionData,
        where: 'id = ?',
        whereArgs: [sessionData['id']],
      );
      return changes > 0;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteSession(String sessionId) async {
    try {
      final db = await database;
      await db.delete(
        sessionsTable,
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      return true;
    } catch (e) {
      return false;
    }
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

  static Future<List<InspectionReportModel>> getInspectionsByUserId(
    String userId, {
    String? sessionId,
  }) async {
    final db = await database;
    String where = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (sessionId != null) {
      where += ' AND session_id = ?';
      whereArgs.add(sessionId);
    }

    final maps = await db.query(
      inspectionReportsTable,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );

    return List.generate(
      maps.length,
      (i) => InspectionReportModel.fromMap(maps[i]),
    );
  }

  static Future<List<InspectionReportModel>> getInspectionsBySessionId(
      String sessionId) async {
    final db = await database;
    final maps = await db.query(
      inspectionReportsTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
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
      InspectionReportModel report) async {
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
