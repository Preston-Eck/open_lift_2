import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise.dart';

class SeederService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> seedInitialExercises() async {
    try {
      // 1. Load JSON from assets
      final String response = await rootBundle.loadString('assets/data/exercises.json');
      final List<dynamic> data = json.decode(response);

      // 2. Convert to Model
      final List<Exercise> exercises = data.map((json) => Exercise.fromJson(json)).toList();

      // 3. Batch Upload to Supabase (Upsert to prevent duplicates)
      // Supabase limits batch sizes, so we chunk it.
      const int batchSize = 50;
      for (var i = 0; i < exercises.length; i += batchSize) {
        final end = (i + batchSize < exercises.length) ? i + batchSize : exercises.length;
        final batch = exercises.sublist(i, end);
        
        await _supabase.from('exercises').upsert(
          batch.map((e) => e.toSupabaseMap()).toList(),
          onConflict: 'name',
        );
        print("Uploaded batch $i to $end");
      }
      print("Seeding Complete!");
    } catch (e) {
      print("Error seeding data: $e");
    }
  }
}