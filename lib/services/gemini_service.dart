import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/plan.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      throw Exception("GEMINI_API_KEY not found in .env");
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
  }

  Future<WorkoutPlan> generateFullPlan(
    String goal,
    String daysPerWeek,
    int minutesPerWorkout,
    List<String> equipment,
    Map<String, String> userProfile,
    String strengthStats,
    List<String> validExercises, // NEW: The Vocabulary List
  ) async {
    
    // Create a "Menu" string, limiting to top 100 to save tokens if list is huge
    final exerciseMenu = validExercises.take(100).join(", ");

    final prompt = '''
    Act as an elite strength and conditioning coach.
    Create a $daysPerWeek-day workout plan for: "$goal".
    
    USER PROFILE:
    $userProfile
    
    STRENGTH STATS (1 Rep Maxes):
    $strengthStats
    
    AVAILABLE EQUIPMENT:
    ${equipment.join(', ')}
    
    CONSTRAINTS:
    1. Time Limit: $minutesPerWorkout minutes per session.
    2. VALID EXERCISES: You MUST prefer exercises from this list: [$exerciseMenu]. Only use other names if absolutely necessary.
    3. FORMAT: Return ONLY valid JSON. No markdown formatting.
    
    JSON STRUCTURE:
    {
      "name": "Plan Name (e.g. Powerbuilding Phase 1)",
      "goal": "Short description",
      "type": "Strength" or "HIIT",
      "days": [
        {
          "name": "Day 1 - Upper Power",
          "exercises": [
            {
              "name": "Exercise Name (Use Exact Wiki Name)",
              "sets": 3,
              "reps": "8-12",
              "rest_seconds": 90,
              "seconds_per_set": 0 (Use 0 for normal reps, or e.g. 60 for timed planks)
            }
          ]
        }
      ]
    }
    
    CRITICAL INSTRUCTION: 
    If the goal implies cardio/conditioning (e.g. "HIIT", "Tabata", "Circuit"), set "type": "HIIT" and ensure "seconds_per_set" is set for time-based moves.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      final cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '');
      final Map<String, dynamic> data = jsonDecode(cleanJson);
      
      return WorkoutPlan.fromMap({
        'id': DateTime.now().toIso8601String(),
        'name': data['name'],
        'goal': data['goal'],
        'type': data['type'] ?? 'Strength', // Support new type
        'schedule_json': jsonEncode(data['days']),
      });
    } catch (e) {
      throw Exception("AI Generation Failed: $e");
    }
  }
}