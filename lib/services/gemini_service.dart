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

    _model = GenerativeModel(
      model: 'gemini-2.0-flash', 
      apiKey: apiKey,
    );
  }

  // Updated signature to accept userProfile map
  Future<WorkoutPlan?> generateFullPlan(
    String goal, 
    String daysPerWeek, 
    List<String> equipment,
    Map<String, String> userProfile
  ) async {
    
    // Construct profile string for prompt
    final profileString = userProfile.entries
        .map((e) => "${e.key}: ${e.value}")
        .join(', ');

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
              "restSeconds": 90,
              "intensity": "75%",
              "secondsPerSet": 0
            }
          ]
        }
      ]
    }
    ''';

    final prompt = '''
      You are an expert fitness coach API. 
      Create a $daysPerWeek-day split workout plan for a user with goal: "$goal".
      
      User Profile: $profileString
      
      They ONLY have access to: ${equipment.join(', ')}.
      
      For "intensity", suggest a target percentage of 1RM (e.g. "75%") OR an RPE (e.g. "RPE 8").
      For "secondsPerSet", use 0 for normal reps. Use >0 (e.g. 60) ONLY for time-based exercises like Planks.
      
      STRICTLY return ONLY valid JSON matching this schema:
      $schema
      
      Do not include markdown formatting (```json), just the raw JSON string.
    ''';

    // REMOVED TRY/CATCH: Let errors propagate to UI
    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    
    if (response.text == null) {
      throw Exception("AI returned empty response");
    }

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