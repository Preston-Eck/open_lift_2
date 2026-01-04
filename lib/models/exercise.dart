class Exercise {
  final String id;
  final String name;
  final String? category;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> equipment; // Stored as array in DB
  final String? level;
  final String? mechanic;

  Exercise({
    required this.id,
    required this.name,
    this.category,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.equipment,
    this.level,
    this.mechanic,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      // Fallback to 'name' if 'id' is missing (common in some JSON lists)
      id: json['id']?.toString() ?? json['name'] ?? 'unknown',
      name: json['name'] ?? 'Unnamed Exercise',
      category: json['category'],
      // Handle Postgres Arrays (text[]) which come back as Lists
      primaryMuscles: List<String>.from(json['primary_muscles'] ?? []),
      secondaryMuscles: List<String>.from(json['secondary_muscles'] ?? []),
      // The import script saves equipment as an array 'equipment_required'
      equipment: List<String>.from(json['equipment_required'] ?? []),
      level: json['level'],
      mechanic: json['mechanic'],
    );
  }

  // Helper for uploading data if needed from the app
  Map<String, dynamic> toSupabaseMap() {
    return {
      'name': name,
      'category': category,
      'primary_muscles': primaryMuscles,
      'secondary_muscles': secondaryMuscles,
      'equipment_required': equipment,
      'level': level,
      'mechanic': mechanic,
    };
  }
}