import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../screens/add_exercise_screen.dart';

class ExerciseSelectionDialog extends StatefulWidget {
  const ExerciseSelectionDialog({super.key});

  @override
  State<ExerciseSelectionDialog> createState() => _ExerciseSelectionDialogState();
}

class _ExerciseSelectionDialogState extends State<ExerciseSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedMuscle = "All";
  String _selectedEquipment = "All";
  
  List<String> _results = [];
  bool _isLoading = false;

  final List<String> _muscles = ["All", "Chest", "Back", "Legs", "Shoulders", "Arms", "Abs", "Cardio"];
  final List<String> _equipment = ["All", "Barbell", "Dumbbell", "Machine", "Cable", "Bodyweight", "Band", "Kettlebell"];

  @override
  void initState() {
    super.initState();
    _performSearch();
    _searchController.addListener(_performSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_performSearch);
    _searchController.dispose();
    super.dispose();
  }

  // Helper for local fuzzy match (removes spaces/hyphens)
  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    final rawQuery = _searchController.text.trim();
    final db = context.read<DatabaseService>();
    final supabase = Supabase.instance.client;

    try {
      // 1. Local Search
      var localExercises = await db.getCustomExercises();
      
      // Filter Local
      if (_selectedMuscle != "All") {
        localExercises = localExercises.where((e) => e.primaryMuscles.any((m) => m.toLowerCase().contains(_selectedMuscle.toLowerCase()))).toList();
      }
      if (_selectedEquipment != "All") {
        localExercises = localExercises.where((e) => e.equipment.any((eq) => eq.toLowerCase().contains(_selectedEquipment.toLowerCase()))).toList();
      }
      
      if (rawQuery.isNotEmpty) {
        final normalizedQuery = _normalize(rawQuery);
        localExercises = localExercises.where((e) {
          return _normalize(e.name).contains(normalizedQuery);
        }).toList();
      }

      final List<String> matches = localExercises.map((e) => e.name).toList();

      // 2. Remote Search (Supabase)
      var dbQuery = supabase.from('exercises').select('name, primary_muscles, equipment_required');
      
      if (rawQuery.isNotEmpty) {
        // Fuzzy Match: Replace space/hyphen with % wildcard
        // "Sit Ups" -> "Sit%Ups" matches "Sit-Ups"
        final fuzzyQuery = rawQuery.replaceAll(RegExp(r'[\s\-]'), '%');
        dbQuery = dbQuery.ilike('name', '%$fuzzyQuery%');
      }
      if (_selectedMuscle != "All") {
        dbQuery = dbQuery.contains('primary_muscles', [_selectedMuscle]);
      }
      if (_selectedEquipment != "All") {
        dbQuery = dbQuery.contains('equipment_required', [_selectedEquipment]);
      }

      final remoteData = await dbQuery.limit(20);
      final remoteMatches = (remoteData as List).map((e) => e['name'] as String).toList();

      // Merge & Dedup
      final combined = {...matches, ...remoteMatches}.toList();
      combined.sort();

      if (mounted) {
        setState(() {
          _results = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Search Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Select Exercise"),
      // Use max width to solve "too compact" issue
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filters
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "Muscle", contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMuscle,
                        isExpanded: true,
                        items: _muscles.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) {
                          setState(() => _selectedMuscle = val!);
                          _performSearch();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                     decoration: const InputDecoration(labelText: "Equipment", contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                     child: DropdownButtonHideUnderline(
                       child: DropdownButton<String>(
                        value: _selectedEquipment,
                        isExpanded: true,
                        items: _equipment.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) {
                          setState(() => _selectedEquipment = val!);
                          _performSearch();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Search name (e.g. Sit Ups)...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Results List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("No exercises found."),
                              TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text("Create New"),
                                onPressed: () async {
                                  Navigator.pop(context); // Close dialog
                                  // Navigate to Add Screen
                                  await Navigator.push(
                                    context, 
                                    MaterialPageRoute(builder: (_) => const AddExerciseScreen())
                                  );
                                },
                              )
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final name = _results[i];
                            return ListTile(
                              dense: true,
                              title: Text(name),
                              onTap: () => Navigator.pop(context, name),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text("Cancel")
        ),
      ],
    );
  }
}