import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:open_lift_2/models/plan.dart';
import 'package:open_lift_2/models/exercise.dart'; // Import Exercise model
import 'package:open_lift_2/models/log.dart'; // Import LogEntry model
import 'package:open_lift_2/services/auth_service.dart';
import 'package:open_lift_2/services/database_service.dart';

class PlanGenerationResult {
  final WorkoutPlan plan;
  final List<Exercise> newExercises;

  PlanGenerationResult(this.plan, this.newExercises);
}

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

  Future<PlanGenerationResult?> generateFullPlan(
    String goal,
    String daysPerWeek,
    int duration,
    List<String> equipment,
    Map<String, String> userProfile,
    String strengthStats,
    List<String> validExercises, // KNOWN EXERCISES
  ) async {
    // Optimized prompt for healthy, valid plans
    final prompt = '''
      You are an expert Strength & Conditioning Coach. Create a $daysPerWeek-day/week workout plan.
      
      === CONTEXT ===
      GOAL: $goal.
      DURATION: Approx $duration minutes per session.
      USER PROFILE: ${userProfile.toString()}
      STRENGTH STATS: $strengthStats
      
      === INVENTORY (CRITICAL) ===
      AVAILABLE TOOLS: ${equipment.isEmpty ? "Bodyweight only" : equipment.join(', ')}.
      
      *** RULES ***
      1. **VALIDATION:** ONLY program exercises if the user has the required tool.
      2. **EXISTING EXERCISES:** Prefer using exercises from this list: ${validExercises.take(100).join(', ')}... (and others you know are standard).
      3. **NEW EXERCISES:** If you need an exercise NOT commonly known or specific to a machine, you MUST define it in `definitions`.
      4. **HEALTHY ROUTINE:** 
         - Include Warm-up (Mobility) and Cool-down.
         - Balance Push/Pull/Legs or Upper/Lower to prevent injury.
         - Ensure appropriate volume (sets/reps) for the goal.

      === OUTPUT STRUCTURE ===
      Return a SINGLE JSON Object:
      {
        "definitions": [
          {
            "name": "Face Pull",
            "category": "Shoulders",
            "primary_muscles": ["Rear Delts", "Rotator Cuff"],
            "equipment": ["Cable"],
            "instructions": ["Set rope to face height", "Pull to forehead", "Squeeze rear delts"],
            "images": [] 
          }
        ],
        "schedule": [
          {
            "day_name": "Day 1 - Upper Power",
            "exercises": [
              {
                "name": "Face Pull",
                "sets": 3,
                "reps": "12-15",
                "rest": 60,
                "notes": "Warm-up"
              }
            ]
          }
        ]
      }
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final String rawJson = response.text ?? "{}";
      
      final cleanJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> data = jsonDecode(cleanJson);

      // 1. Parse Definitions (New Exercises)
      final List<Exercise> newExercises = [];
      if (data['definitions'] != null) {
        for (var def in data['definitions']) {
          newExercises.add(Exercise(
            id: const Uuid().v4(), // Generate ID for new exercise
            name: def['name'],
            category: def['category'],
            primaryMuscles: List<String>.from(def['primary_muscles'] ?? []),
            secondaryMuscles: [],
            equipment: List<String>.from(def['equipment'] ?? []),
            instructions: List<String>.from(def['instructions'] ?? []),
            images: [], // No photos generated
          ));
        }
      }

      // 2. Parse Schedule
      final List<dynamic> daysRaw = data['schedule'] ?? [];
      final List<WorkoutDay> days = daysRaw.map((d) => WorkoutDay.fromMap(d)).toList();

      final plan = WorkoutPlan(
        id: const Uuid().v4(),
        name: "AI: $goal",
        goal: goal,
        type: "AI Generated",
        days: days,
      );

      return PlanGenerationResult(plan, newExercises);

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

  /// NEW: Vision-based analysis for Equipment + Exercise parsing
  Future<Map<String, dynamic>> analyzeEquipmentVision({
    required String itemName,
    String? userNotes,
    List<DataPart>? mediaParts, // Images or PDFs
  }) async {
    final prompt = '''
      You are an expert fitness equipment auditor. 
      Analyze the equipment: "$itemName".
      User Notes: "${userNotes ?? 'None'}"

      Your Task:
      1. Identify the core capabilities (e.g., Cable, Smith Machine, Bench).
      2. Extract OR infer a list of 10-15 standard exercises that can be performed on this specific item.
      
      Return a JSON object:
      {
        "capabilities": ["Cable", "Leg Developer", ...],
        "exercises": [
          {
            "name": "Leg Extension",
            "category": "Legs",
            "primary_muscles": ["Quads"],
            "instructions": ["Sit on bench", "Extend legs", "Squeeze quads"]
          }
        ]
      }
      
      Return ONLY valid JSON.
    ''';

    try {
      final content = [
        Content.multi([
          TextPart(prompt),
          if (mediaParts != null) ...mediaParts,
        ])
      ];

      final response = await _model.generateContent(content);
      final String rawJson = response.text ?? "{}";
      final cleanJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
      
      return jsonDecode(cleanJson);
    } catch (e) {
      debugPrint("Gemini Vision Analysis Error: $e");
      return {"capabilities": [], "exercises": []};
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

  /// AI Coach Chat
  Future<String> chatWithCoach(
    String userMessage, 
    List<Map<String, String>> history, 
    Map<String, dynamic> contextData
  ) async {
    // 1. Construct Context Block
    final profile = contextData['profile'] ?? "Unknown";
    final equipment = contextData['equipment'] ?? "Unknown";
    final recentLogs = contextData['recent_logs'] ?? "No recent activity";
    final strengthStats = contextData['strength_stats'] ?? "No data";
    final specificHistory = contextData['specific_history'] ?? ""; // NEW

    final systemPrompt = '''
      You are "OpenLift Coach", an expert personal trainer and strength coach.
      
      === YOUR KNOWLEDGE BASE (USER CONTEXT) ===
      PROFILE: $profile
      AVAILABLE EQUIPMENT: $equipment
      ESTIMATED 1RMs: $strengthStats
      RECENT WORKOUTS (Global): $recentLogs
      
      ${specificHistory.isNotEmpty ? "=== SPECIFIC EXERCISE HISTORY ===\n$specificHistory" : ""}
      
      === YOUR MISSION ===
      1. Answer questions about fitness, form, programming, and nutrition.
      2. Use the user's specific context.
      3. If specific history is provided, analyze the trend (Volume, Intensity, Frequency) to answer questions like "Why am I stalled?".
      4. RPE (Rate of Perceived Exertion): Users rate sets from 1-10. 
         - RPE 10 = Max effort (no reps left).
         - RPE 7-9 = Optimal for strength/hypertrophy.
         - RPE < 6 = Warm-up or low intensity.
         - Use this to detect if a lack of progress is due to low intensity (sandbagging) or overtraining (too many RPE 10s).
      5. Be encouraging but direct. 
      
      === STYLE ===
      Concise, actionable, professional yet friendly.
    ''';

    try {
      // 2. Build History for the Model
      final List<Content> chatHistory = [];
      
      // Add System Prompt as the first "model" turn context or just prepend to first user message.
      // Gemini API supports 'system_instruction' in beta, but standard way is to prepend context.
      
      // We will prepend the system prompt to the current interaction context
      // Reconstruct history
      for (var msg in history) {
        if (msg['role'] == 'user') {
          chatHistory.add(Content.text(msg['content']!));
        } else {
          chatHistory.add(Content.model([TextPart(msg['content']!)]));
        }
      }

      // Add the current message with system context prepended
      final finalPrompt = "$systemPrompt\n\nUser Question: $userMessage";
      chatHistory.add(Content.text(finalPrompt));

      final response = await _model.generateContent(chatHistory);
      return response.text ?? "I'm having trouble thinking right now. Try again?";
      
    } catch (e) {
      debugPrint("AI Coach Error: $e");
      return "I encountered an error connecting to the coaching server. Please check your internet connection.";
    }
  }

  /// Generates a Weekly Review based on recent logs.
  Future<Map<String, dynamic>> generateWeeklyReview(List<Map<String, dynamic>> lastWeekLogs) async {
    final prompt = '''
      You are an elite Strength Coach analyzing a client's past week of training.
      
      === DATA (LAST 7 DAYS) ===
      ${jsonEncode(lastWeekLogs)}
      
      === TASK ===
      Analyze the volume, consistency, and intensity.
      
      Return ONLY valid JSON with this structure:
      {
        "score": 85, // 0-100 based on consistency
        "summary": "Great work hitting the gym 4 times this week! Your chest volume is up.",
        "highlights": ["New PR on Bench Press", "Consistent workout times"],
        "improvements": ["Missed Leg Day", "Low volume on back exercises"],
        "next_week_goals": [
          "Increase Squat weight by 5lbs",
          "Add 1 more set to Pull-ups"
        ]
      }
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      final String rawJson = response.text ?? "{}";
      final cleanJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
      
      return jsonDecode(cleanJson);
    } catch (e) {
      debugPrint("Weekly Review Error: $e");
      return {
        "score": 0,
        "summary": "Unable to generate review. Please try again.",
        "highlights": [],
        "improvements": [],
        "next_week_goals": []
      };
    }
  }

  /// NEW: Post-Workout Quick Insight
  Future<String> generatePostWorkoutInsight(List<LogEntry> sessionLogs) async {
    if (sessionLogs.isEmpty) return "";
    
    final logsJson = sessionLogs.map((LogEntry l) => {
      'exercise': l.exerciseName,
      'weight': l.weight,
      'reps': l.reps,
      'rpe': l.rpe,
    }).toList();

    final prompt = '''
      You are "OpenLift Coach". The user just finished a workout.
      Analyze these logs: ${jsonEncode(logsJson)}
      
      Task: Provide a ONE-SENTENCE high-value technical or motivational insight.
      - If RPE is high across the board, emphasize recovery/sleep.
      - If RPE is low, suggest increasing weight next time.
      - If one exercise was much harder than others, mention the imbalance.
      
      BE BRIEF. 20 words max.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text?.trim() ?? "";
    } catch (e) {
      debugPrint("Post-Workout Insight Error: $e");
      return "";
    }
  }
}