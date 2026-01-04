import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/plan.dart';
import '../services/database_service.dart';

class ManualPlanCreatorScreen extends StatefulWidget {
  const ManualPlanCreatorScreen({super.key});

  @override
  State<ManualPlanCreatorScreen> createState() => _ManualPlanCreatorScreenState();
}

class _ManualPlanCreatorScreenState extends State<ManualPlanCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  
  // FIX: Made this final as the list reference doesn't change, only its contents
  final List<WorkoutDay> _days = [];

  void _addDay() {
    setState(() {
      _days.add(WorkoutDay(name: "Day ${_days.length + 1}", exercises: []));
    });
  }

  void _removeDay(int index) {
    setState(() {
      _days.removeAt(index);
    });
  }

  void _editDayName(int index, String newName) {
    setState(() {
      // Recreate the day object since its fields are final
      _days[index] = WorkoutDay(name: newName, exercises: _days[index].exercises);
    });
  }

  void _addExercise(int dayIndex) {
    showDialog(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final setsCtrl = TextEditingController(text: "3");
        final repsCtrl = TextEditingController(text: "10");
        final restCtrl = TextEditingController(text: "60");

        return AlertDialog(
          title: const Text("Add Exercise"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Exercise Name (e.g. Bench Press)")),
                Row(
                  children: [
                    Expanded(child: TextField(controller: setsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Sets"))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: repsCtrl, decoration: const InputDecoration(labelText: "Reps (e.g. 8-12)"))),
                  ],
                ),
                TextField(controller: restCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Rest (seconds)")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() {
                    _days[dayIndex].exercises.add(WorkoutExercise(
                      name: nameCtrl.text,
                      sets: int.tryParse(setsCtrl.text) ?? 3,
                      reps: repsCtrl.text,
                      restSeconds: int.tryParse(restCtrl.text) ?? 60,
                    ));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one day.")));
      return;
    }

    final plan = WorkoutPlan(
      id: const Uuid().v4(),
      name: _nameController.text,
      goal: _goalController.text,
      days: _days,
    );

    await context.read<DatabaseService>().savePlan(plan);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan Saved Successfully!")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Custom Plan"),
        actions: [
          IconButton(onPressed: _savePlan, icon: const Icon(Icons.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Plan Name", border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _goalController,
              decoration: const InputDecoration(labelText: "Goal (Optional)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            const Text("Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            ..._days.asMap().entries.map((entry) {
              final i = entry.key;
              final day = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: TextFormField(
                    initialValue: day.name,
                    decoration: const InputDecoration(border: InputBorder.none),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    onChanged: (val) => _editDayName(i, val),
                  ),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeDay(i)),
                  children: [
                    if (day.exercises.isEmpty)
                      const Padding(padding: EdgeInsets.all(16), child: Text("No exercises yet.")),
                    
                    ...day.exercises.asMap().entries.map((exEntry) => ListTile(
                      dense: true,
                      leading: CircleAvatar(child: Text("${exEntry.key + 1}")),
                      title: Text(exEntry.value.name),
                      subtitle: Text("${exEntry.value.sets} sets x ${exEntry.value.reps} reps"),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() {
                            day.exercises.removeAt(exEntry.key);
                          });
                        },
                      ),
                    )),

                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add Exercise"),
                        onPressed: () => _addExercise(i),
                      ),
                    )
                  ],
                ),
              );
            }),

            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _addDay,
              icon: const Icon(Icons.calendar_today),
              label: const Text("Add Workout Day"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}