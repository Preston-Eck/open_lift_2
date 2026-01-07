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
  
  Map<String, int> _auditStats = {};
  List<String> _allCapabilities = [];
  List<String> _existingNames = [];

  @override
  void initState() {
    super.initState();
    // Safety: Ensure build is complete before running logic
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _runAudit();
    });
  }

  Future<void> _runAudit() async {
    if (!mounted) return;
    
    final db = context.read<DatabaseService>();
    final capabilities = await db.getOwnedEquipment();
    final customExercises = await db.getCustomExercises();
    
    final uniqueTags = capabilities.toSet().toList();
    uniqueTags.sort(); 
    
    Map<String, int> stats = {};
    List<String> names = customExercises.map((e) => e.name).toList();

    for (var tag in uniqueTags) {
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

  Future<void> _generateForTag(String tag) async {
    setState(() => _isLoading = true);
    final gemini = context.read<GeminiService>();
    final db = context.read<DatabaseService>();

    try {
      final suggestions = await gemini.suggestMissingExercises(tag, _existingNames);
      
      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text("Suggested for $tag"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: suggestions.isEmpty 
              ? const Center(child: Text("No suggestions found."))
              : ListView.separated( // Safe inside Dialog
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final ex = suggestions[i];
                    return ListTile(
                      title: Text(ex['name'] ?? "Unknown"),
                      subtitle: Text((ex['primary_muscles'] as List? ?? []).join(', ')),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () async {
                          final newEx = Exercise(
                            id: const Uuid().v4(),
                            name: ex['name'],
                            category: "Strength", 
                            primaryMuscles: List<String>.from(ex['primary_muscles'] ?? []),
                            secondaryMuscles: [],
                            equipment: [tag],
                            instructions: List<String>.from(ex['instructions'] ?? []),
                            images: [],
                          );
                          
                          await db.addCustomExercise(newEx);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Added ${newEx.name}!")));
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text("Close")
            )
          ],
        ),
      );

      if (mounted) _runAudit();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Exercise Database Auditor")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : CustomScrollView( // ✅ SLIVERS: More robust for dynamic lists on Windows
            slivers: [
              // 1. Header Area
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: const Card(
                    color: Colors.blueGrey,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text(
                        "This tool compares your Inventory vs. Database. Tap to generate missing exercises.",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Empty State Handling
              if (_allCapabilities.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text("No equipment capabilities found.\nGo to 'Manage' to add gear.")),
                  ),
                ),

              // 3. The List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tag = _allCapabilities[index];
                      final count = _auditStats[tag] ?? 0;
                      final isLow = count == 0;

                      return Card(
                        key: ValueKey(tag), // ✅ KEY: Helps Flutter track updates safely
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
                              // Ensure button doesn't cause layout overflow
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              minimumSize: Size.zero, 
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _generateForTag(tag),
                          ),
                        ),
                      );
                    },
                    childCount: _allCapabilities.length,
                  ),
                ),
              ),
              
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
    );
  }
}