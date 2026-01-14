import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:http/http.dart' as http;
import '../models/attachment.dart';

class AiEquipmentService {
  List<String> _knownExerciseNames = [];

  AiEquipmentService();

  Future<void> loadExerciseLibrary() async {
    if (_knownExerciseNames.isNotEmpty) return;
    try {
      final String response = await rootBundle.loadString('assets/data/exercises.json');
      final List<dynamic> data = json.decode(response);
      _knownExerciseNames = data.map((e) => e['name'].toString()).toList();
    } catch (e) {
      print("Error loading exercise library: $e");
    }
  }

  Future<List<String>> analyzeEquipment({
    required String title,
    required String model,
    required String notes,
    List<Attachment>? attachments,
  }) async {
    await loadExerciseLibrary();
    
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
    if (apiKey.isEmpty) {
      print("Error: Missing GEMINI_API_KEY");
      return [];
    }

    // Direct HTTP Call to Gemini 2.5 Flash
    // Verified available via API listing
    const modelId = 'gemini-2.5-flash';
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey');

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

    // Build Request Body
    List<Map<String, dynamic>> parts = [
      {"text": promptText}
    ];

    if (attachments != null) {
      for (var file in attachments) {
        try {
           final bytes = file.bytes;
           final mime = file.mimeType ?? 'image/jpeg';
           
           if (bytes != null) {
              final base64Image = base64Encode(bytes);
              parts.add({
                "inline_data": {
                  "mime_type": mime,
                  "data": base64Image
                }
              });
           }
        } catch (e) {
          print("Error reading attachment: $e");
        }
      }
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{ "parts": parts }]
        }),
      );

      if (response.statusCode != 200) {
        print("Gemini API Error (${response.statusCode}): ${response.body}");
        return [];
      }

      final jsonResponse = jsonDecode(response.body);
      // Simplify accessing the candidates -> content -> parts -> text
      final candidates = jsonResponse['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return [];
      
      final contentParts = candidates[0]['content']['parts'] as List<dynamic>?;
      if (contentParts == null || contentParts.isEmpty) return [];
      
      final text = contentParts[0]['text'] as String?;
      if (text == null) return [];

      // Extract JSON from markdown
      final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> parsed = json.decode(cleanJson);
      
      return parsed.map((e) => e.toString()).toList();

    } catch (e) {
      print("AI Analysis Failed (HTTP): $e");
      return [];
    }
  }
}
