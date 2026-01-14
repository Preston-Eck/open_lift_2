import '../models/exercise.dart';
import 'database_service.dart';

class AnalyticsService {
  final DatabaseService _db;

  AnalyticsService(this._db);

  /// Generates a normalized map (0.0 to 1.0) of muscle activation volume
  /// based on the user's workout logs from the last 30 days.
  Future<Map<String, double>> generateMuscleHeatmapData(List<Exercise> allExercises) async {
    // 1. Define Timeframe (30 Days)
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    // 2. Fetch Logs
    final logs = await _db.getLogsInDateRange(startDate, endDate);
    if (logs.isEmpty) return {};

    // 3. Tally Muscle Volume
    final Map<String, double> muscleVolumes = {};
    double maxVolume = 0;

    for (var log in logs) {
      final exercise = allExercises.firstWhere(
        (e) => e.name.toLowerCase() == log.exerciseName.toLowerCase(), 
        orElse: () => Exercise(id: '0', name: 'Unknown', primaryMuscles: [], secondaryMuscles: [], equipment: [], instructions: [], images: [])
      );

      final volume = log.volumeLoad; // weight * reps

      for (var muscle in exercise.primaryMuscles) {
        final m = muscle.toLowerCase().trim();
        muscleVolumes[m] = (muscleVolumes[m] ?? 0) + volume;
        
        if (muscleVolumes[m]! > maxVolume) maxVolume = muscleVolumes[m]!;
      }
    }

    // 4. Normalize Data (0.0 - 1.0)
    final Map<String, double> heatMap = {};
    if (maxVolume == 0) return {};

    muscleVolumes.forEach((key, value) {
      heatMap[key] = (value / maxVolume).clamp(0.0, 1.0);
    });

    return heatMap;
  }

  /// Categorizes muscle volumes into 6 major groups for balance analysis.
  Future<Map<String, double>> generateMuscleGroupBalance(List<Exercise> allExercises) async {
    final heatmapData = await generateMuscleHeatmapData(allExercises);
    if (heatmapData.isEmpty) return {};

    final Map<String, double> groups = {
      'Chest': 0,
      'Back': 0,
      'Legs': 0,
      'Shoulders': 0,
      'Arms': 0,
      'Core': 0,
    };

    final mapper = {
      'chest': 'Chest', 'pectorals': 'Chest', 'pecs': 'Chest',
      'back': 'Back', 'lats': 'Back', 'traps': 'Back', 'erectors': 'Back',
      'legs': 'Legs', 'quads': 'Legs', 'hamstrings': 'Legs', 'glutes': 'Legs', 'calves': 'Legs',
      'shoulders': 'Shoulders', 'delts': 'Shoulders', 'deltoids': 'Shoulders',
      'arms': 'Arms', 'biceps': 'Arms', 'triceps': 'Arms', 'forearms': 'Arms',
      'abs': 'Core', 'core': 'Core', 'obliques': 'Core', 'abdominals': 'Core',
    };

    heatmapData.forEach((muscle, intensity) {
      if (mapper.containsKey(muscle)) {
        final group = mapper[muscle]!;
        if (intensity > groups[group]!) groups[group] = intensity;
      }
    });

    return groups;
  }
}