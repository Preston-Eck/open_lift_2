import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/plan.dart';
import '../models/session.dart';
import '../models/log.dart';
import 'workout_player_screen.dart';
import 'manual_plan_creator_screen.dart';

class SavedPlansScreen extends StatefulWidget {
  const SavedPlansScreen({super.key});

  @override
  State<SavedPlansScreen> createState() => _SavedPlansScreenState();
}

class _SavedPlansScreenState extends State<SavedPlansScreen> {
  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("My Plans")),
      body: FutureBuilder<List<WorkoutPlan>>(
        future: db.getPlans(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final plans = snapshot.data!;

          if (plans.isEmpty) return const Center(child: Text("No saved plans."));

          return ListView.builder(
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(plan.goal),
                  leading: const Icon(Icons.folder, color: Colors.blueAccent),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ManualPlanCreatorScreen(planToEdit: plan)),
                          );
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context, db, plan.id),
                      ),
                    ],
                  ),
                  children: [
                    ...plan.days.map((day) => ExpansionTile(
                      title: Text(day.name),
                      leading: const Icon(Icons.calendar_today, size: 20),
                      children: [
                        // The "Time Machine" View
                        PlanDayHistoryView(
                          planId: plan.id, 
                          day: day,
                          isHiit: plan.type == 'HIIT',
                          onSessionComplete: () {
                            // Trigger full rebuild to refresh history
                            setState(() {}); 
                          },
                        ),
                      ],
                    )),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, DatabaseService db, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Plan?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              db.deletePlan(id);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// --- HISTORY BROWSER & START INTERFACE ---
class PlanDayHistoryView extends StatefulWidget {
  final String planId;
  final WorkoutDay day; // Pass full day object to show targets
  final bool isHiit;
  final VoidCallback onSessionComplete;

  const PlanDayHistoryView({
    super.key, 
    required this.planId, 
    required this.day, 
    required this.isHiit,
    required this.onSessionComplete,
  });

  @override
  State<PlanDayHistoryView> createState() => _PlanDayHistoryViewState();
}

class _PlanDayHistoryViewState extends State<PlanDayHistoryView> {
  List<WorkoutSession> _sessions = [];
  bool _isLoading = true;
  
  // Index -1 = "New Session" (Target)
  // Index 0+ = History (0 is newest)
  int _viewIndex = -1; 
  List<LogEntry> _historyLogs = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  // Fix: Re-load if the day changes (though usually this widget rebuilds)
  @override
  void didUpdateWidget(covariant PlanDayHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) {
      _loadSessions();
    }
  }

  Future<void> _loadSessions() async {
    final db = context.read<DatabaseService>();
    final sessions = await db.getSessionsForPlanDay(widget.planId, widget.day.name);
    
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
        // Default to "New Session" (-1)
        _viewIndex = -1; 
      });
    }
  }

  Future<void> _loadLogsForSession(String sessionId) async {
    final db = context.read<DatabaseService>();
    final logs = await db.getLogsForSession(sessionId);
    if (mounted) {
      setState(() {
        _historyLogs = logs;
      });
    }
  }

  void _cycleView(int direction) {
    // direction: 1 (Older), -1 (Newer)
    int newIndex = _viewIndex + direction;

    // Bounds check
    // Max index = _sessions.length - 1
    // Min index = -1 (New Session)
    
    if (newIndex >= -1 && newIndex < _sessions.length) {
      setState(() => _viewIndex = newIndex);
      
      if (newIndex >= 0) {
        _loadLogsForSession(_sessions[newIndex].id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final bool isNewSessionMode = _viewIndex == -1;
    String headerTitle = "NEW SESSION";
    String headerDate = "Target";

    if (!isNewSessionMode) {
      final session = _sessions[_viewIndex];
      headerTitle = "HISTORY";
      headerDate = DateFormat('MMM d, yyyy').format(session.startTime);
    }

    return Column(
      children: [
        // --- 1. Cycle Header ---
        Container(
          color: isNewSessionMode ? Colors.green.withValues(alpha: 0.1) : Colors.grey[100],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Arrow (Go Older)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _viewIndex < _sessions.length - 1 ? () => _cycleView(1) : null,
              ),
              
              // Center Label
              Column(
                children: [
                  Text(headerTitle, style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 10, 
                    color: isNewSessionMode ? Colors.green : Colors.grey
                  )),
                  Text(headerDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              
              // Right Arrow (Go Newer)
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                // If at -1, disabled. If at 0, goes to -1.
                onPressed: _viewIndex > -1 ? () => _cycleView(-1) : null,
              ),
            ],
          ),
        ),

        // --- 2. Action Button (Only in New Session Mode) ---
        if (isNewSessionMode)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("START SESSION"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => WorkoutPlayerScreen(
                      workoutDay: widget.day,
                      planId: widget.planId,
                      isHiit: widget.isHiit
                    ))
                  );
                  // Refresh history when they return
                  await _loadSessions();
                  widget.onSessionComplete();
                },
              ),
            ),
          ),

        // --- 3. The Details List ---
        // If New: Show Plan Targets
        // If History: Show Actual Logs
        isNewSessionMode ? _buildTargetList() : _buildHistoryList(),
      ],
    );
  }

  Widget _buildTargetList() {
    if (widget.day.exercises.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("No exercises."));
    
    return Column(
      children: widget.day.exercises.map((ex) => ListTile(
        dense: true,
        leading: const Icon(Icons.fitness_center, size: 16, color: Colors.grey),
        title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text("${ex.sets} sets x ${ex.reps}"),
        trailing: ex.secondsPerSet > 0 ? Text("${ex.secondsPerSet}s") : null,
      )).toList(),
    );
  }

  Widget _buildHistoryList() {
    if (_historyLogs.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("No logs recorded for this session."));

    // Group logs by exercise
    final Map<String, List<String>> groups = {};
    for (var log in _historyLogs) {
      if (!groups.containsKey(log.exerciseName)) groups[log.exerciseName] = [];
      groups[log.exerciseName]!.add("${log.weight.toInt()}x${log.reps}");
    }

    return Column(
      children: groups.entries.map((entry) => ListTile(
        dense: true,
        title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(entry.value.join(", ")),
        leading: const Icon(Icons.history, size: 16, color: Colors.blueGrey),
      )).toList(),
    );
  }
}