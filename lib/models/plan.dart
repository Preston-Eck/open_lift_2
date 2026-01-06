import 'dart:convert'; 

class WorkoutPlan {
  final String id;
  final String name;
  final String goal;
  final String type; // NEW: 'Strength' or 'HIIT'
  final List<WorkoutDay> days;

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.goal,
    this.type = 'Strength', // Default
    required this.days,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'goal': goal,
      'type': type, // Save to DB
      'schedule_json': jsonEncode(days.map((x) => x.toMap()).toList()),
    };
  }

  factory WorkoutPlan.fromMap(Map<String, dynamic> map) {
    return WorkoutPlan(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      goal: map['goal'] ?? '',
      type: map['type'] ?? 'Strength', // Load from DB
      days: map['schedule_json'] != null 
          ? List<WorkoutDay>.from(
              (jsonDecode(map['schedule_json']) as List).map((x) => WorkoutDay.fromMap(x)),
            )
          : [],
    );
  }
  
  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      goal: json['goal'] ?? '',
      type: json['type'] ?? 'Strength',
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
  final String? intensity;
  final int secondsPerSet;

  WorkoutExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.intensity,
    this.secondsPerSet = 0,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'sets': sets,
    'reps': reps,
    'restSeconds': restSeconds,
    'intensity': intensity,
    'secondsPerSet': secondsPerSet,
  };

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      name: map['name'] ?? '',
      sets: map['sets'] ?? 3,
      reps: map['reps']?.toString() ?? '10',
      restSeconds: map['restSeconds'] ?? 60,
      intensity: map['intensity'],
      secondsPerSet: map['secondsPerSet'] ?? 0,
    );
  }
}