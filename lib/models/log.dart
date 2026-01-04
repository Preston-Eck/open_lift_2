class LogEntry {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final double weight;
  final int reps;
  final double volumeLoad;
  final String timestamp;

  LogEntry({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.volumeLoad,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'weight': weight,
      'reps': reps,
      'volume_load': volumeLoad,
      'timestamp': timestamp,
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
      timestamp: map['timestamp'],
    );
  }
}