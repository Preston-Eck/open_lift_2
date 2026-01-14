import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;
  String _status = "Initializing OpenLift...";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulse = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _runInitialization();
  }

  Future<void> _runInitialization() async {
    // We gives a moment for the animation to be seen
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return;

    setState(() => _status = "Checking Authentication...");
    final auth = context.read<AuthService>();
    final db = context.read<DatabaseService>();
    final sync = context.read<SyncService>();

    // If authenticated, trigger sync in the background
    // We don't await it here to prevent blocking the UI/navigation if sync hangs
    if (auth.isAuthenticated) {
      setState(() => _status = "Starting Synchronization...");
      auth.updateLastSeen(); // Mark user as active for nudge system
      sync.syncAll(); // Fire and forget in splash
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;
    
    Navigator.pushReplacement(
      context, 
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulse,
              child: Image.asset(
                'assets/icon/app_icon.png', 
                width: 120, 
                height: 120,
                errorBuilder: (ctx, _, __) => const Icon(Icons.fitness_center, size: 80, color: Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _status,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFFE0E0E0),
                color: Colors.blueAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
