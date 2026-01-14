import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/attachment.dart';

class AiEquipmentService {
  List<String> _knownExerciseNames = [];
  late final GenerativeModel _model;

  AiEquipmentService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: apiKey,
    );
  }

  Future<void> loadExerciseLibrary() async {
    if (_knownExerciseNames.isNotEmpty) return;
    try {
      final String response = await rootBundle.loadString('assets/data/exercises.json');
      final List<dynamic> data = json.decode(response);
      _knownExerciseNames = data.map((e) => e['name'].toString()).toList();
    } catch (e) {
      debugPrint("Error loading exercise library: $e");
    }
  }

  Future<List<String>> analyzeEquipment({
    required String title,
    required String model,
    required String notes,
    List<Attachment>? attachments,
  }) async {
    await loadExerciseLibrary();
    
    if (dotenv.env['GEMINI_API_KEY'] == null) {
      debugPrint("Error: Missing GEMINI_API_KEY");
      return [];
    }

    final promptText = '''
    You are an expert fitness equipment analyst. 
    Analyze the provided equipment details and valid exercises.
    
    Equipment Details:
    - Title: $title
    - Model: $model
    - Notes: $notes
    
    Task:
    1. Identify what this machine is.
    2. Determine every exercise that can be performed on it.
    
    CRITICAL INSTRUCTIONS:
    - IF the equipment is a "Home Gym", "Functional Trainer", "All-in-One", or "Smith Machine":
      Assume it has standard High/Low pulleys and standard attachments (lat bar, handles) unless stated otherwise. 
      Aggressively map these to standard cable exercises (e.g., Lat Pulldown, Triceps Pushdown, Cable Crossover, Face Pull).
    
    - MATCHING RULES:
      1. Try to find an EXACT match in the "Valid Exercises" list.
      2. If an exact match is not found, find the CLOSEST SEMANTIC MATCH (e.g., "Lat Pulldown" -> "Cable Lat Pulldown").
      3. If the machine enables an exercise that is surprisingly similar to a list item, include it.
      4. DO NOT return an empty list if the machine is clearly capable of standard movements.
    
    - RETURN FORMAT:
      RETURN ONLY A JSON LIST of strings.
    
    Valid Exercises (Select from this list):
    ${_knownExerciseNames.join(", ")}
    ''';

    final List<Content> content = [
      Content.multi([
        TextPart(promptText),
        if (attachments != null)
          ...attachments.map((file) {
            final bytes = file.bytes;
            final mime = file.mimeType ?? 'image/jpeg';
            if (bytes != null) {
              return DataPart(mime, bytes);
            }
            return TextPart("");
          }).where((part) {
            if (part is DataPart) return true;
            if (part is TextPart) return part.text.isNotEmpty;
            return false;
          }),
      ])
    ];

    try {
      final response = await _model.generateContent(content);
      final text = response.text;
      if (text == null) return [];

      // Extract JSON from markdown or raw text
      final jsonString = _extractJson(text);
      final List<dynamic> parsed = json.decode(jsonString);
      
      return parsed.map((e) => e.toString()).toList();

    } catch (e) {
      debugPrint("AI Analysis Failed: $e");
      return [];
    }
  }

  String _extractJson(String text) {
    if (text.contains('```json')) {
      final start = text.indexOf('```json') + 7;
      final end = text.lastIndexOf('```');
      return text.substring(start, end).trim();
    } else if (text.contains('```')) {
      final start = text.indexOf('```') + 3;
      final end = text.lastIndexOf('```');
      return text.substring(start, end).trim();
    }
    return text.trim();
  }
}
