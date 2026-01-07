import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database_service.dart';
import 'services/gemini_service.dart';
import 'services/logger_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart'; // NEW
import 'theme.dart';
import 'screens/home_screen.dart'; // Changed to HomeScreen to match flow

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
          ChangeNotifierProvider(create: (_) => AuthService()),
          Provider(create: (_) => GeminiService()),
          // NEW: SyncService (Dependent on DB and Auth)
          ProxyProvider2<DatabaseService, AuthService, SyncService>(
            update: (_, db, auth, __) => SyncService(db, auth),
          ),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    LoggerService().log("Async Error", error, stack);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Trigger Sync after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // We can't access Provider here easily without context in build, 
        // so usually we do this in the first screen or a splash screen.
        // For simplicity, HomeScreen will trigger it.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenLift 2.0',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(), // Ensure we point to the main dashboard container
      debugShowCheckedModeBanner: false,
    );
  }
}