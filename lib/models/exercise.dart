class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final List<String> equipment;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'],
      muscleGroup: json['muscle_group'] ?? 'General',
      equipment: List<String>.from(json['equipment_required'] ?? []),
    );
  }
}