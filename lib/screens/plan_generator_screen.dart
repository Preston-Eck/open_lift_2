import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../models/plan.dart';

class PlanGeneratorScreen extends StatefulWidget {
  const PlanGeneratorScreen({super.key});

  @override
  State<PlanGeneratorScreen> createState() => _PlanGeneratorScreenState();
}

class _PlanGeneratorScreenState extends State<PlanGeneratorScreen> {
  final TextEditingController _timeController = TextEditingController(text: "60");
  final TextEditingController _goalController = TextEditingController();
  String _daysPerWeek = "3";
  bool _isLoading = false;
  WorkoutPlan? _generatedPlan;

  /// Main function to gather data and call the AI
  Future<void> _generatePlan() async {
    // 1. Update UI to show loading state
    setState(() {
      _isLoading = true;
      _generatedPlan = null; 
    });

    final db = context.read<DatabaseService>();
    final gemini = context.read<GeminiService>();
    
    try {
      // 2. Fetch User Equipment
      final equipment = await db.getOwnedEquipment();
      if (equipment.isEmpty) {
        // IMPROVED: Guide user instead of crashing
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You need equipment to generate a plan!"))
          );
        }
        return; // Stop execution safely
      }

      // 3. Fetch User Profile (Age, Gender, etc. from Settings)
      final prefs = await SharedPreferences.getInstance();
      final userProfile = {
        'Age': prefs.getString('user_age') ?? 'Unknown',
        'Height': prefs.getString('user_height') ?? 'Unknown',
        'Weight': prefs.getString('user_weight') ?? 'Unknown',
        'Gender': prefs.getString('user_gender') ?? 'Unknown',
        'Fitness Level': prefs.getString('user_fitness_level') ?? 'Intermediate',
      };

      // 4. Fetch Strength Stats (NEW: Get 1RMs from Database)
      final oneRepMaxes = await db.getLatestOneRepMaxes();
      // Format map into readable string: "Bench Press: 200.0, Squat: 315.0"
      final strengthStats = oneRepMaxes.isEmpty 
          ? "No recorded strength data (assume beginner)"
          : oneRepMaxes.entries.map((e) => "${e.key}: ${e.value}lbs").join(", ");

      // 5. Call AI with all the gathered context
      final plan = await gemini.generateFullPlan(
        _goalController.text,
        _daysPerWeek,
        int.tryParse(_timeController.text) ?? 60, // Pass time
        equipment,
        userProfile,
        strengthStats, 
      );
      
      // 6. Update UI with the result
      setState(() {
        _generatedPlan = plan;
      });

    } catch (e) {
      // 7. Handle Errors Gracefully
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Error"),
            content: Text(e.toString()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
            ],
          ),
        );
      }
    } finally {
      // 8. Stop loading spinner regardless of success/failure
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Coach")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Describe your Goal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _goalController,
              decoration: const InputDecoration(
                hintText: "e.g., Build chest muscle, lose weight, train for 5k",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            
            const Text("Days per Week", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _daysPerWeek,
              isExpanded: true,
              items: ['1','2','3','4','5','6','7'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text("$value Days"),
                );
              }).toList(),
              onChanged: (val) => setState(() => _daysPerWeek = val!),
            ),
            const SizedBox(height: 20),
            
            const Text("Time Available (minutes)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: _timeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "60"),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome),
                label: Text(_isLoading ? " Designing Plan..." : "Generate Workout Plan"),
                onPressed: _isLoading ? null : _generatePlan,
              ),
            ),
            
            const Divider(height: 40),

            if (_generatedPlan != null) ...[
              Text("Plan: ${_generatedPlan!.name}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 10),
              ..._generatedPlan!.days.map((day) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  title: Text(day.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: day.exercises.map((ex) => ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(ex.name),
                    subtitle: Text("${ex.sets} sets x ${ex.reps} reps${ex.secondsPerSet > 0 ? ' (${ex.secondsPerSet}s)' : ''}"),
                    trailing: ex.intensity != null ? Chip(label: Text(ex.intensity!)) : null,
                  )).toList(),
                ),
              )),
              
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    if (_generatedPlan != null) {
                      try {
                        await context.read<DatabaseService>().savePlan(_generatedPlan!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Plan Saved Successfully!"))
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Save failed: $e"), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  child: const Text("Save & Activate Plan", style: TextStyle(color: Colors.white)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}