import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'saved_plans_screen.dart';
import 'global_search_screen.dart';
import 'wiki_screen.dart';
import 'analytics_screen.dart';
import 'body_metrics_screen.dart';
import 'strength_profile_screen.dart';
import '../services/database_service.dart';
import '../widgets/onboarding_progress_widget.dart';
import 'ai_coach_screen.dart'; // NEW

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    DashboardHome(),
    SavedPlansScreen(),
    WikiScreen(),
    AnalyticsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Plans'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Wiki'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Analytics'),
        ],
      ),
    );
  }
}

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Quick Statistics for the Home Tab
    return Scaffold(
      appBar: AppBar(
        title: const Text("OpenLift 2.0"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Onboarding Guide (Hides when complete)
            const OnboardingProgressWidget(),
            const SizedBox(height: 20),

            // Welcome / Quick Actions
            const Text("Quick Actions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context, 
                    "AI Coach", 
                    Icons.auto_awesome, 
                    Colors.purple, 
                    const AICoachScreen()
                  )
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard(
                    context, 
                    "Body Metrics", 
                    Icons.monitor_weight, 
                    Colors.orange, 
                    const BodyMetricsScreen()
                  )
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context, 
                    "Strength Profile", 
                    Icons.fitness_center, 
                    Colors.blue, 
                    const StrengthProfileScreen()
                  )
                ),
                // Add more buttons here if needed
                const SizedBox(width: 10),
                const Expanded(child: SizedBox()), // Spacer
              ],
            ),

            const SizedBox(height: 30),
            
            // Recent History Preview
            const Text("Recent Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder(
              future: context.read<DatabaseService>().getHistory(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final logs = snapshot.data as List;
                if (logs.isEmpty) return const Text("No recent workouts.");
                
                // Show top 5 logs
                return Column(
                  children: logs.take(5).map((log) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(log.exerciseName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${log.weight}lbs x ${log.reps}"),
                    trailing: Text(
                      log.timestamp.substring(5, 10), // MM-DD
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, Widget page) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}