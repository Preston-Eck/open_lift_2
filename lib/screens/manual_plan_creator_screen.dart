import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/plan.dart';
import '../services/database_service.dart';
import '../widgets/exercise_selection_dialog.dart'; // Import the new widget

class ManualPlanCreatorScreen extends StatefulWidget {
  final WorkoutPlan? planToEdit;

  const ManualPlanCreatorScreen({super.key, this.planToEdit});

  @override
  State<ManualPlanCreatorScreen> createState() => _ManualPlanCreatorScreenState();
}

class _ManualPlanCreatorScreenState extends State<ManualPlanCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _goalController;
  final List<WorkoutDay> _days = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.planToEdit?.name ?? '');
    _goalController = TextEditingController(text: widget.planToEdit?.goal ?? '');
    
    if (widget.planToEdit != null) {
      for (var day in widget.planToEdit!.days) {
        _days.add(WorkoutDay(
          name: day.name, 
          exercises: List.from(day.exercises)
        ));
      }
    }
  }

  void _addDay() {
    setState(() {
      _days.add(WorkoutDay(name: "Day ${_days.length + 1}", exercises: []));
    });
  }

  void _removeDay(int index) {
    setState(() => _days.removeAt(index));
  }

  void _editDayName(int index, String newName) {
    setState(() {
      _days[index] = WorkoutDay(name: newName, exercises: _days[index].exercises);
    });
  }

  Future<void> _addExercise(int dayIndex) async {
    // Step 1: Pick the Exercise using the shared dialog
    final String? selectedName = await showDialog<String>(
      context: context,
      builder: (ctx) => const ExerciseSelectionDialog(),
    );

    if (selectedName == null || !mounted) return;

    // Step 2: Configure Sets/Reps
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        final setsCtrl = TextEditingController(text: "3");
        final repsCtrl = TextEditingController(text: "10");
        final restCtrl = TextEditingController(text: "60");
        final timeCtrl = TextEditingController(text: "0");

        return AlertDialog(
          title: Text(selectedName),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: setsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Sets"))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: repsCtrl, decoration: const InputDecoration(labelText: "Reps"))),
                  ],
                ),
                TextField(controller: restCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Rest (sec)")),
                TextField(
                  controller: timeCtrl, 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: "Duration (sec) - 0 if not timed", hintText: "e.g. 60")
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _days[dayIndex].exercises.add(WorkoutExercise(
                    name: selectedName,
                    sets: int.tryParse(setsCtrl.text) ?? 3,
                    reps: repsCtrl.text,
                    restSeconds: int.tryParse(restCtrl.text) ?? 60,
                    secondsPerSet: int.tryParse(timeCtrl.text) ?? 0,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text("Add to Day"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add a day first.")));
      return;
    }

    final plan = WorkoutPlan(
      id: widget.planToEdit?.id ?? const Uuid().v4(),
      name: _nameController.text,
      goal: _goalController.text,
      days: _days,
    );

    await context.read<DatabaseService>().savePlan(plan);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!")));
      Navigator.pop(context); 
      if (widget.planToEdit != null) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.planToEdit == null ? "Create Plan" : "Edit Plan"),
        actions: [IconButton(onPressed: _savePlan, icon: const Icon(Icons.save))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Plan Name", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Required" : null),
            const SizedBox(height: 10),
            TextFormField(controller: _goalController, decoration: const InputDecoration(labelText: "Goal", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            
            ..._days.asMap().entries.map((entry) {
              final i = entry.key;
              final day = entry.value;
              return Card(
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: TextFormField(initialValue: day.name, onChanged: (val) => _editDayName(i, val)),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeDay(i)),
                  children: [
                    ...day.exercises.asMap().entries.map((ex) => ListTile(
                      title: Text(ex.value.name),
                      subtitle: Text("${ex.value.sets}x${ex.value.reps} ${ex.value.secondsPerSet > 0 ? '(${ex.value.secondsPerSet}s)' : ''}"),
                      trailing: IconButton(icon: const Icon(Icons.remove_circle), onPressed: () => setState(() => day.exercises.removeAt(ex.key))),
                    )),
                    TextButton(onPressed: () => _addExercise(i), child: const Text("Add Exercise"))
                  ],
                ),
              );
            }),
            ElevatedButton(onPressed: _addDay, child: const Text("Add Day")),
          ],
        ),
      ),
    );
  }
}