import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';

// Screens
import 'screens/home_screen.dart'; 
import 'screens/style_guide_screen.dart'; 
import 'screens/analytics_screen.dart'; // <--- NEW IMPORT

// Services
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/gemini_service.dart';
import 'services/workout_player_service.dart';

// Theme
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Database Factory for Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 2. Load Environment Variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found. Supabase features may fail.");
  }

  // 3. Initialize Supabase
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  } catch (e) {
    debugPrint("Supabase Initialization Warning: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        Provider(create: (_) => GeminiService()), 
        ChangeNotifierProvider(create: (_) => WorkoutPlayerService()),
      ],
      child: const OpenLiftApp(),
    ),
  );
}

class OpenLiftApp extends StatelessWidget {
  const OpenLiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenLift',
      theme: AppTheme.lightTheme, 
      
      // --- PHASE 4 VERIFICATION ---
      // Temporarily set to AnalyticsScreen to verify the Heatmap logic.
      // Once verified, we will swap this back to HomeScreen() and add a navigation button.
      home: const AnalyticsScreen(), 
      
      debugShowCheckedModeBanner: false,
    );
  }
}