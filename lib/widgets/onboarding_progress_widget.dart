import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../theme.dart';
import '../screens/settings_screen.dart'; // For Profile
import '../screens/equipment_manager_screen.dart'; // For Gym
import '../screens/plan_generator_screen.dart'; // For Plan

class OnboardingProgressWidget extends StatelessWidget {
  const OnboardingProgressWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return FutureBuilder<Map<String, bool>>(
      future: _checkProgress(db),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final status = snapshot.data!;
        final profileDone = status['profile']!;
        final gymDone = status['gym']!;
        final planDone = status['plan']!;

        // If all done, hide this widget to save space
        if (profileDone && gymDone && planDone) return const SizedBox.shrink();

        // Calculate progress (0.0 to 1.0)
        final progress = (profileDone ? 1 : 0) + (gymDone ? 1 : 0) + (planDone ? 1 : 0);
        final percent = progress / 3.0;

        return Card(
          elevation: 4,
          shadowColor: AppTheme.renewalTeal.withValues(alpha: 0.2),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Getting Started",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.foundationalSlate,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${(percent * 100).toInt()}%",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.renewalTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: AppTheme.foundationalSlate.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.renewalTeal),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Steps
                _buildStep(
                  context,
                  title: "Setup Profile",
                  isDone: profileDone,
                  icon: Icons.person,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                _buildStep(
                  context,
                  title: "Configure Gym",
                  isDone: gymDone,
                  icon: Icons.fitness_center,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EquipmentManagerScreen())),
                ),
                _buildStep(
                  context,
                  title: "Create Plan",
                  isDone: planDone,
                  icon: Icons.calendar_today,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanGeneratorScreen())),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep(BuildContext context, {required String title, required bool isDone, required IconData icon, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDone ? AppTheme.renewalTeal.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isDone ? Icons.check : icon,
          color: isDone ? AppTheme.renewalTeal : Colors.grey,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDone ? Colors.grey : AppTheme.foundationalSlate,
          decoration: isDone ? TextDecoration.lineThrough : null,
          fontWeight: isDone ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      trailing: isDone 
          ? null 
          : const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.motivationCoral),
      onTap: isDone ? null : onTap,
    );
  }

  Future<Map<String, bool>> _checkProgress(DatabaseService db) async {
    final profile = await db.getUserProfile();
    final equipment = await db.getOwnedItemNames();
    final plans = await db.getPlans();

    return {
      'profile': profile != null && profile['birth_date'] != null,
      'gym': equipment.isNotEmpty, // Consider "done" if at least one item is owned
      'plan': plans.isNotEmpty,
    };
  }
}
