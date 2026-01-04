import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../models/plan.dart';

class PlanGeneratorScreen extends StatefulWidget {
  const PlanGeneratorScreen({super.key});

  @override
  State<PlanGeneratorScreen> createState() => _PlanGeneratorScreenState();
}

class _PlanGeneratorScreenState extends State<PlanGeneratorScreen> {
  final TextEditingController _goalController = TextEditingController();
  String _daysPerWeek = "3";
  bool _isLoading = false;
  WorkoutPlan? _generatedPlan;

  Future<void> _generatePlan() async {
    setState(() => _isLoading = true);
    final db = context.read<DatabaseService>();
    final gemini = context.read<GeminiService>();
    
    // 1. Get User Equipment
    final equipment = await db.getOwnedEquipment();
    
    if (equipment.isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please add equipment in the Dashboard first!"))
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // 2. Call AI
    try {
      final plan = await gemini.generateFullPlan(
        _goalController.text.isEmpty ? "General Fitness" : _goalController.text,
        _daysPerWeek,
        equipment,
      );
      
      setState(() {
        _generatedPlan = plan;
      });
    } catch (e) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
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
            // --- Input Section ---
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
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _isLoading ? const SizedBox() : const Icon(Icons.auto_awesome),
                label: Text(_isLoading ? "Asking Coach..." : "Generate Workout Plan"),
                onPressed: _isLoading ? null : _generatePlan,
              ),
            ),
            
            const Divider(height: 40),

            // --- Results Section ---
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
                    subtitle: Text("${ex.sets} sets x ${ex.reps} reps (${ex.restSeconds}s rest)"),
                  )).toList(),
                ),
              )),
              
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    // FIX: Save logic implemented
                    if (_generatedPlan != null) {
                      await context.read<DatabaseService>().savePlan(_generatedPlan!);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Plan Saved Successfully!"))
                        );
                        Navigator.pop(context);
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