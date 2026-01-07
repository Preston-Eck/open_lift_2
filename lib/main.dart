import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database_service.dart';
import 'services/gemini_service.dart';
import 'services/logger_service.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart'; // Ensure this matches your file structure

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await LoggerService().init();

    try {
      await dotenv.load(fileName: ".env");
      
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      );
    } catch (e, stack) {
      LoggerService().log("Startup Error", e, stack);
    }

    FlutterError.onError = (FlutterErrorDetails details) {
      LoggerService().log("Flutter Error", details.exception, details.stack);
      FlutterError.presentError(details);
    };

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DatabaseService()),
          Provider(create: (_) => GeminiService()),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    LoggerService().log("Async Error", error, stack);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenLift 2.0',
      theme: AppTheme.lightTheme,
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}