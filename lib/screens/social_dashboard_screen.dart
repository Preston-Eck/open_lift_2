import 'dart:convert'; // NEW: For jsonDecode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart'; // NEW: For unique IDs
import '../services/auth_service.dart';
import '../services/database_service.dart'; // NEW
import '../models/plan.dart'; // NEW

class SocialDashboardScreen extends StatefulWidget {
  const SocialDashboardScreen({super.key});

  @override
  State<SocialDashboardScreen> createState() => _SocialDashboardScreenState();
}

class _SocialDashboardScreenState extends State<SocialDashboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _publicPlans = [];

  @override
  void initState() {
    super.initState();
    _fetchPublicPlans();
  }

  Future<void> _fetchPublicPlans() async {
    try {
      final data = await Supabase.instance.client
          .from('plans')
          .select('*, profiles(username)') // Join with profiles to get owner name
          .eq('is_public', true)
          .order('updated_at', ascending: false)
          .limit(20);
      
      if (mounted) {
        setState(() {
          _publicPlans = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Social Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clonePlan(Map<String, dynamic> publicPlan) async {
    try {
      final db = context.read<DatabaseService>();
      
      // 1. Decode Schedule
      // Ensure we handle the JSON string correctly from Supabase
      final String jsonStr = publicPlan['schedule_json'];
      final List<dynamic> daysRaw = jsonDecode(jsonStr);
      final List<WorkoutDay> days = daysRaw.map((x) => WorkoutDay.fromMap(x)).toList();

      // 2. Create New Local Plan
      // MUST generate a new ID to avoid collisions with the remote ID
      final newPlan = WorkoutPlan(
        id: const Uuid().v4(),
        name: "${publicPlan['name']} (Imported)",
        goal: publicPlan['goal'] ?? "Imported Plan",
        type: publicPlan['type'] ?? "Strength",
        days: days,
      );

      // 3. Save Locally
      await db.savePlan(newPlan);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Imported '${newPlan.name}' to your library!"),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import Failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImportDialog(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Import ${plan['name']}?"),
        content: const Text("This will save a copy of this workout plan to your local device. You can then edit or start it."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clonePlan(plan);
            },
            child: const Text("Import"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.user;
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text("Community")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Profile Header
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        (profile?['username'] ?? "U").substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?['username'] ?? "User",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user?.email ?? "",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 2. Section: Community Plans
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Public Plans", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: _fetchPublicPlans, child: const Text("Refresh")),
              ],
            ),
            
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_publicPlans.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("No public plans found. Be the first to share one!", style: TextStyle(color: Colors.grey)),
              )
            else
              ..._publicPlans.map((plan) {
                final owner = plan['profiles']?['username'] ?? 'Unknown';
                final date = DateTime.parse(plan['updated_at']);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.download_for_offline, color: Colors.deepPurple), // Changed Icon to indicate Import
                    title: Text(plan['name'] ?? "Untitled Plan", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("By @$owner • ${plan['goal'] ?? 'General'}"),
                    trailing: Text(
                      DateFormat('MMM d').format(date),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () => _showImportDialog(plan), // Trigger Import Logic
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}