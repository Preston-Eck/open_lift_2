import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/social_service.dart'; // NEW
import '../models/gym_profile.dart';
import '../theme.dart';
import 'user_picker_dialog.dart'; // NEW

class GymSelector extends StatelessWidget {
  const GymSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return FutureBuilder<List<GymProfile>>(
      future: db.getGymProfiles(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final gyms = snapshot.data!;
        
        // ✅ FIXED: Safely handle empty list
        if (gyms.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.warning, color: Colors.orange),
              title: Text("No Gym Profile Found"),
              subtitle: Text("Please create one in settings."),
            ),
          );
        }

        // Determine active gym (or default)
        GymProfile activeGym;
        if (db.currentGymId != null) {
          activeGym = gyms.firstWhere(
            (g) => g.id == db.currentGymId, 
            orElse: () => gyms.first
          );
        } else {
          activeGym = gyms.firstWhere(
            (g) => g.isDefault, 
            orElse: () => gyms.first
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          color: AppTheme.renewalTeal.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showGymSwitcher(context, gyms, activeGym.id, db),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.renewalTeal, size: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("CURRENT LOCATION", style: TextStyle(fontSize: 10, color: AppTheme.foundationalSlate.withValues(alpha: 0.6), fontWeight: FontWeight.bold)),
                      Text(activeGym.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.renewalTeal)),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.expand_more, color: AppTheme.renewalTeal),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGymSwitcher(BuildContext context, List<GymProfile> gyms, String activeId, DatabaseService db) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Gym Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              ...gyms.map((gym) => ListTile(
                leading: Icon(
                  gym.id == activeId ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: gym.id == activeId ? AppTheme.renewalTeal : Colors.grey,
                ),
                title: Text(gym.displayName, style: TextStyle(fontWeight: gym.id == activeId ? FontWeight.bold : FontWeight.normal)),
                subtitle: gym.isShared ? const Text("Shared Gym") : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!gym.isShared)
                      IconButton(
                        icon: const Icon(Icons.person_add, color: Colors.blueAccent),
                        tooltip: "Invite Friend",
                        onPressed: () => _inviteFriend(context, gym),
                      ),
                    if (gym.isDefault) const Chip(label: Text("Default", style: TextStyle(fontSize: 10))),
                  ],
                ),
                onTap: () {
                  db.setCurrentGym(gym.id);
                  Navigator.pop(ctx);
                },
              )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add, color: AppTheme.motivationCoral),
                title: const Text("Create New Profile", style: TextStyle(color: AppTheme.motivationCoral, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateDialog(context, db);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _inviteFriend(BuildContext context, GymProfile gym) async {
    // Close the bottom sheet first so the dialog can appear clearly
    Navigator.pop(context);

    final friendId = await showDialog<String>(
      context: context,
      builder: (ctx) => const UserPickerDialog(title: "Invite to Gym"),
    );

    if (friendId != null && context.mounted) {
      await context.read<SocialService>().sendGymInvite(gym.id, gym.name, friendId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invited friend to ${gym.name}!")));
      }
    }
  }

  void _showCreateDialog(BuildContext context, DatabaseService db) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Gym Profile"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Gym Name", hintText: "e.g. Hotel Gym"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newId = await db.createGymProfile(controller.text);
                db.setCurrentGym(newId); // Auto-switch to new gym
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }
}