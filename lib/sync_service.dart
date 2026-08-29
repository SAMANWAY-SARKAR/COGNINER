import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';

class SyncService {
  static String get _baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  final _db = DatabaseHelper.instance;

  Future<void> trySync() async {
    final List<ConnectivityResult> connectivity = await Connectivity().checkConnectivity();

    if (connectivity.contains(ConnectivityResult.none) || connectivity.isEmpty) {
      return;
    }

    await _syncPatients();
    await _syncCaregivers();
    await _syncGameSessions();
    await _syncMusicSessions();
    await _syncRegionalMusicPlays();
  }

  Future<void> _syncPatients() async {
    final unsynced = await _db.getUnsyncedPatients();
    for (final patient in unsynced) {
      final success = await _post('/patients/', patient);
      if (success) {
        await _db.markPatientSynced(patient['user_id']);
      }
    }
  }

  Future<void> _syncCaregivers() async {
    final unsynced = await _db.getUnsyncedCaregivers();
    for (final caregiver in unsynced) {
      final success = await _post('/caregivers/', caregiver);
      if (success) {
        await _db.markCaregiverSynced(caregiver['caregiver_id']);
      }
    }
  }

  Future<void> _syncGameSessions() async {
    final unsynced = await _db.getUnsyncedGameSessions();
    for (final session in unsynced) {
      final success = await _post('/game-sessions/', session);
      if (success) {
        await _db.markGameSessionSynced(session['session_id']);
      }
    }
  }

  Future<void> _syncMusicSessions() async {
    final unsynced = await _db.getUnsyncedMusicSessions();
    for (final session in unsynced) {
      final success = await _post('/music-sessions/', session);
      if (success) {
        await _db.markMusicSessionSynced(session['session_id']);
      }
    }
  }

  Future<void> _syncRegionalMusicPlays() async {
    final unsynced = await _db.getUnsyncedRegionalMusicPlays();
    for (final play in unsynced) {
      final success = await _post('/regional-music-plays/', play);
      if (success) {
        await _db.markRegionalMusicPlaySynced(play['play_id']);
      }
    }
  }

  Future<bool> _post(String path, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}