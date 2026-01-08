class EquipmentBundle {
  final String name;
  final String description;
  final List<String> equipmentTags;

  const EquipmentBundle({
    required this.name,
    required this.description,
    required this.equipmentTags,
  });
}

// Pre-defined complex equipment
final List<EquipmentBundle> equipmentBundles = [
  const EquipmentBundle(
    name: "Power Rack Setup",
    description: "Cage with barbell, pull-up bar, and safeties.",
    equipmentTags: ["Barbell", "Rack", "Pull-up Bar", "Bench"],
  ),
  const EquipmentBundle(
    name: "Functional Trainer",
    description: "Dual cable stack machine.",
    equipmentTags: ["Cable", "Pull-up Bar"],
  ),
  const EquipmentBundle(
    name: "Smith Machine Combo",
    description: "Smith machine with attached cables/pegs.",
    equipmentTags: ["Smith Machine", "Cable", "Pull-up Bar"],
  ),
  const EquipmentBundle(
    name: "Basic Home Gym",
    description: "Dumbbells and a bench.",
    equipmentTags: ["Dumbbell", "Bench", "Bodyweight"],
  ),
];

// MASTER LIST: All individual items used by the AI
final List<String> allGenericEquipment = [
  "Barbell",
  "Dumbbell",
  "Kettlebell",
  "Cable",
  "Machine",
  "Smith Machine",
  "Band",
  "Bodyweight",
  "Bench",
  "Pull-up Bar",
  "Dip Station",
  "Landmine",
  "EZ Bar",
  "Trap Bar",
  "Sled",
  "Medicine Ball",
  "Stability Ball",
  "Foam Roller",
  "Rack", 
  "Plate",
  "Box", 
  "Chain"
];