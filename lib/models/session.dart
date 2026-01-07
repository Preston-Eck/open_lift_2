/// Represents a completed or active workout session.
/// Acts as a container for logs, linking them to a specific Plan and Day.
class WorkoutSession {
  final String id;
  final String planId;      // Links back to the WorkoutPlan
  final String dayName;     // e.g., "Day 1 - Upper Power"
  final DateTime startTime;
  final DateTime? endTime;  // Null if currently active
  final String? note;       // User notes for the session

  WorkoutSession({
    required this.id,
    required this.planId,
    required this.dayName,
    required this.startTime,
    this.endTime,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plan_id': planId,
      'day_name': dayName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'note': note,
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'],
      planId: map['plan_id'],
      dayName: map['day_name'],
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      note: map['note'],
    );
  }
}