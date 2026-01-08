import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/plan.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      throw Exception("GEMINI_API_KEY not found in .env");
    }
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp', 
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // Force JSON response
      ),
    );
  }

  Future<WorkoutPlan?> generateFullPlan(
    String goal,
    String daysPerWeek,
    int duration,
    List<String> equipment,
    Map<String, String> userProfile,
    String strengthStats,
    List<String> validExercises,
  ) async {
    // CHANGED: Completely overhauled prompt to enforce strict equipment rules
    final prompt = '''
      You are an expert Strength & Conditioning Coach. Create a $daysPerWeek-day/week workout plan.
      
      === CONTEXT ===
      GOAL: $goal.
      DURATION: Approx $duration minutes per session.
      USER PROFILE: ${userProfile.toString()}
      STRENGTH STATS: $strengthStats
      
      === INVENTORY (CRITICAL) ===
      AVAILABLE TOOLS & CAPABILITIES: ${equipment.isEmpty ? "Bodyweight only" : equipment.join(', ')}.
      
      *** STRICT RULES FOR EQUIPMENT USAGE ***
      1. **VALIDATION:** You may ONLY program an exercise if the user explicitly has the required tool in the list above.
         - If "Barbell" is NOT listed, you CANNOT program Barbell Squats, Bench Press, etc.
         - If "Cable" is NOT listed, you CANNOT program Cable Flys or Tricep Pushdowns.
         - "Bodyweight" is always available.
      
      2. **MACHINE IDENTIFICATION:** The list contains Model Names (e.g., "SincMill SCM-1160", "Bowflex"). 
         - **NEVER** use a Model Name as the "name" of an exercise. 
         - Instead, use the standard movement that machine allows (e.g., use "Lat Pulldown", NOT "SincMill SCM-1160").
         - If a specific machine is listed, assume the user can perform standard exercises associated with it (e.g. Power Cage = Squats, Pull-ups).

      3. **SUBSTITUTIONS:** If the user lacks a tool (e.g. No Barbell), you MUST substitute with an available tool (e.g. Dumbbell Squat).

      === PROGRAM STRUCTURE ===
      1. **Warm-up:** Every session MUST start with a "Warm-up & Mobility" section (5-10 mins).
      2. **Selection:** Use standard, proven exercises. Prioritize compound movements first.
      3. **Progression:** Ensure the volume/intensity fits the user's fitness level.

      === OUTPUT ===
      Return ONLY valid JSON with this structure (Array of Days):
      [
        {
          "day_name": "Day 1 - Upper Body Focus",
          "exercises": [
            {
              "name": "Cat-Cow Stretch",
              "sets": 1,
              "reps": "60 sec",
              "rest": 0,
              "notes": "Mobility Warm-up"
            },
            {
              "name": "Dumbbell Bench Press",
              "sets": 3,
              "reps": "8-12",
              "rest": 60,
              "notes": "Control the eccentric"
            }
          ]
        }
      ]
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final String rawJson = response.text ?? "[]";
      
      final cleanJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> daysRaw = jsonDecode(cleanJson);

      final List<WorkoutDay> days = daysRaw.map((d) => WorkoutDay.fromMap(d)).toList();

      return WorkoutPlan(
        id: const Uuid().v4(),
        name: "AI: $goal",
        goal: goal,
        type: "AI Generated",
        days: days,
      );

    } catch (e) {
      debugPrint("Gemini Plan Generation Error: $e");
      return null;
    }
  }

  Future<List<String>> analyzeEquipment(String equipmentName, {String contextInfo = ""}) async {
    final prompt = '''
      You are an expert fitness equipment researcher. 
      Analyze the equipment item: "$equipmentName".
      
      Additional Context Provided by User:
      "$contextInfo"

      Your Task:
      1. If the input contains a specific Model Number (e.g. SCM-1160) or Brand, use your internal knowledge to identify its exact features.
      2. If it is a "Home Gym", "Functional Trainer", or "Smith Machine", break it down into standard capabilities.
      
      Return a JSON list of standard tags from this set (add others if strictly necessary):
      [
        "Barbell", "Dumbbell", "Cable", "Machine", "Bench", "Bodyweight", 
        "Pull Up Bar", "Dip Station", "Kettlebell", "Smith Machine", 
        "Resistance Band", "Cardio", "Leg Developer", "Pec Deck"
      ]

      Examples:
      - "SincMill SCM-1160" -> ["Cable", "Smith Machine", "Pull Up Bar", "Dip Station", "Bench"]
      - "Bowflex Xtreme" -> ["Cable", "Resistance Machine", "Leg Extension"]
      
      Return ONLY valid JSON.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      final String rawJson = response.text ?? "[]";
      final cleanJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final List<dynamic> parsed = jsonDecode(cleanJson);
      return parsed.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint("Gemini Equipment Analysis Error: $e");
      if (equipmentName.toLowerCase().contains("dumbbell")) return ["Dumbbell"];
      if (equipmentName.toLowerCase().contains("barbell")) return ["Barbell"];
      return ["Bodyweight"];
    }
  }

  /// Suggests exercises for a specific piece of equipment (Tag)
  /// excluding ones the user already has.
  Future<List<Map<String, dynamic>>> suggestMissingExercises(
    String targetTag, 
    List<String> existingExerciseNames,
    List<String> fullInventory 
  ) async {
    final prompt = '''
      The user explicitly owns the following equipment tags: ${fullInventory.join(', ')}.
      
      Task: Suggest 20 standard, effective exercises that utilize the "$targetTag" capability.
      
      CRITICAL CONSTRAINTS:
      1. The exercise MUST use "$targetTag".
      2. The exercise must NOT require any equipment NOT listed above.
      3. Assume "Bodyweight" is always available.
      4. Exclude these exercises already in the database: ${existingExerciseNames.take(50).join(', ')}.
      
      Return ONLY valid JSON with this structure:
      [
        {
          "name": "Exercise Name",
          "primary_muscles": ["Muscle 1", "Muscle 2"],
          "instructions": ["Step 1", "Step 2"]
        }
      ]
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      final String rawJson = response.text ?? "[]";
      final cleanJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final List<dynamic> parsed = jsonDecode(cleanJson);
      return List<Map<String, dynamic>>.from(parsed);
    } catch (e) {
      debugPrint("Gemini Suggestion Error: $e");
      return [];
    }
  }
}