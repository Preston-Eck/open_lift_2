import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
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

  Future<void> _generatePlan() async {
    setState(() {
      _isLoading = true;
      _generatedPlan = null; 
    });

    final db = context.read<DatabaseService>();
    final gemini = context.read<GeminiService>();
    
    try {
      // 1. Fetch Local Data (Equipment)
      final equipment = await db.getOwnedEquipment();
      if (equipment.isEmpty) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You need equipment to generate a plan! Go to Manage Equipment."))
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 2. Fetch User Profile (Database)
      final profileData = await db.getUserProfile();
      
      // FIX: Explicitly convert dynamic DB values to Strings for the AI Service
      final Map<String, String> userProfile = {
        'Age': profileData?['birth_date']?.toString() ?? 'Unknown',
        'Height': profileData?['height']?.toString() ?? 'Unknown',
        'Weight': profileData?['current_weight']?.toString() ?? 'Unknown',
        'Gender': profileData?['gender']?.toString() ?? 'Unknown',
        'Fitness Level': profileData?['fitness_level']?.toString() ?? 'Intermediate',
      };

      // 3. Fetch Strength Stats (1RMs)
      final oneRepMaxes = await db.getLatestOneRepMaxes();
      final strengthStats = oneRepMaxes.isEmpty 
          ? "No recorded strength data (assume beginner)"
          : oneRepMaxes.entries.map((e) => "${e.key}: ${e.value.toInt()}lbs").join(", ");

      // 4. Fetch Wiki Vocabulary (RAG)
      List<String> validExercises = [];
      try {
        final response = await Supabase.instance.client
            .from('exercises')
            .select('name')
            .limit(100); 
        validExercises = (response as List).map((e) => e['name'] as String).toList();
      } catch (e) {
        debugPrint("Supabase Fetch Error (Offline?): $e");
      }

      // 5. Call AI
      final plan = await gemini.generateFullPlan(
        _goalController.text,
        _daysPerWeek,
        int.tryParse(_timeController.text) ?? 60,
        equipment,
        userProfile,
        strengthStats, 
        validExercises, 
      );
      
      setState(() {
        _generatedPlan = plan;
      });

    } catch (e) {
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
                hintText: "e.g., Build chest muscle, lose weight, HIIT cardio",
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
              Text("Type: ${_generatedPlan!.type}", style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 10),
              ..._generatedPlan!.days.map((day) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  title: Text(day.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: day.exercises.map((ex) => ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(ex.name),
                    subtitle: Text("${ex.sets} sets x ${ex.reps} ${ex.secondsPerSet > 0 ? '(${ex.secondsPerSet}s)' : ''}"),
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