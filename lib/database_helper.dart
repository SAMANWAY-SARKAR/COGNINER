import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static sqlite.Database? _database;
  final _uuid = const Uuid();

  final List<Map<String, dynamic>> _webPatients = [];
  final List<Map<String, dynamic>> _webCaregivers = [];
  final List<Map<String, dynamic>> _webCaregiverPatients = [];
  final List<Map<String, dynamic>> _webGameSessions = [];
  final List<Map<String, dynamic>> _webMusicSessions = [];
  final List<Map<String, dynamic>> _webRegionalMusicPlays = [];

  Future<sqlite.Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initNativeDatabase();
    return _database!;
  }

  Future<sqlite.Database> _initNativeDatabase() async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      sqlite.databaseFactory = databaseFactoryFfi;
    }
    String path = join(await sqlite.getDatabasesPath(), 'cogniner.db');
    return await sqlite.openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(sqlite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        user_id               TEXT PRIMARY KEY,
        registration_number   TEXT UNIQUE,
        name                  TEXT NOT NULL,
        email                 TEXT UNIQUE,
        phone                 TEXT UNIQUE,
        password              TEXT,
        age                   INTEGER,
        photo                 TEXT,
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
      CREATE TABLE caregivers (
        caregiver_id          TEXT PRIMARY KEY,
        name                  TEXT NOT NULL,
        email                 TEXT UNIQUE,
        phone                 TEXT UNIQUE,
        password              TEXT,
        institution           TEXT,
        created_at            DATETIME DEFAULT CURRENT_TIMESTAMP,
        synced                INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE caregiver_patients (
        caregiver_id          TEXT,
        patient_id            TEXT,
        PRIMARY KEY (caregiver_id, patient_id),
        FOREIGN KEY (caregiver_id) REFERENCES caregivers(caregiver_id) ON DELETE CASCADE,
        FOREIGN KEY (patient_id) REFERENCES patients(user_id) ON DELETE CASCADE
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
      CREATE TABLE regional_music_plays (
        play_id                TEXT PRIMARY KEY,
        user_id                TEXT NOT NULL,
        state_name             TEXT NOT NULL,
        song_title             TEXT NOT NULL,
        duration_seconds       INTEGER DEFAULT 0,
        loop_count             INTEGER DEFAULT 0,
        emotional_state        TEXT,
        cognitive_response     TEXT,
        timestamp              DATETIME DEFAULT CURRENT_TIMESTAMP,
        synced                 INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES patients(user_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<String> insertPatient({
    required String registrationNumber,
    required String name,
    String? email,
    String? phone,
    String? password,
    int? age,
    String? photo,
    String languagePreference = 'Assamese',
  }) async {
    final id = _uuid.v4();
    final patientData = {
      'user_id': id,
      'registration_number': registrationNumber,
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'age': age,
      'photo': photo,
      'language_preference': languagePreference,
      'cumulative_score': 0,
      'daily_score': 0,
      'current_streak': 0,
      'last_activity_date': null,
      'synced': 0,
    };
    if (kIsWeb) {
      _webPatients.add(patientData);
      return id;
    }
    final db = await database;
    await db!.insert('patients', patientData);
    return id;
  }

  Future<String> insertCaregiver({
    required String name,
    String? email,
    String? phone,
    String? password,
    String? institution,
  }) async {
    final id = _uuid.v4();
    final caregiverData = {
      'caregiver_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'institution': institution,
      'synced': 0,
    };
    if (kIsWeb) {
      _webCaregivers.add(caregiverData);
      return id;
    }
    final db = await database;
    await db!.insert('caregivers', caregiverData);
    return id;
  }

  Future<Map<String, dynamic>?> searchPatientByRegistration(String regNumber) async {
    if (kIsWeb) {
      try {
        return _webPatients.firstWhere((p) => p['registration_number'] == regNumber);
      } catch (e) {
        return null;
      }
    }
    final db = await database;
    final result = await db!.query('patients', where: 'registration_number = ?', whereArgs: [regNumber]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> linkPatientToCaregiver(String caregiverId, String patientId) async {
    if (kIsWeb) {
      _webCaregiverPatients.add({'caregiver_id': caregiverId, 'patient_id': patientId});
      return;
    }
    final db = await database;
    await db!.insert('caregiver_patients', {
      'caregiver_id': caregiverId,
      'patient_id': patientId,
    }, conflictAlgorithm: sqlite.ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> getPatientsForCaregiver(String caregiverId) async {
    if (kIsWeb) {
      final linkedPatientIds = _webCaregiverPatients.where((link) => link['caregiver_id'] == caregiverId).map((link) => link['patient_id']).toList();
      return _webPatients.where((p) => linkedPatientIds.contains(p['user_id'])).toList();
    }
    final db = await database;
    return await db!.rawQuery('''
      SELECT p.* 
      FROM patients p
      INNER JOIN caregiver_patients cp ON p.user_id = cp.patient_id
      WHERE cp.caregiver_id = ?
    ''', [caregiverId]);
  }

  Future<Map<String, dynamic>?> verifyLogin(String identifier, String password) async {
    if (kIsWeb) {
      try {
        final patient = _webPatients.firstWhere((p) =>
            (p['email'] == identifier || p['phone'] == identifier) && p['password'] == password);
        return {'role': 'patient', 'data': patient};
      } catch (e) {
        try {
          final caregiver = _webCaregivers.firstWhere((c) =>
              (c['email'] == identifier || c['phone'] == identifier) && c['password'] == password);
          return {'role': 'caregiver', 'data': caregiver};
        } catch (e) {
          return null;
        }
      }
    }
    final db = await database;
    final List<Map<String, dynamic>> pResult = await db!.query('patients', where: '(email = ? OR phone = ?) AND password = ?', whereArgs: [identifier, identifier, password]);
    if (pResult.isNotEmpty) return {'role': 'patient', 'data': pResult.first};
    final List<Map<String, dynamic>> cResult = await db.query('caregivers', where: '(email = ? OR phone = ?) AND password = ?', whereArgs: [identifier, identifier, password]);
    if (cResult.isNotEmpty) return {'role': 'caregiver', 'data': cResult.first};
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllPatients() async {
    if (kIsWeb) return _webPatients;
    final db = await database;
    return await db!.query('patients');
  }

  Future<void> updatePatientScores({
    required String userId,
    required int cumulativeScore,
    required int dailyScore,
    required int currentStreak,
    required String lastActivityDate,
  }) async {
    if (kIsWeb) {
      final index = _webPatients.indexWhere((p) => p['user_id'] == userId);
      if (index != -1) {
        _webPatients[index]['cumulative_score'] = cumulativeScore;
        _webPatients[index]['daily_score'] = dailyScore;
        _webPatients[index]['current_streak'] = currentStreak;
        _webPatients[index]['last_activity_date'] = lastActivityDate;
      }
      return;
    }
    final db = await database;
    await db!.update('patients', {
      'cumulative_score': cumulativeScore, 'daily_score': dailyScore, 'current_streak': currentStreak, 'last_activity_date': lastActivityDate, 'synced': 0,
    }, where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<String> insertGameSession({
    required String userId, required String gameType, required int completionTimeSec, required int errorsMade, required int engagementScore,
  }) async {
    final id = _uuid.v4();
    final sessionData = {'session_id': id, 'user_id': userId, 'game_type': gameType, 'completion_time_sec': completionTimeSec, 'errors_made': errorsMade, 'engagement_score': engagementScore, 'synced': 0};
    if (kIsWeb) { _webGameSessions.add(sessionData); return id; }
    final db = await database; await db!.insert('game_sessions', sessionData); return id;
  }

  Future<String> insertMusicSession({
    required String userId, required String trackId, String? engagementIndicator,
  }) async {
    final id = _uuid.v4();
    final sessionData = {'session_id': id, 'user_id': userId, 'track_id': trackId, 'engagement_indicator': engagementIndicator, 'synced': 0};
    if (kIsWeb) { _webMusicSessions.add(sessionData); return id; }
    final db = await database; await db!.insert('music_sessions', sessionData); return id;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedPatients() async {
    if (kIsWeb) return _webPatients.where((p) => p['synced'] == 0).toList();
    final db = await database; return await db!.query('patients', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedCaregivers() async {
    if (kIsWeb) return _webCaregivers.where((c) => c['synced'] == 0).toList();
    final db = await database; return await db!.query('caregivers', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedGameSessions() async {
    if (kIsWeb) return _webGameSessions.where((s) => s['synced'] == 0).toList();
    final db = await database; return await db!.query('game_sessions', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedMusicSessions() async {
    if (kIsWeb) return _webMusicSessions.where((s) => s['synced'] == 0).toList();
    final db = await database; return await db!.query('music_sessions', where: 'synced = 0');
  }

  Future<void> markPatientSynced(String userId) async {
    if (kIsWeb) { final idx = _webPatients.indexWhere((p) => p['user_id'] == userId); if (idx != -1) _webPatients[idx]['synced'] = 1; return; }
    final db = await database; await db!.update('patients', {'synced': 1}, where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> markCaregiverSynced(String caregiverId) async {
    if (kIsWeb) { final idx = _webCaregivers.indexWhere((c) => c['caregiver_id'] == caregiverId); if (idx != -1) _webCaregivers[idx]['synced'] = 1; return; }
    final db = await database; await db!.update('caregivers', {'synced': 1}, where: 'caregiver_id = ?', whereArgs: [caregiverId]);
  }

  Future<void> markGameSessionSynced(String sessionId) async {
    if (kIsWeb) { final idx = _webGameSessions.indexWhere((s) => s['session_id'] == sessionId); if (idx != -1) _webGameSessions[idx]['synced'] = 1; return; }
    final db = await database; await db!.update('game_sessions', {'synced': 1}, where: 'session_id = ?', whereArgs: [sessionId]);
  }

  Future<void> markMusicSessionSynced(String sessionId) async {
    if (kIsWeb) { final idx = _webMusicSessions.indexWhere((s) => s['session_id'] == sessionId); if (idx != -1) _webMusicSessions[idx]['synced'] = 1; return; }
    final db = await database; await db!.update('music_sessions', {'synced': 1}, where: 'session_id = ?', whereArgs: [sessionId]);
  }

  // --- REGIONAL MUSIC PLAYS ---
  Future<void> insertRegionalMusicPlay({
    required String userId,
    required String stateName,
    required String songTitle,
    required int durationSeconds,
    required int loopCount,
    String? emotionalState,
    String? cognitiveResponse,
  }) async {
    final id = _uuid.v4();
    final data = {
      'play_id': id,
      'user_id': userId,
      'state_name': stateName,
      'song_title': songTitle,
      'duration_seconds': durationSeconds,
      'loop_count': loopCount,
      'emotional_state': emotionalState,
      'cognitive_response': cognitiveResponse,
      'synced': 0,
    };
    if (kIsWeb) { _webRegionalMusicPlays.add(data); return; }
    final db = await database; await db!.insert('regional_music_plays', data);
  }

  Future<List<Map<String, dynamic>>> getRegionalMusicPlays(String userId) async {
    if (kIsWeb) return _webRegionalMusicPlays.where((s) => s['user_id'] == userId).toList();
    final db = await database;
    return await db!.query('regional_music_plays', where: 'user_id = ?', whereArgs: [userId], orderBy: 'timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> getRegionalMusicPlaysByState(String userId, String stateName) async {
    if (kIsWeb) return _webRegionalMusicPlays.where((s) => s['user_id'] == userId && s['state_name'] == stateName).toList();
    final db = await database;
    return await db!.query('regional_music_plays',
      where: 'user_id = ? AND state_name = ?',
      whereArgs: [userId, stateName],
      orderBy: 'timestamp DESC');
  }

  Future<Map<String, dynamic>> getRegionalMusicSummary(String userId) async {
    final plays = await getRegionalMusicPlays(userId);
    int totalDuration = 0;
    int totalLoops = 0;
    Map<String, int> stateDurations = {};
    Map<String, int> stateLoops = {};
    String mostPlayedState = 'None';
    int maxStateDuration = 0;

    for (var play in plays) {
      int dur = play['duration_seconds'] as int? ?? 0;
      int loops = play['loop_count'] as int? ?? 0;
      String state = play['state_name'] as String? ?? 'Unknown';
      totalDuration += dur;
      totalLoops += loops;
      stateDurations[state] = (stateDurations[state] ?? 0) + dur;
      stateLoops[state] = (stateLoops[state] ?? 0) + loops;
      if ((stateDurations[state] ?? 0) > maxStateDuration) {
        maxStateDuration = stateDurations[state]!;
        mostPlayedState = state;
      }
    }

    return {
      'total_plays': plays.length,
      'total_duration_seconds': totalDuration,
      'total_loops': totalLoops,
      'most_played_state': mostPlayedState,
      'state_durations': stateDurations,
      'state_loops': stateLoops,
    };
  }

  // --- REGIONAL MUSIC PLAYS SYNC SUPPORT ---
  Future<List<Map<String, dynamic>>> getUnsyncedRegionalMusicPlays() async {
    if (kIsWeb) return _webRegionalMusicPlays.where((p) => p['synced'] == 0).toList();
    final db = await database; return await db!.query('regional_music_plays', where: 'synced = 0');
  }

  Future<void> markRegionalMusicPlaySynced(String playId) async {
    if (kIsWeb) { final idx = _webRegionalMusicPlays.indexWhere((p) => p['play_id'] == playId); if (idx != -1) _webRegionalMusicPlays[idx]['synced'] = 1; return; }
    final db = await database; await db!.update('regional_music_plays', {'synced': 1}, where: 'play_id = ?', whereArgs: [playId]);
  }
}