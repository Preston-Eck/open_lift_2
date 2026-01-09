class GymProfile {
  final String id;
  final String name;
  final bool isDefault;
  final List<String> equipmentIds; // IDs of equipment available at this location

  GymProfile({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.equipmentIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory GymProfile.fromMap(Map<String, dynamic> map, {List<String>? equipmentIds}) {
    return GymProfile(
      id: map['id'],
      name: map['name'],
      isDefault: (map['is_default'] as int) == 1,
      equipmentIds: equipmentIds ?? [],
    );
  }
}