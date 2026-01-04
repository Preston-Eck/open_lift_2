class Exercise {
  final String id;
  final String name;
  final String? category;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> equipment;
  final String? level;
  final String? mechanic;
  final List<String> instructions; // Added
  final List<String> images;       // Added

  Exercise({
    required this.id,
    required this.name,
    this.category,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.equipment,
    this.level,
    this.mechanic,
    required this.instructions,
    required this.images,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id']?.toString() ?? json['name'] ?? 'unknown',
      name: json['name'] ?? 'Unnamed Exercise',
      category: json['category'],
      primaryMuscles: List<String>.from(json['primary_muscles'] ?? []),
      secondaryMuscles: List<String>.from(json['secondary_muscles'] ?? []),
      equipment: List<String>.from(json['equipment_required'] ?? []),
      level: json['level'],
      mechanic: json['mechanic'],
      // Map these new fields safely
      instructions: List<String>.from(json['instructions'] ?? []),
      images: List<String>.from(json['images'] ?? []),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'name': name,
      'category': category,
      'primary_muscles': primaryMuscles,
      'secondary_muscles': secondaryMuscles,
      'equipment_required': equipment,
      'level': level,
      'mechanic': mechanic,
      'instructions': instructions,
      'images': images,
    };
  }
}