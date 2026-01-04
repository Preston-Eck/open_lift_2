import 'package:flutter/material.dart';
import '../models/exercise.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Tags ---
            Wrap(
              spacing: 8,
              children: [
                if (exercise.category != null) Chip(label: Text(exercise.category!), backgroundColor: Colors.blue.withValues(alpha: 0.2)),
                if (exercise.mechanic != null) Chip(label: Text(exercise.mechanic!)),
                if (exercise.level != null) Chip(label: Text(exercise.level!)),
              ],
            ),
            const SizedBox(height: 20),

            // --- Images (If available) ---
            if (exercise.images.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: exercise.images.length,
                  itemBuilder: (context, index) {
                    // Note: In the real app, you would load these from assets or a URL
                    // For now, we assume they are filenames stored in Supabase strings
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 300,
                      color: Colors.grey[900],
                      child: Center(child: Text("Image: ${exercise.images[index]}", style: const TextStyle(color: Colors.white))),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 20),

            // --- Muscles ---
            const Text("Primary Muscles", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            Text(exercise.primaryMuscles.join(', '), style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            
            if (exercise.secondaryMuscles.isNotEmpty) ...[
              const Text("Secondary Muscles", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(exercise.secondaryMuscles.join(', '), style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 20),
            ],

            // --- Instructions ---
            const Text("Instructions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
            const SizedBox(height: 10),
            ...exercise.instructions.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${entry.key + 1}.", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 16, height: 1.4))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}