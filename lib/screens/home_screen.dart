import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/logger_service.dart';
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
import 'social_dashboard_screen.dart';
import 'exercise_auditor_screen.dart'; // ✅ FIXED: Added missing import

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
            icon: const Icon(Icons.cloud_sync),
            tooltip: "Sync Data",
            onPressed: () {
              final sync = Provider.of<SyncService>(context, listen: false);
              sync.syncAll();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sync Started...")));
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: Icon(auth.isAuthenticated ? Icons.logout : Icons.person),
            tooltip: auth.isAuthenticated ? "Sign Out" : "Sign In",
            onPressed: () {
              if (auth.isAuthenticated) {
                auth.signOut();
              } else {
                _showAuthDialog(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(context, auth),
            const SizedBox(height: 20),
            
            // --- SOCIAL ENTRY POINT ---
            if (auth.isAuthenticated) ...[
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialDashboardScreen())),
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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
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

            // Consolidated Equipment Section with Auditor Button
            _buildEquipmentList(context, db),
            const SizedBox(height: 20),
            
            // --- ACTION BUTTONS ---
            ElevatedButton.icon(
              icon: const Icon(Icons.bolt),
              label: const Text("Create New Plan with AI"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanGeneratorScreen())),
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
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualPlanCreatorScreen())),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text("View Saved Plans"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPlansScreen())),
            ),
             const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.show_chart),
              label: const Text("Exercise Progress Scatter Plot"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseAnalyticsScreen())),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.monitor_weight),
                    label: const Text("Body Stats"),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BodyMetricsScreen())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.fitness_center),
                    label: const Text("Strength"),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StrengthProfileScreen())),
                  ),
                ),
              ],
            ),
             const SizedBox(height: 10),
             ElevatedButton.icon(
              icon: const Icon(Icons.menu_book),
              label: const Text("Exercise Wiki"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WikiScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, AuthService auth) {
    final username = auth.username;
    final email = auth.user?.email;
    final isGuest = !auth.isAuthenticated;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle, size: 40),
              title: Text(
                username != null ? "Hi, $username!" : (email != null ? "Welcome back!" : "Welcome, Guest"),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(email ?? "Join the community to sync data and track progress."),
            ),
            if (isGuest) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showAuthDialog(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  child: const Text("Sign In / Join"),
                ),
              ),
            ]
          ],
        ),
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
            // ✅ FIXED: Consolidated Auditor and Manage buttons here
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.fact_check, color: Colors.deepPurple),
                  tooltip: "Audit Database",
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseAuditorScreen()));
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("Manage"),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EquipmentManagerScreen())),
                ),
              ],
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
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EquipmentManagerScreen())),
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

  void _showAuthDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final confirmPassController = TextEditingController(); 
    final userController = TextEditingController(); 
    
    showDialog(
      context: context,
      builder: (ctx) {
        bool isSignup = false;
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isSignup ? "Create Account" : "Welcome Back"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController, 
                      decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passController, 
                      decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock)), 
                      obscureText: true
                    ),
                    
                    if (isSignup) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: confirmPassController, 
                        decoration: const InputDecoration(labelText: "Confirm Password", prefixIcon: Icon(Icons.lock_outline)), 
                        obscureText: true
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: userController, 
                        decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  TextButton(
                    onPressed: () => setState(() => isSignup = !isSignup),
                    child: Text(isSignup ? "Already have an account? Log In" : "Need an account? Sign Up"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final auth = ctx.read<AuthService>();
                      setState(() => isLoading = true);

                      try {
                        if (isSignup) {
                          if (passController.text != confirmPassController.text) {
                            throw Exception("Passwords do not match.");
                          }
                          if (userController.text.isEmpty) {
                            throw Exception("Username is required.");
                          }
                          if (passController.text.length < 6) {
                            throw Exception("Password must be at least 6 characters.");
                          }

                          await auth.signUp(emailController.text, passController.text, userController.text);
                        } else {
                          await auth.signIn(emailController.text, passController.text);
                        }
                        
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e, stack) {
                        LoggerService().log("Auth Error (${isSignup ? 'SignUp' : 'Login'})", e, stack);
                        
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll("Exception: ", "")),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) setState(() => isLoading = false);
                      }
                    },
                    child: Text(isSignup ? "Sign Up" : "Log In"),
                  ),
                ]
              ],
            );
          },
        );
      },
    );
  }
}