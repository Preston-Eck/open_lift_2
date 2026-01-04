// lib/config/equipment_bundles.dart

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

// Define your specific machine here
final List<EquipmentBundle> equipmentBundles = [
  const EquipmentBundle(
    name: "Major Lutie Smith Machine Cage",
    description: "All-in-one rack with cables, smith machine, and landmine.",
    equipmentTags: [
      "Barbell", 
      "Rack", 
      "Smith Machine", 
      "Cable", 
      "Pull-up Bar", 
      "Dip Bar", 
      "Landmine",
      "Bands" // Often used with the pegs on this cage
    ],
  ),
  const EquipmentBundle(
    name: "Basic Home Gym",
    description: "Standard starter set.",
    equipmentTags: [
      "Dumbbell", 
      "Bench", 
      "Bodyweight"
    ],
  ),
];

// A master list of all individual items for manual selection
final List<String> allGenericEquipment = [
  "Barbell", "Dumbbell", "Cable", "Machine", "Kettlebell", 
  "Bodyweight", "Band", "Smith Machine", "Rack", "Pull-up Bar", 
  "Dip Bar", "Landmine", "Bench", "Stability Ball", "Foam Roller"
];