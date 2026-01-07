import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../models/exercise.dart';

class ExerciseAuditorScreen extends StatefulWidget {
  const ExerciseAuditorScreen({super.key});

  @override
  State<ExerciseAuditorScreen> createState() => _ExerciseAuditorScreenState();
}

class _ExerciseAuditorScreenState extends State<ExerciseAuditorScreen> {
  bool _isLoading = true;
  
  // Data
  Map<String, int> _auditStats = {};
  List<String> _allCapabilities = [];
  List<String> _existingNames = [];

  @override
  void initState() {
    super.initState();
    // Schedule audit for after the first frame to avoid build conflicts
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _runAudit();
    });
  }

  Future<void> _runAudit() async {
    if (!mounted) return;
    
    final db = context.read<DatabaseService>();
    
    // 1. Fetch Data
    final capabilities = await db.getOwnedEquipment();
    final customExercises = await db.getCustomExercises();
    
    // 2. Process Data (Flatten capabilities)
    final uniqueTags = capabilities.toSet().toList();
    uniqueTags.sort(); // Sort alphabetically
    
    Map<String, int> stats = {};
    List<String> names = customExercises.map((e) => e.name).toList();

    for (var tag in uniqueTags) {
      // Loose check: does any exercise equipment list contain this tag?
      int count = customExercises.where((e) => 
        e.equipment.any((eq) => eq.toLowerCase().contains(tag.toLowerCase()))
      ).length;
      stats[tag] = count;
    }

    if (mounted) {
      setState(() {
        _allCapabilities = uniqueTags;
        _auditStats = stats;
        _existingNames = names;
        _isLoading = false;
      });
    }
  }

  // ✅ FIXED: Syntax error corrected here
  Future<void> _generateForTag(String tag) async {
    setState(() => _isLoading = true);
    final gemini = context.read<GeminiService>();
    final db = context.read<DatabaseService>();

    try {
      // Pass full inventory to prevent hallucinations
      final suggestions = await gemini.suggestMissingExercises(
        tag, 
        _existingNames,
        _allCapabilities
      );
      
      if (!mounted) return;

      // Local state for the dialog checkboxes
      final Set<String> selectedExercises = {};
      // Auto-select all by default
      for (var ex in suggestions) {
        selectedExercises.add(ex['name']); 
      }

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder( 
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text("Suggested for $tag"),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: suggestions.isEmpty 
                    ? const Center(child: Text("No suggestions found."))
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              "Select exercises to add (${selectedExercises.length}/${suggestions.length})",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              itemCount: suggestions.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final ex = suggestions[i];
                                final name = ex['name'];
                                final isSelected = selectedExercises.contains(name);
                                
                                return CheckboxListTile(
                                  title: Text(name),
                                  subtitle: Text((ex['primary_muscles'] as List).join(', ')),
                                  value: isSelected,
                                  activeColor: Colors.deepPurple,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedExercises.add(name);
                                      } else {
                                        selectedExercises.remove(name);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx), 
                    child: const Text("Cancel")
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: selectedExercises.isEmpty ? null : () async {
                      // Batch Save
                      int addedCount = 0;
                      for (var exData in suggestions) {
                        if (selectedExercises.contains(exData['name'])) {
                          final newEx = Exercise(
                            id: const Uuid().v4(),
                            name: exData['name'],
                            category: "Strength", 
                            primaryMuscles: List<String>.from(exData['primary_muscles']),
                            secondaryMuscles: [],
                            equipment: [tag], 
                            instructions: List<String>.from(exData['instructions'] ?? []),
                            images: [],
                          );
                          await db.addCustomExercise(newEx);
                          addedCount++;
                        }
                      }
                      
                      // ✅ FIXED: Safe context usage across async gap
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added $addedCount exercises!")));
                      }
                    },
                    child: Text("Add Selected (${selectedExercises.length})"),
                  )
                ],
              );
            },
          );
        },
      );

      if (mounted) _runAudit(); 

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Exercise Database Auditor")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView( 
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. Header Area
                const Card(
                  color: Colors.blueGrey,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text(
                      "This tool compares your Inventory vs. Database. Tap to generate missing exercises.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Empty State Handling
                if (_allCapabilities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text("No equipment capabilities found.\nGo to 'Manage' to add gear.")),
                  ),

                // 3. The List Items (Mapped to Column children)
                ..._allCapabilities.map((tag) {
                  final count = _auditStats[tag] ?? 0;
                  final isLow = count == 0;

                  return Card(
                    key: ValueKey(tag),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        isLow ? Icons.warning_amber : Icons.check_circle,
                        color: isLow ? Colors.orange : Colors.green
                      ),
                      title: Text(tag, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("$count exercises found"),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: Text(isLow ? "Fill Gap" : "Add More"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero, 
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _generateForTag(tag),
                      ),
                    ),
                  );
                }),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }
}