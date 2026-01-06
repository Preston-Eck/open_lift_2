import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import '../models/exercise.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  String _getImageUrl(String path) {
    if (path.startsWith('http')) return path;
    // Hardcoded fallback if .env fails or variable is missing
    final projectId = dotenv.env['SUPABASE_URL'] ?? 'https://nlbxwoinogqmnkvyrsyi.supabase.co'; 
    // Ensure we don't double slash
    final baseUrl = projectId.endsWith('/') ? projectId : "$projectId/";
    return "${baseUrl}storage/v1/object/public/exercises/$path"; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exercise.images.isNotEmpty)
              SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: exercise.images.length,
                  itemBuilder: (context, index) {
                    final imageUrl = _getImageUrl(exercise.images[index]);
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 350,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint("Failed to load: $imageUrl");
                            return Container(
                              color: Colors.grey[200],
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                  Text("Image Error"),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
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
            if (exercise.instructions.isEmpty)
              const Text("No instructions available.", style: TextStyle(fontStyle: FontStyle.italic))
            else
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