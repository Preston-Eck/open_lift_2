// lib/models/plan.dart
import 'dart:convert'; // Kept for jsonEncode usage below

class WorkoutPlan {
  final String id;
  final String name;
  final String goal;
  final List<WorkoutDay> days;

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.goal,
    required this.days,
  });

  // Convert to Map for Database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'goal': goal,
      // Store complex list as a JSON string for SQLite
      'schedule_json': jsonEncode(days.map((x) => x.toMap()).toList()),
    };
  }

  factory WorkoutPlan.fromMap(Map<String, dynamic> map) {
    return WorkoutPlan(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      goal: map['goal'] ?? '',
      days: map['schedule_json'] != null 
          ? List<WorkoutDay>.from(
              (jsonDecode(map['schedule_json']) as List).map((x) => WorkoutDay.fromMap(x)),
            )
          : [],
    );
  }
  
  // For Gemini parsing (keeps existing logic)
  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      goal: json['goal'] ?? '',
      days: List<WorkoutDay>.from(
        (json['days'] as List).map((x) => WorkoutDay.fromMap(x)),
      ),
    );
  }
}

class WorkoutDay {
  final String name;
  final List<WorkoutExercise> exercises;

  WorkoutDay({required this.name, required this.exercises});

  Map<String, dynamic> toMap() => {
    'name': name,
    'exercises': exercises.map((x) => x.toMap()).toList(),
  };

  factory WorkoutDay.fromMap(Map<String, dynamic> map) {
    return WorkoutDay(
      name: map['name'] ?? 'Workout',
      exercises: List<WorkoutExercise>.from(
        (map['exercises'] as List).map((x) => WorkoutExercise.fromMap(x)),
      ),
    );
  }
}

class WorkoutExercise {
  final String name;
  final int sets;
  final String reps;
  final int restSeconds;

  WorkoutExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'sets': sets,
    'reps': reps,
    'restSeconds': restSeconds,
  };

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      name: map['name'] ?? '',
      sets: map['sets'] ?? 3,
      reps: map['reps']?.toString() ?? '10',
      restSeconds: map['restSeconds'] ?? 60,
    );
  }
}