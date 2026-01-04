import 'dart:convert';
import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:dotenv/dotenv.dart'; // Import standard dotenv

void main(List<String> arguments) async {
  // 1. Load .env file
  final env = DotEnv(includePlatformEnvironment: true)..load();
  
  final supabaseUrl = env['SUPABASE_URL'];
  final supabaseKey = env['SUPABASE_SERVICE_ROLE_KEY']; // Use Service Role for bulk writes

  if (supabaseUrl == null || supabaseKey == null) {
    stdout.writeln('❌ Error: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
    return;
  }

  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  // 2. Determine Path
  String exercisesPath;
  
  if (arguments.isNotEmpty) {
    exercisesPath = arguments.first;
  } else {
    stdout.write('Enter the full path to the "exercises" folder (drag & drop folder here): ');
    final input = stdin.readLineSync();
    if (input != null && input.isNotEmpty) {
      exercisesPath = input.replaceAll('"', '').replaceAll("'", "").trim();
    } else {
      stdout.writeln("❌ No path provided.");
      return;
    }
  }

  final dir = Directory(exercisesPath);

  if (!dir.existsSync()) {
    stdout.writeln('❌ Error: Directory not found at: $exercisesPath');
    return;
  }

  stdout.writeln("📂 Reading files from: $exercisesPath");
  
  final List<Map<String, dynamic>> batch = [];
  int totalUploaded = 0;

  // 3. Iterate and Upload
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

        if (batch.length >= 100) {
          await client.from('exercises').upsert(batch, onConflict: 'name');
          totalUploaded += batch.length;
          stdout.write('\r🚀 Uploaded $totalUploaded exercises...');
          batch.clear();
        }
      } catch (e) {
        stdout.writeln("\n⚠️ Skipping file ${file.path}: $e");
      }
    }
  }

  if (batch.isNotEmpty) {
    await client.from('exercises').upsert(batch, onConflict: 'name');
    totalUploaded += batch.length;
  }
  
  stdout.writeln("\n✅ Success! Total exercises imported: $totalUploaded");
}