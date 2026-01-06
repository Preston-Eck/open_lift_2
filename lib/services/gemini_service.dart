import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/plan.dart';
import 'package:uuid/uuid.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
  }

  Future<WorkoutPlan?> generateFullPlan(
    String goal, 
    String daysPerWeek, 
    int timeAvailableMins, // NEW ARGUMENT
    List<String> equipment,
    Map<String, String> userProfile,
    String strengthStats
  ) async {
    
    final profileString = userProfile.entries.map((e) => "${e.key}: ${e.value}").join(', ');

    const schema = '''
    {
      "name": "Plan Name",
      "goal": "Goal",
      "type": "Strength OR HIIT", 
      "days": [
        {
          "name": "Day 1",
          "exercises": [
            {
              "name": "Exercise Name",
              "sets": 3,
              "reps": "12",
              "restSeconds": 60,
              "intensity": "RPE 8",
              "secondsPerSet": 0
            }
          ]
        }
      ]
    }
    ''';

    final prompt = '''
      Create a $daysPerWeek-day workout plan.
      User Goal: "$goal".
      Time Available: $timeAvailableMins mins/session.
      
      CONTEXT:
      Profile: $profileString
      Strength: $strengthStats
      Equipment: ${equipment.join(', ')}

      LOGIC:
      1. If goal implies cardio/fat loss AND time < 30 mins, set "type" to "HIIT".
      2. If goal is muscle/strength, set "type" to "Strength".
      3. For HIIT: "secondsPerSet" should be > 0 (e.g., 45), "reps" is "0". Low rest (15s).
      4. For Strength: "secondsPerSet" is 0. Normal rest (90s+).
      
      OUTPUT JSON (NO MARKDOWN):
      $schema
    ''';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    
    if (response.text == null) throw Exception("Empty AI response");

    String cleanedText = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
    
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(cleanedText);
      jsonMap['id'] = const Uuid().v4();
      return WorkoutPlan.fromJson(jsonMap);
    } catch (e) {
      throw Exception("Failed to parse AI response: $e");
    }
  }
}