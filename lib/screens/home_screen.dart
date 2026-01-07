import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'equipment_manager_screen.dart';
import 'plan_generator_screen.dart';
import 'saved_plans_screen.dart';
import 'manual_plan_creator_screen.dart';
import 'body_metrics_screen.dart';
import 'strength_profile_screen.dart';
import 'analytics_screen.dart'; 
import 'settings_screen.dart';
import 'wiki_screen.dart';
import 'exercise_analytics_screen.dart';
import 'global_search_screen.dart';
import 'social_dashboard_screen.dart'; // NEW IMPORT

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          if (auth.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => auth.signOut(),
            )
          else
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: () => _showLoginDialog(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(auth.user?.email, auth.username),
            const SizedBox(height: 20),
            
            // --- SOCIAL ENTRY POINT ---
            if (auth.isAuthenticated) ...[
              GestureDetector(
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialDashboardScreen()));
                },
                child: Card(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  child: const ListTile(
                    leading: Icon(Icons.public, color: Colors.deepPurple, size: 30),
                    title: Text("Community & Friends", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    subtitle: Text("Find plans, view leaderboards, and connect"),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.deepPurple),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            GestureDetector(
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              },
              child: Card(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                child: const ListTile(
                  leading: Icon(Icons.show_chart, color: Colors.blueAccent, size: 30),
                  title: Text("View Analytics", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  subtitle: Text("Track your volume and consistency trends"),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blueAccent),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildEquipmentList(context, db),
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              icon: const Icon(Icons.bolt),
              label: const Text("Create New Plan with AI"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanGeneratorScreen()));
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_note),
              label: const Text("Create Manual Plan"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blueGrey, 
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualPlanCreatorScreen()));
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text("View Saved Plans"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPlansScreen()));
              },
            ),
             const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.show_chart),
              label: const Text("Exercise Progress Scatter Plot"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseAnalyticsScreen()));
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.monitor_weight),
                    label: const Text("Body Stats"),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BodyMetricsScreen()));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.fitness_center),
                    label: const Text("Strength"),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StrengthProfileScreen()));
                    },
                  ),
                ),
              ],
            ),
             const SizedBox(height: 10),
             ElevatedButton.icon(
              icon: const Icon(Icons.menu_book),
              label: const Text("Exercise Wiki"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const WikiScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(String? email, String? username) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_circle, size: 40),
        title: Text(username != null ? "Hi, $username!" : (email != null ? "Welcome back!" : "Welcome, Guest")),
        subtitle: Text(email ?? "Sign in to join the community"),
      ),
    );
  }

  Widget _buildEquipmentList(BuildContext context, DatabaseService db) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("My Equipment", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text("Manage"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EquipmentManagerScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<String>>(
          future: db.getOwnedEquipment(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final equipment = snapshot.data!;
            
            if (equipment.isEmpty) {
              return ActionChip(
                label: const Text("Tap to set up your Gym"),
                avatar: const Icon(Icons.add),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EquipmentManagerScreen()),
                  );
                },
              );
            }

            return Wrap(
              spacing: 8.0,
              children: equipment.map((e) => Chip(label: Text(e))).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showLoginDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final userController = TextEditingController(); // NEW: For Sign Up
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sign In / Sign Up"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            const SizedBox(height: 8),
            TextField(controller: passController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            const SizedBox(height: 8),
            TextField(controller: userController, decoration: const InputDecoration(labelText: "Username (Sign Up Only)")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (userController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Username required for Sign Up")));
                return;
              }
              try {
                // UPDATED: Pass 3 arguments
                await ctx.read<AuthService>().signUp(emailController.text, passController.text, userController.text);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text("Sign Up"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ctx.read<AuthService>().signIn(emailController.text, passController.text);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text("Log In"),
          ),
        ],
      ),
    );
  }
}