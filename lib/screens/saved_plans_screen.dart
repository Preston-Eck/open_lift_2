import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/plan.dart';
import 'workout_player_screen.dart'; // We will update this next

class SavedPlansScreen extends StatelessWidget {
  const SavedPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("My Workout Plans")),
      body: FutureBuilder<List<WorkoutPlan>>(
        future: db.getPlans(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final plans = snapshot.data!;

          if (plans.isEmpty) {
            return const Center(child: Text("No plans yet. Ask the AI Coach!"));
          }

          return ListView.builder(
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(plan.goal),
                  children: [
                    ...plan.days.map((day) => ListTile(
                      title: Text(day.name),
                      subtitle: Text("${day.exercises.length} Exercises"),
                      trailing: const Icon(Icons.play_arrow, color: Colors.green),
                      onTap: () {
                        // Start this specific day
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (_) => WorkoutPlayerScreen(workoutDay: day)
                          )
                        );
                      },
                    )),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text("Delete Plan", style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        // Add delete logic to DatabaseService if needed
                        // await db.deletePlan(plan.id);
                      }, 
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}