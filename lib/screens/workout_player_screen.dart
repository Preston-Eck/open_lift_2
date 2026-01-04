import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/workout_player_service.dart';
import '../services/database_service.dart'; 
import '../models/log.dart'; 
import '../models/plan.dart'; 

class WorkoutPlayerScreen extends StatelessWidget {
  final WorkoutDay? workoutDay;

  const WorkoutPlayerScreen({super.key, this.workoutDay});

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<WorkoutPlayerService>(context);
    
    // Fallback if no day is passed
    final exercises = workoutDay?.exercises ?? [
      WorkoutExercise(name: "Freestyle Workout", sets: 1, reps: "0", restSeconds: 60)
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(workoutDay?.name ?? "Active Workout"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            player.finishWorkout();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // --- Timer Header ---
          Container(
            padding: const EdgeInsets.all(24),
            color: player.state == WorkoutState.resting 
              ? Colors.red.withValues(alpha: 0.2) 
              : Colors.transparent,
            child: Center(
              child: Text(
                player.state == WorkoutState.resting 
                  ? "REST: ${player.timerSeconds}s" 
                  : "WORKING",
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          // --- Exercise List ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final ex = exercises[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ex.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    // Generate rows based on the plan's set count
                    ...List.generate(ex.sets, (setIndex) => 
                      _ExerciseSetRow(
                        exercise: ex, 
                        setNumber: setIndex + 1
                      )
                    ),
                    const Divider(height: 30),
                  ],
                );
              },
            ),
          ),
          
          // --- Finish Button ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                player.finishWorkout();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.flag),
              label: const Text("Finish Workout"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Stateful Widget for Individual Sets ---
class _ExerciseSetRow extends StatefulWidget {
  final WorkoutExercise exercise;
  final int setNumber;

  const _ExerciseSetRow({required this.exercise, required this.setNumber});

  @override
  State<_ExerciseSetRow> createState() => _ExerciseSetRowState();
}

class _ExerciseSetRowState extends State<_ExerciseSetRow> {
  bool _isCompleted = false;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (int.tryParse(widget.exercise.reps) != null) {
      _repsController.text = widget.exercise.reps;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _isCompleted ? Colors.green.withValues(alpha: 0.1) : null,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // Set Number
            CircleAvatar(
              radius: 16,
              backgroundColor: _isCompleted ? Colors.green : Colors.grey,
              child: Text(
                "${widget.setNumber}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 16),
            
            // Weight Input (Changed to lbs)
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                enabled: !_isCompleted,
                decoration: const InputDecoration(
                  labelText: "Weight (lbs)", // <--- UPDATED HERE
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Reps Input
            Expanded(
              child: TextField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                enabled: !_isCompleted,
                decoration: InputDecoration(
                  labelText: "Reps",
                  hintText: widget.exercise.reps, 
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Checkbox logic
            Checkbox(
              value: _isCompleted,
              onChanged: (val) {
                if (val == true) {
                  _logSet(context);
                } else {
                  setState(() => _isCompleted = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _logSet(BuildContext context) {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final reps = int.tryParse(_repsController.text) ?? 0;

    if (reps == 0 && weight == 0) return; 

    // 1. Log to Database
    final db = Provider.of<DatabaseService>(context, listen: false);
    db.logSet(LogEntry(
      id: DateTime.now().toIso8601String(),
      exerciseId: widget.exercise.name, 
      exerciseName: widget.exercise.name,
      weight: weight,
      reps: reps,
      volumeLoad: weight * reps,
      timestamp: DateTime.now().toIso8601String(),
    ));

    // 2. Trigger Rest Timer
    final player = Provider.of<WorkoutPlayerService>(context, listen: false);
    player.completeSet(widget.exercise.restSeconds);

    // 3. Update UI
    setState(() {
      _isCompleted = true;
    });
  }
}