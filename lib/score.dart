import 'database_helper.dart';
import 'sync_service.dart';

class ScoreService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> recordActivity({
    required String userId,
    required int earnedPoints,
  }) async {
    final patients = await _dbHelper.getAllPatients();
    final patient = patients.firstWhere(
      (p) => p['user_id'] == userId,
      orElse: () => {},
    );
    if (patient.isEmpty) {
      throw Exception('Patient with ID $userId not found in database.');
    }

    final String? lastDateStr = patient['last_activity_date'];
    final DateTime now = DateTime.now();
    final String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    int currentStreak = patient['current_streak'] ?? 0;
    int dailyScore = patient['daily_score'] ?? 0;
    int cumulativeScore = patient['cumulative_score'] ?? 0;

    if (lastDateStr == null) {
      currentStreak = 1;
      dailyScore = earnedPoints;
    } else if (lastDateStr == todayStr) {
      dailyScore += earnedPoints;
    } else {
      final DateTime lastDate = DateTime.parse(lastDateStr);
      final DateTime today = DateTime.parse(todayStr);
      final int differenceInDays = today.difference(lastDate).inDays;

      if (differenceInDays == 1) {
        currentStreak += 1;
        dailyScore = earnedPoints;
      } else {
        currentStreak = 1;
        dailyScore = earnedPoints;
      }
    }

    cumulativeScore += earnedPoints;

    await _dbHelper.updatePatientScores(
      userId: userId,
      cumulativeScore: cumulativeScore,
      dailyScore: dailyScore,
      currentStreak: currentStreak,
      lastActivityDate: todayStr,
    );

    SyncService().trySync();
  }
}