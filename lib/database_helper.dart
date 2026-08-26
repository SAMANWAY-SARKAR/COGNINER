// database_helper.dart
//
// UPDATED schema: patients / game_sessions / music_sessions / caregiver_alerts,
// including cumulative_score, daily_score, current_streak, and last_activity_date.
//
// pubspec.yaml dependencies needed:
//   sqflite: ^2.3.0
//   path: ^1.9.0
//   uuid: ^4.0.0
// then: flutter pub get

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'cogniner.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        user_id               TEXT PRIMARY KEY,
        name                  TEXT NOT NULL,
        age                   INTEGER,
        language_preference   TEXT DEFAULT 'Assamese',
        baseline_score        INTEGER DEFAULT 50,
        cumulative_score      INTEGER DEFAULT 0,
        daily_score           INTEGER DEFAULT 0,
        current_streak        INTEGER DEFAULT 0,
        last_activity_date    TEXT,
        created_at            DATETIME DEFAULT CURRENT_TIMESTAMP,
        synced                INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE game_sessions (
        session_id             TEXT PRIMARY KEY,
        user_id                 TEXT NOT NULL,
        game_type               TEXT NOT NULL,
        completion_time_sec     INTEGER NOT NULL,
        errors_made              INTEGER NOT NULL,
        engagement_score         INTEGER NOT NULL,
        timestamp                 DATETIME DEFAULT CURRENT_TIMESTAMP,
        synced                    INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES patients(user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE music_sessions (
        session_id             TEXT PRIMARY KEY,
        user_id                 TEXT NOT NULL,
        track_id                 TEXT NOT NULL,
        engagement_indicator     TEXT,
        timestamp                 DATETIME DEFAULT CURRENT_TIMESTAMP,
        synced                    INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES patients(user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE caregiver_alerts (
        alert_id                TEXT PRIMARY KEY,
        user_id                  TEXT NOT NULL,
        alert_type                TEXT NOT NULL,
        message                    TEXT NOT NULL,
        created_at                  DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES patients(user_id) ON DELETE CASCADE
      )
    ''');
  }

  // ---------- PATIENTS ----------

  Future<String> insertPatient({
    required String name,
    int? age,
    String languagePreference = 'Assamese',
  }) async {
    final db = await database;
    final id = _uuid.v4();
    await db.insert('patients', {
      'user_id': id,
      'name': name,
      'age': age,
      'language_preference': languagePreference,
      'cumulative_score': 0,
      'daily_score': 0,
      'current_streak': 0,
      'last_activity_date': null,
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllPatients() async {
    final db = await database;
    return await db.query('patients');
  }

  Future<void> updatePatientScores({
    required String userId,
    required int cumulativeScore,
    required int dailyScore,
    required int currentStreak,
    required String lastActivityDate,
  }) async {
    final db = await database;
    await db.update(
      'patients',
      {
        'cumulative_score': cumulativeScore,
        'daily_score': dailyScore,
        'current_streak': currentStreak,
        'last_activity_date': lastActivityDate,
        'synced': 0, // Mark unsynced so server picks up score updates
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ---------- GAME SESSIONS ----------

  Future<String> insertGameSession({
    required String userId,
    required String gameType,
    required int completionTimeSec,
    required int errorsMade,
    required int engagementScore,
  }) async {
    final db = await database;
    final id = _uuid.v4();
    await db.insert('game_sessions', {
      'session_id': id,
      'user_id': userId,
      'game_type': gameType,
      'completion_time_sec': completionTimeSec,
      'errors_made': errorsMade,
      'engagement_score': engagementScore,
    });
    return id;
  }

  // ---------- MUSIC SESSIONS ----------

  Future<String> insertMusicSession({
    required String userId,
    required String trackId,
    String? engagementIndicator,
  }) async {
    final db = await database;
    final id = _uuid.v4();
    await db.insert('music_sessions', {
      'session_id': id,
      'user_id': userId,
      'track_id': trackId,
      'engagement_indicator': engagementIndicator,
    });
    return id;
  }

  // ---------- SYNC SUPPORT ----------

  Future<List<Map<String, dynamic>>> getUnsyncedPatients() async {
    final db = await database;
    return await db.query('patients', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedGameSessions() async {
    final db = await database;
    return await db.query('game_sessions', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedMusicSessions() async {
    final db = await database;
    return await db.query('music_sessions', where: 'synced = 0');
  }

  Future<void> markPatientSynced(String userId) async {
    final db = await database;
    await db.update('patients', {'synced': 1},
        where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> markGameSessionSynced(String sessionId) async {
    final db = await database;
    await db.update('game_sessions', {'synced': 1},
        where: 'session_id = ?', whereArgs: [sessionId]);
  }

  Future<void> markMusicSessionSynced(String sessionId) async {
    final db = await database;
    await db.update('music_sessions', {'synced': 1},
        where: 'session_id = ?', whereArgs: [sessionId]);
  }
}