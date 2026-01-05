import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/plan.dart';
import 'workout_player_screen.dart';
import 'manual_plan_creator_screen.dart';

class SavedPlansScreen extends StatefulWidget {
  const SavedPlansScreen({super.key});

  @override
  State<SavedPlansScreen> createState() => _SavedPlansScreenState();
}

class _SavedPlansScreenState extends State<SavedPlansScreen> {
  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("My Plans")),
      body: FutureBuilder<List<WorkoutPlan>>(
        future: db.getPlans(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final plans = snapshot.data!;

          if (plans.isEmpty) return const Center(child: Text("No saved plans."));

          return ListView.builder(
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(plan.goal),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ManualPlanCreatorScreen(planToEdit: plan)),
                          );
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          db.deletePlan(plan.id);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  children: [
                    ...plan.days.map((day) => ListTile(
                      title: Text(day.name),
                      trailing: const Icon(Icons.play_arrow, color: Colors.green),
                      onTap: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => WorkoutPlayerScreen(workoutDay: day))
                        );
                      },
                    )),
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