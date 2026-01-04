import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    // Initialize with your API Key
    _model = GenerativeModel(model: 'gemini-pro', apiKey: 'YOUR_GEMINI_API_KEY');
  }

  Future<String> getSubstitute(String exercise, List<String> equipment) async {
    final prompt = '''
      The user wants to perform the exercise: "$exercise".
      However, they only have the following equipment available: ${equipment.join(', ')}.
      
      Please suggest 1 biomechanically similar exercise substitute that targets the same primary muscle groups and uses the available equipment. 
      Explain briefly why it is a good substitute.
    ''';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    return response.text ?? "Could not generate substitute.";
  }

  Future<String> generatePlan(String goal, String experience, List<String> equipment) async {
    final prompt = '''
      Create a simple 3-day split workout plan for a user with:
      Goal: $goal
      Experience: $experience
      Equipment: ${equipment.join(', ')}
      
      Format as a list of exercises with recommended sets and reps.
    ''';
    
    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    return response.text ?? "Could not generate plan.";
  }
}