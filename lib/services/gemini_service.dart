import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/plan.dart';
import 'package:uuid/uuid.dart';

/// Service responsible for communicating with Google's Gemini AI.
/// It constructs the prompt, sends it, and parses the JSON response into a WorkoutPlan.
class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    // 1. Load API Key from .env file
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }

    // 2. Initialize the model. We use 'gemini-2.0-flash' for speed and cost-efficiency.
    _model = GenerativeModel(
      model: 'gemini-2.0-flash', 
      apiKey: apiKey,
    );
  }

  /// Generates a full workout plan based on user inputs.
  /// 
  /// [goal]: The user's primary fitness goal (e.g., "Hypertrophy").
  /// [daysPerWeek]: How many days they want to train.
  /// [equipment]: List of available equipment strings.
  /// [userProfile]: Map of user stats (Age, Weight, etc.).
  /// [strengthStats]: NEW - A string summary of the user's 1 Rep Maxes (e.g., "Bench: 200lbs").
  Future<WorkoutPlan?> generateFullPlan(
    String goal, 
    String daysPerWeek, 
    List<String> equipment,
    Map<String, String> userProfile,
    String strengthStats // <--- New Argument
  ) async {
    
    // Convert the user profile map into a readable string for the AI
    final profileString = userProfile.entries
        .map((e) => "${e.key}: ${e.value}")
        .join(', ');

    // Define the strict JSON structure we expect back. 
    // This ensures the app doesn't crash when trying to read the AI's response.
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

    // Construct the Prompt. This is the "instruction manual" for the AI.
    final prompt = '''
      You are an expert fitness coach API. 
      Create a $daysPerWeek-day split workout plan for a user with goal: "$goal".
      
      --- USER CONTEXT ---
      Profile: $profileString
      Strength Levels (1 Rep Max): $strengthStats
      
      --- CONSTRAINTS ---
      1. They ONLY have access to: ${equipment.join(', ')}.
      2. For "intensity", suggest a target percentage of 1RM (e.g. "75%") OR an RPE (e.g. "RPE 8").
      3. Use the Strength Levels to gauge difficulty. If they are strong (e.g., >300lb squat), suggest advanced protocols (5x5, wave loading). If strength is low or unknown, stick to standard hypertrophy (3x10).
      4. For "secondsPerSet", use 0 for normal reps. Use >0 (e.g. 60) ONLY for time-based exercises like Planks.
      
      --- OUTPUT FORMAT ---
      STRICTLY return ONLY valid JSON matching this schema:
      $schema
      
      Do not include markdown formatting (```json), just the raw JSON string.
    ''';

    // Send request to AI
    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    
    if (response.text == null) {
      throw Exception("AI returned empty response");
    }

    // Clean up the response in case the AI added markdown backticks
    String cleanedText = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
    
    // Parse JSON into Dart Objects
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(cleanedText);
      jsonMap['id'] = const Uuid().v4(); // Assign a unique ID to the new plan
      return WorkoutPlan.fromJson(jsonMap);
    } catch (e) {
      throw Exception("Failed to parse AI response: $e");
    }
  }
}