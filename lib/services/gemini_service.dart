import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import this
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

    _model = GenerativeModel(
      model: 'gemini-pro', 
      apiKey: apiKey
    );
  }

  // ... (Rest of the file remains exactly the same)
  Future<WorkoutPlan?> generateFullPlan(String goal, String daysPerWeek, List<String> equipment) async {
    const schema = '''
    {
      "name": "Name of plan",
      "goal": "User goal",
      "days": [
        {
          "name": "Day Name",
          "exercises": [
            {
              "name": "Exercise Name",
              "sets": 3,
              "reps": "8-12",
              "restSeconds": 90
            }
          ]
        }
      ]
    }
    ''';

    final prompt = '''
      You are an expert fitness coach API. 
      Create a $daysPerWeek-day split workout plan for a user with goal: "$goal".
      They ONLY have access to: ${equipment.join(', ')}.
      
      STRICTLY return ONLY valid JSON matching this schema:
      $schema
      
      Do not include markdown formatting (```json), just the raw JSON string.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null) return null;

      String cleanedText = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final Map<String, dynamic> jsonMap = jsonDecode(cleanedText);
      jsonMap['id'] = const Uuid().v4();
      
      return WorkoutPlan.fromJson(jsonMap);
    } catch (e) {
      debugPrint("Gemini Error: $e");
      return null;
    }
  }
}