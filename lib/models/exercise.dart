class Exercise {
  final String id;
  final String name;
  final String? force;
  final String? level;
  final String? mechanic;
  final String? equipment;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final String? category;
  final List<String> images;

  Exercise({
    required this.id,
    required this.name,
    this.force,
    this.level,
    this.mechanic,
    this.equipment,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.instructions,
    this.category,
    required this.images,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] ?? json['name'], // Fallback if ID is missing
      name: json['name'],
      force: json['force'],
      level: json['level'],
      mechanic: json['mechanic'],
      equipment: json['equipment'],
      primaryMuscles: List<String>.from(json['primaryMuscles'] ?? []),
      secondaryMuscles: List<String>.from(json['secondaryMuscles'] ?? []),
      instructions: List<String>.from(json['instructions'] ?? []),
      category: json['category'],
      images: List<String>.from(json['images'] ?? []),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'name': name,
      'force': force,
      'level': level,
      'mechanic': mechanic,
      'equipment_required': equipment != null ? [equipment] : [], // Adapter for array
      'primary_muscles': primaryMuscles,
      'secondary_muscles': secondaryMuscles,
      'instructions': instructions,
      'category': category,
      'images': images,
    };
  }
}