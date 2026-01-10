import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../services/social_service.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/plan.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInbox();
  }

  Future<void> _fetchInbox() async {
    try {
      final notifs = await context.read<SocialService>().getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Inbox Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAcceptGym(String notificationId, Map<String, dynamic> payload) async {
    final gymId = payload['gym_id'];
    final userId = context.read<AuthService>().user!.id;
    
    try {
      // 1. Update Membership on Supabase
      await Supabase.instance.client
          .from('gym_members')
          .update({'status': 'accepted'})
          .eq('gym_id', gymId)
          .eq('user_id', userId);
          
      // 2. Mark Notification Read
      await context.read<SocialService>().markNotificationRead(notificationId);
      
      // 3. Trigger Local Sync (via Gym Selector or Sync Service if available)
      // Ideally, trigger a full sync. For now, we just update UI.
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gym Joined!")));
        _fetchInbox();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _handleImportPlan(String notificationId, Map<String, dynamic> payload) async {
    final planData = payload['plan_data'];
    if (planData == null) return;

    try {
      final db = context.read<DatabaseService>();
      
      // Parse Plan
      // Check if schedule_json is string or object (Supabase 'json' column can be either depending on how it was inserted)
      dynamic schedule = planData['schedule_json'];
      List<dynamic> daysRaw;
      if (schedule is String) {
        daysRaw = jsonDecode(schedule);
      } else {
        daysRaw = schedule;
      }

      final List<WorkoutDay> days = daysRaw.map((x) => WorkoutDay.fromMap(x)).toList();

      final newPlan = WorkoutPlan(
        id: const Uuid().v4(),
        name: "${planData['name']} (Shared)",
        goal: planData['goal'] ?? "Shared Plan",
        type: planData['type'] ?? "General",
        days: days,
      );

      await db.savePlan(newPlan);
      await context.read<SocialService>().markNotificationRead(notificationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan Imported!")));
        _fetchInbox();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import Error: $e")));
    }
  }

  Future<void> _deleteNotif(String id) async {
    await context.read<SocialService>().deleteNotification(id);
    _fetchInbox();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_notifications.isEmpty) return const Center(child: Text("Inbox is empty.", style: TextStyle(color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: _fetchInbox,
      child: ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (ctx, i) {
          final notif = _notifications[i];
          final type = notif['type'];
          final payload = notif['payload_json'] ?? {};
          final isRead = notif['is_read'] ?? false;

          IconData icon = Icons.notifications;
          Color color = Colors.grey;
          String title = "Notification";
          String subtitle = "";
          Widget? action;

          if (type == 'gym_invite') {
            icon = Icons.fitness_center;
            color = Colors.blue;
            title = "Gym Invite";
            subtitle = "${payload['inviter_name']} invited you to join '${payload['gym_name']}'";
            action = ElevatedButton(
              onPressed: () => _handleAcceptGym(notif['id'], payload),
              child: const Text("Join"),
            );
          } else if (type == 'plan_share') {
            icon = Icons.description;
            color = Colors.green;
            title = "Plan Shared";
            subtitle = "${payload['sender_name']} shared '${payload['plan_name']}' with you.";
            action = ElevatedButton(
              onPressed: () => _handleImportPlan(notif['id'], payload),
              child: const Text("Import"),
            );
          }

          return Dismissible(
            key: Key(notif['id']),
            background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (_) => _deleteNotif(notif['id']),
            child: Card(
              color: isRead ? Colors.grey.withValues(alpha: 0.1) : Colors.white,
              child: ListTile(
                leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(icon, color: color)),
                title: Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text(subtitle),
                trailing: action,
              ),
            ),
          );
        },
      ),
    );
  }
}
