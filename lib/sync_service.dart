import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';

class SyncService {
  // 10.0.2.2 is the exact IP the Android emulator uses to talk to your laptop's localhost
  static const String _baseUrl = 'http://10.0.2.2:8000'; 

  final _db = DatabaseHelper.instance;

  Future<void> trySync() async {
    final List<ConnectivityResult> connectivity = await Connectivity().checkConnectivity();
    
    if (connectivity.contains(ConnectivityResult.none) || connectivity.isEmpty) {
      return; // No internet, skip silently
    }

    // Sync Users First
    await _syncPatients();
    // (Note: Caregivers sync logic can be expanded here as they are added to the getUnsynced queries)
    
    // Sync Sessions Second (These rely on the users existing in the backend first)
    await _syncGameSessions();
    await _syncMusicSessions();
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

  Future<bool> _post(String path, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      // Returns true if the server accepts the data (200 OK or 201 Created)
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}