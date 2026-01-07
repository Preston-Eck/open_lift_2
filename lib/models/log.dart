class LogEntry {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final double weight;
  final int reps;
  final double volumeLoad;
  final int duration;
  final String timestamp;
  final String? sessionId; // NEW: Links this set to a WorkoutSession

  LogEntry({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.volumeLoad,
    this.duration = 0,
    required this.timestamp,
    this.sessionId, // Nullable for backward compatibility
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'weight': weight,
      'reps': reps,
      'volume_load': volumeLoad,
      'duration': duration,
      'timestamp': timestamp,
      'session_id': sessionId, // NEW column
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'],
      exerciseId: map['exercise_id'],
      exerciseName: map['exercise_name'],
      weight: map['weight'],
      reps: map['reps'],
      volumeLoad: map['volume_load'],
      duration: map['duration'] ?? 0,
      timestamp: map['timestamp'],
      sessionId: map['session_id'], // Handle older null records gracefully
    );
  }
}