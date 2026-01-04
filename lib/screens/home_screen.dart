import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'equipment_manager_screen.dart';
import 'plan_generator_screen.dart';
import 'saved_plans_screen.dart'; // Import for saved plans
import 'manual_plan_creator_screen.dart'; // FIX: Corrected import typo

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
            _buildWelcomeCard(auth.user?.email),
            const SizedBox(height: 20),
            _buildEquipmentList(context, db),
            const SizedBox(height: 20),
            
            // --- Action Buttons ---
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
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(String? email) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_circle, size: 40),
        title: Text(email != null ? "Welcome back!" : "Welcome, Guest"),
        subtitle: Text(email ?? "Sign in to sync your plans"),
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
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sign In / Sign Up"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: passController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ctx.read<AuthService>().signUp(emailController.text, passController.text);
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