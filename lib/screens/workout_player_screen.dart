import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/workout_player_service.dart';
import '../services/database_service.dart';
import '../models/log.dart'; // Ensure you have this or generic map logic

class WorkoutPlayerScreen extends StatelessWidget {
  const WorkoutPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<WorkoutPlayerService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Active Workout"),
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
          // Timer Header
          Container(
            padding: const EdgeInsets.all(24),
            color: player.state == WorkoutState.resting ? Colors.red.withOpacity(0.2) : Colors.transparent,
            child: Center(
              child: Text(
                player.state == WorkoutState.resting 
                  ? "REST: ${player.timerSeconds}s" 
                  : "WORKING",
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text("Bench Press", style: TextStyle(fontSize: 24)),
                const SizedBox(height: 10),
                _buildSetRow(context, 1, 60.0, 10),
                _buildSetRow(context, 2, 60.0, 10),
                _buildSetRow(context, 3, 60.0, 10),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: player.finishWorkout,
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

  Widget _buildSetRow(BuildContext context, int setNum, double weight, int reps) {
    final player = Provider.of<WorkoutPlayerService>(context, listen: false);
    
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text("$setNum")),
        title: Text("${weight}kg x $reps reps"),
        trailing: Checkbox(
          value: false, // In a real app, bind this to local state
          onChanged: (val) {
            if (val == true) {
              // Log the set to DB
              Provider.of<DatabaseService>(context, listen: false).logSet(
                LogEntry(
                  id: DateTime.now().toIso8601String(),
                  exerciseId: "bench_press", 
                  exerciseName: "Bench Press", 
                  weight: weight, 
                  reps: reps, 
                  volumeLoad: weight * reps, 
                  timestamp: DateTime.now().toIso8601String()
                )
              );
              // Trigger rest timer
              player.completeSet(60); // 60s rest
            }
          },
        ),
      ),
    );
  }
}