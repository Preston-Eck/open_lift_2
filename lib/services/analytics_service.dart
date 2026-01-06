import 'package:flutter/material.dart';
import '../models/log.dart';
import '../models/exercise.dart';
import 'database_service.dart';

class AnalyticsService {
  final DatabaseService _db;

  AnalyticsService(this._db);

  // Generates the 0.0 - 1.0 intensity map for muscles
  Future<Map<String, double>> generateMuscleHeatmapData(List<Exercise> allExercises) async {
    // 1. Get logs from last 90 days (Quarterly heat map)
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 90));
    final logs = await _db.getLogsInDateRange(startDate, endDate);

    if (logs.isEmpty) return {};

    // 2. Tally muscle frequency
    // Map<MuscleID, SetCount>
    final Map<String, int> muscleCounts = {};
    int maxCount = 0;

    for (var log in logs) {
      // Find the exercise definition to get its muscles
      // This is a simple lookup. In a real app with 1000s of logs, cache this map.
      final exercise = allExercises.firstWhere(
        (e) => e.name == log.exerciseName, 
        orElse: () => Exercise(id: '0', name: 'Unknown', primaryMuscles: [], secondaryMuscles: [], equipment: [], instructions: [], images: [])
      );

      for (var muscle in exercise.primaryMuscles) {
        final m = muscle.toLowerCase();
        muscleCounts[m] = (muscleCounts[m] ?? 0) + 1; // Primary counts as 1 point
        if (muscleCounts[m]! > maxCount) maxCount = muscleCounts[m]!;
      }
      
      // Optional: Secondary muscles count as 0.5 points? 
      // Keeping it simple for now (1 point).
    }

    // 3. Normalize to 0.0 - 1.0 for Opacity
    final Map<String, double> heatMap = {};
    if (maxCount == 0) return {};

    muscleCounts.forEach((key, value) {
      heatMap[key] = (value / maxCount).clamp(0.0, 1.0);
    });

    return heatMap;
  }
}