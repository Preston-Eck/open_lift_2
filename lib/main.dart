import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'services/workout_player_service.dart';
import 'services/gemini_service.dart';
import 'screens/home_screen.dart';
import 'screens/workout_player_screen.dart';
import 'screens/wiki_screen.dart';
import 'screens/analytics_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Windows Database
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Supabase (Replace with your actual keys)
  await Supabase.initialize(
    url: 'https://dwtpwfwlviustmkspwms.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR3dHB3Zndsdml1c3Rta3Nwd21zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczMDY1MDksImV4cCI6MjA4Mjg4MjUwOX0.1Uyq6uvOBTFoBJHRu1peBcbL_gSppExTpjEn4lGs_aM',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => WorkoutPlayerService()),
        Provider(create: (_) => GeminiService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenFit Wiki',
      theme: AppTheme.darkTheme,
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const WikiScreen(),
    const AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Workout'),
          NavigationDestination(icon: Icon(Icons.library_books), label: 'Wiki'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Analytics'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkoutPlayerScreen()),
              ),
              child: const Icon(Icons.play_arrow),
            )
          : null,
    );
  }
}