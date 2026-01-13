import 'dart:async';
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ NEW: For kIsWeb
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; 
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // ✅ Web DB
import 'package:firebase_core/firebase_core.dart'; // NEW

import 'services/database_service.dart';
import 'services/gemini_service.dart';
import 'services/logger_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart'; 
import 'services/social_service.dart'; 
import 'services/realtime_service.dart'; 
import 'services/workout_player_service.dart'; 
import 'services/notification_service.dart'; // NEW
import 'theme.dart';
import 'screens/home_screen.dart'; 

Future<void> main() async {
  runZonedGuarded(() async {
    debugPrint("🚀 App Starting...");
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase
    try {
      await Firebase.initializeApp();
      debugPrint("✅ Firebase Initialized");
    } catch (e) {
      debugPrint("⚠️ Firebase Init Failed (likely missing config): $e");
    }

    debugPrint("✅ Widgets Binding Initialized");
    await LoggerService().init();
    debugPrint("✅ Logger Initialized");

    if (kIsWeb) {
      debugPrint("🌐 Initializing Web Database...");
      // Using the more explicit web initialization
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint("📦 Initializing FFI Database...");
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    try {
      debugPrint("📄 Loading app.env...");
      await dotenv.load(fileName: "app.env");
      debugPrint("✅ app.env Loaded");
      
      final url = dotenv.env['SUPABASE_URL'];
      final key = dotenv.env['SUPABASE_ANON_KEY'];
      
      if (url == null || key == null) {
        throw Exception("Missing Supabase URL or Anon Key in app.env");
      }

      debugPrint("🔗 Initializing Supabase...");
      await Supabase.initialize(
        url: url,
        anonKey: key,
      );
      debugPrint("✅ Supabase Initialized");
    } catch (e, stack) {
      debugPrint("❌ Initialization Error: $e");
      LoggerService().log("Startup Error", e, stack);
    }

    debugPrint("🏃 Running App...");
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          Provider(create: (_) => GeminiService()),
          
          // 1. Database depends on Auth
          ChangeNotifierProxyProvider<AuthService, DatabaseService>(
            create: (_) => DatabaseService(),
            update: (_, auth, db) {
              // Whenever Auth changes, update the DB's user ID
              db?.setUserId(auth.user?.id); 
              return db!;
            },
          ),

          // 2. Sync depends on DB and Auth
          ChangeNotifierProxyProvider2<DatabaseService, AuthService, SyncService>(
            create: (ctx) => SyncService(ctx.read<DatabaseService>(), ctx.read<AuthService>()),
            update: (ctx, db, auth, sync) => sync ?? SyncService(db, auth),
          ),
          
          // 3. Social depends on Auth
          ProxyProvider<AuthService, SocialService>(
            update: (_, auth, __) => SocialService(auth),
          ),

          // 4. Realtime depends on Auth
          ChangeNotifierProxyProvider<AuthService, RealtimeService>(
            create: (context) => RealtimeService(Provider.of<AuthService>(context, listen: false)),
            update: (_, auth, realtime) => RealtimeService(auth),
          ),

          // 5. Workout Player (Global State)
          ChangeNotifierProvider(create: (_) => WorkoutPlayerService()),

          // 6. Notifications
          Provider(create: (_) => NotificationService()),
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
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    // Wait for frame to ensure providers are available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifs = context.read<NotificationService>();
      final auth = context.read<AuthService>();
      
      await notifs.init();
      final token = await notifs.getToken();
      if (token != null) {
        await auth.updateFcmToken(token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenLift 2.0',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(), 
      debugShowCheckedModeBanner: false,
    );
  }
}