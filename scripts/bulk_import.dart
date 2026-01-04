import 'dart:convert';
import 'dart:io';
import 'package:supabase/supabase.dart'; // Add 'supabase' to pubspec.yaml dev_dependencies if needed

// CONFIGURATION
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseKey = 'YOUR_SUPABASE_SERVICE_ROLE_KEY'; // Use Service Role Key for bulk admin writes
const String exercisesPath = 'C:/path/to/free-exercise-db-main/exercises'; // Update this path

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  final dir = Directory(exercisesPath);
  final List<Map<String, dynamic>> batch = [];

  print("Reading files from $exercisesPath...");

  await for (final file in dir.list(recursive: true)) {
    if (file is File && file.path.endsWith('.json')) {
      try {
        final content = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        
        // Map JSON to DB Schema
        batch.add({
          'name': json['name'],
          'force': json['force'],
          'level': json['level'],
          'mechanic': json['mechanic'],
          'equipment_required': json['equipment'] != null ? [json['equipment']] : [],
          'primary_muscles': json['primaryMuscles'] ?? [],
          'secondary_muscles': json['secondaryMuscles'] ?? [],
          'instructions': json['instructions'] ?? [],
          'category': json['category'],
          'images': json['images'] ?? [],
        });

        // Upload in batches of 100
        if (batch.length >= 100) {
          await client.from('exercises').upsert(batch, onConflict: 'name');
          print("Uploaded batch of 100...");
          batch.clear();
        }
      } catch (e) {
        print("Skipping file ${file.path}: $e");
      }
    }
  }

  // Upload remaining
  if (batch.isNotEmpty) {
    await client.from('exercises').upsert(batch, onConflict: 'name');
    print("Uploaded final batch.");
  }
  
  print("Done!");
}