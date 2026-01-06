import '../models/exercise.dart';
import 'database_service.dart';

class AnalyticsService {
  final DatabaseService _db;

  AnalyticsService(this._db);

  /// Generates a normalized map (0.0 to 1.0) of muscle activation frequency
  /// based on the user's workout logs from the last 90 days.
  Future<Map<String, double>> generateMuscleHeatmapData(List<Exercise> allExercises) async {
    // 1. Define Timeframe (Quarterly Heatmap)
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 90));

    // 2. Fetch Logs
    final logs = await _db.getLogsInDateRange(startDate, endDate);
    if (logs.isEmpty) return {};

    // 3. Tally Muscle Counts
    final Map<String, int> muscleCounts = {};
    int maxCount = 0;

    for (var log in logs) {
      // Resolve Exercise Definition
      // In a real app, optimize this lookup (e.g., convert list to map first)
      final exercise = allExercises.firstWhere(
        (e) => e.name.toLowerCase() == log.exerciseName.toLowerCase(), 
        orElse: () => Exercise(id: '0', name: 'Unknown', primaryMuscles: [], secondaryMuscles: [], equipment: [], instructions: [], images: [])
      );

      // Score Primary Muscles
      for (var muscle in exercise.primaryMuscles) {
        final m = muscle.toLowerCase();
        muscleCounts[m] = (muscleCounts[m] ?? 0) + 1;
        
        // Track the highest count to normalize data later
        if (muscleCounts[m]! > maxCount) maxCount = muscleCounts[m]!;
      }
    }

    // 4. Normalize Data (0.0 - 1.0)
    final Map<String, double> heatMap = {};
    if (maxCount == 0) return {};

    muscleCounts.forEach((key, value) {
      // Normalize: value / maxCount
      // Example: If Chest has 10 sets and max is 10, intensity is 1.0 (Dark Red)
      heatMap[key] = (value / maxCount).clamp(0.0, 1.0);
    });

    return heatMap;
  }
}