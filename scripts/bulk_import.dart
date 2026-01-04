import 'dart:convert';
import 'dart:io';
import 'package:supabase/supabase.dart';

// CONFIGURATION (Default fallback)
// Replace these with your actual Supabase keys or use environment variables
const String supabaseUrl = 'https://dwtpwfwlviustmkspwms.supabase.co'; 
const String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR3dHB3Zndsdml1c3Rta3Nwd21zIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NzMwNjUwOSwiZXhwIjoyMDgyODgyNTA5fQ.0OrmKEdFwzJGnasuc8kbXDYUe1o_Ah1bQw396sbCAAw'; 

void main(List<String> arguments) async {
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  // 1. Determine Path: Argument -> Input
  String exercisesPath;
  
  if (arguments.isNotEmpty) {
    exercisesPath = arguments.first;
  } else {
    stdout.write('Enter the full path to the "exercises" folder (drag & drop folder here): ');
    final input = stdin.readLineSync();
    if (input != null && input.isNotEmpty) {
      // Remove quotes if user dragged/dropped folder into terminal
      exercisesPath = input.replaceAll('"', '').replaceAll("'", "").trim();
    } else {
      stdout.writeln("❌ No path provided."); // Fixed: avoid_print
      return;
    }
  }

  final dir = Directory(exercisesPath);

  if (!dir.existsSync()) {
    stdout.writeln('❌ Error: Directory not found at: $exercisesPath'); // Fixed: avoid_print
    return;
  }

  stdout.writeln("📂 Reading files from: $exercisesPath"); // Fixed: avoid_print
  
  final List<Map<String, dynamic>> batch = [];
  int totalUploaded = 0;

  // 2. Iterate and Upload
  await for (final file in dir.list(recursive: true)) {
    if (file is File && file.path.endsWith('.json')) {
      try {
        final content = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        
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

        // Batch size of 100 for better performance
        if (batch.length >= 100) {
          await client.from('exercises').upsert(batch, onConflict: 'name');
          totalUploaded += batch.length;
          stdout.write('\r🚀 Uploaded $totalUploaded exercises...'); // Fixed: avoid_print
          batch.clear();
        }
      } catch (e) {
        stdout.writeln("\n⚠️ Skipping file ${file.path}: $e"); // Fixed: avoid_print
      }
    }
  }

  // Upload remaining items
  if (batch.isNotEmpty) {
    await client.from('exercises').upsert(batch, onConflict: 'name');
    totalUploaded += batch.length;
  }
  
  stdout.writeln("\n✅ Success! Total exercises imported: $totalUploaded"); // Fixed: avoid_print
}