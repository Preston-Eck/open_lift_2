import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';
import '../services/gemini_service.dart';
import '../services/workout_player_service.dart'; 
import '../services/realtime_service.dart';
import '../services/sync_service.dart'; // NEW
import '../models/log.dart';
import '../models/plan.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import 'exercise_detail_screen.dart';

class WorkoutPlayerScreen extends StatefulWidget {
  final WorkoutDay? workoutDay;
  final String? planId;
  final bool isHiit;
  final String? versusRoomId; 
  final int initialStepIndex; 
  final String? resumeSessionId; 

  const WorkoutPlayerScreen({
    super.key, 
    this.workoutDay, 
    this.planId, 
    this.isHiit = false,
    this.versusRoomId,
    this.initialStepIndex = 0,
    this.resumeSessionId,
  });

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  late String _sessionId;
  Map<String, String> _aliases = {}; 
  Map<String, double> _oneRepMaxes = {}; 
  Map<String, Exercise> _exerciseMetadata = {}; 

  // Sequential Flow Data
  List<WorkoutExercise> _flatFlow = []; 
  int _currentStepIndex = 0;
  double _sessionTotalTonnage = 0; 
  double _currentRpe = 7.0; 
  bool _autoApplySmartRest = true; 
  final List<Key> _flowKeys = []; // Stable keys for reordering
  final Set<Key> _completedKeys = {}; // Track completed sets by Key
   // Controllers for current set
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sessionId = widget.resumeSessionId ?? Uuid().v4(); 
    _currentStepIndex = widget.initialStepIndex;
    if (widget.resumeSessionId == null) _initSession();
    _loadData();
    _generateFlatFlow();
    
    // Auto-start the service and sync draft
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<WorkoutPlayerService>();
      
      // Load current draft if exists
      if (player.draftWeight.isNotEmpty) _weightController.text = player.draftWeight;
      if (player.draftReps.isNotEmpty) _repsController.text = player.draftReps;
      setState(() {
         _currentRpe = player.draftRpe;
      });

      // Add listeners to preserve state
      _weightController.addListener(() {
         context.read<WorkoutPlayerService>().updateDraft(_weightController.text, null, null);
      });
      _repsController.addListener(() {
         context.read<WorkoutPlayerService>().updateDraft(null, _repsController.text, null);
      });

      player.startWorkout();
      
      // Start Versus Mode if room ID exists
      if (widget.versusRoomId != null) {
        context.read<RealtimeService>().joinVersus(widget.versusRoomId!);
      }
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    // Leave versus mode on exit
    if (widget.versusRoomId != null) {
      context.read<RealtimeService>().leaveVersus();
    }
    super.dispose();
  }

  Future<void> _logSet(WorkoutExercise ex) async {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    final setTonnage = weight * reps;

    final log = LogEntry(
      id: Uuid().v4(),
      exerciseId: ex.name,
      exerciseName: ex.name,
      weight: weight,
      reps: reps,
      volumeLoad: setTonnage,
      duration: 0, 
      timestamp: DateTime.now().toIso8601String(),
      sessionId: _sessionId,
      rpe: _currentRpe,
    );

    final isPr = await context.read<DatabaseService>().logSet(log);
    
    if (isPr) {
      _showPRCelebration(ex.name, weight, reps);
    }
    
    // Update local tonnage and broadcast
    setState(() {
      _sessionTotalTonnage += setTonnage;
    });

    if (widget.versusRoomId != null) {
      context.read<RealtimeService>().broadcastTonnage(widget.versusRoomId!, _sessionTotalTonnage);
    }
    
    // Auto-apply Smart Rest logic
    if (_autoApplySmartRest && _currentRpe >= 9) {
       context.read<WorkoutPlayerService>().setNextRestAdjust(30); // Add 30s automatically
    }

    // Track completion
    setState(() {
      _completedKeys.add(_flowKeys[_currentStepIndex]);
    });

    // Clear draft in service
    context.read<WorkoutPlayerService>().clearDraft(keepWeight: true);

    // Clear local for next set
    _repsController.clear();
    setState(() {
      _currentRpe = 7.0;
    });
  }

  Future<void> _saveDefaultRest(WorkoutPlayerService player) async {
    if (widget.planId == null) return;
    
    final db = context.read<DatabaseService>();
    final plan = await db.getPlanById(widget.planId!);
    if (plan == null) return;

    final currentExercise = _flatFlow[_currentStepIndex];
    
    // Find and update the exercise in the plan
    bool found = false;
    for (var day in plan.days) {
      if (day.name == widget.workoutDay?.name) {
        for (var ex in day.exercises) {
          if (ex.name == currentExercise.name) {
            // Update restSeconds
            // Note: WorkoutExercise is immutable, we need to handle this.
            // For now, let's assume we can at least find it.
            // If it's immutable, we'd need to recreate the day/plan.
            found = true;
            break;
          }
        }
      }
    }

    if (found) {
       // Since WorkoutExercise is immutable in our model, we recreate the objects
       final updatedDays = plan.days.map((day) {
         if (day.name == widget.workoutDay?.name) {
           final updatedExercises = day.exercises.map((ex) {
             if (ex.name == currentExercise.name) {
                return WorkoutExercise(
                  name: ex.name,
                  sets: ex.sets,
                  reps: ex.reps,
                  restSeconds: player.timerSeconds, // The currently adjusted time
                  intensity: ex.intensity,
                  secondsPerSet: ex.secondsPerSet,
                  metricType: ex.metricType,
                  circuitGroupId: ex.circuitGroupId,
                );
             }
             return ex;
           }).toList();
           return WorkoutDay(name: day.name, exercises: updatedExercises);
         }
         return day;
       }).toList();

       final updatedPlan = WorkoutPlan(
         id: plan.id,
         name: plan.name,
         goal: plan.goal,
         type: plan.type,
         days: updatedDays,
       );

       await db.savePlan(updatedPlan);
       
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Rest updated to ${player.timerSeconds}s for ${currentExercise.name}"))
         );
       }
    }
  }

  void _jumpToStep(int index) {
    if (index < 0 || index >= _flatFlow.length) return;
    setState(() {
      _currentStepIndex = index;
      _weightController.clear();
      _repsController.clear();
      _currentRpe = 7.0;
    });
    final player = context.read<WorkoutPlayerService>();
    player.resetToWork();
  }

  void _showPRCelebration(String exercise, double weight, int reps) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber.shade700,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.stars, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("NEW PERSONAL RECORD!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("$exercise: ${weight.toInt()} lbs x $reps", style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateFlatFlow() {
    if (widget.workoutDay == null) return;
    final exercises = widget.workoutDay!.exercises;
    
    // Group by circuitGroupId
    // For MVP: We process them in groups as they appear in the list.
    // If consecutive exercises have same group ID, we interleave.
    
    List<WorkoutExercise> flow = [];
    int i = 0;
    while (i < exercises.length) {
      final current = exercises[i];
      if (current.circuitGroupId != null && current.circuitGroupId!.isNotEmpty) {
        // Find all in this group
        final groupId = current.circuitGroupId;
        final group = exercises.skip(i).takeWhile((e) => e.circuitGroupId == groupId).toList();
        
        // Interleave sets
        int maxSets = group.map((e) => e.sets).reduce((a, b) => a > b ? a : b);
        for (int s = 0; s < maxSets; s++) {
          for (var ex in group) {
            if (s < ex.sets) flow.add(ex);
          }
        }
        i += group.length;
      } else {
        // Just add all sets for this exercise
        for (int s = 0; s < current.sets; s++) {
          flow.add(current);
        }
        i++;
      }
    }
    _flatFlow = flow;
    _flowKeys.clear();
    for (var i = 0; i < _flatFlow.length; i++) {
      _flowKeys.add(UniqueKey());
    }
  }

  Future<void> _initSession() async {
    if (widget.workoutDay != null) {
      final session = WorkoutSession(
        id: _sessionId,
        planId: widget.planId ?? 'unknown',
        dayName: widget.workoutDay!.name,
        startTime: DateTime.now(),
      );
      context.read<DatabaseService>().startSession(session);
    }
  }

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    final aliases = await db.getAliases();
    Map<String, double> maxes = {};
    if (widget.workoutDay != null) {
      for (var ex in widget.workoutDay!.exercises) {
        // 1. One Rep Maxes
        final data = await db.getLatestOneRepMaxDetailed(ex.name);
        if (data != null) maxes[ex.name] = data['weight'];

        // 2. Metadata (Pre-load)
        // Check custom first
        Exercise? meta = await db.findCustomExerciseByName(ex.name);
        if (meta == null) {
          // Check Supabase (standard list)
          try {
            final response = await Supabase.instance.client
                .from('exercises')
                .select()
                .ilike('name', ex.name)
                .limit(1)
                .maybeSingle();
            if (response != null) meta = Exercise.fromJson(response);
          } catch (_) {}
        }
        if (meta != null) _exerciseMetadata[ex.name] = meta;
      }
    }
    if (mounted) setState(() { 
      _aliases = aliases; 
      _oneRepMaxes = maxes;
    });
  }

  Future<void> _finishWorkout() async {
    final db = context.read<DatabaseService>();
    final gemini = context.read<GeminiService>();
    final sync = context.read<SyncService>();
    
    // 1. Fetch Session Logs for AI Analysis
    final logs = await db.getLogsForSession(_sessionId);
    
    // 2. Clear focus/player
    context.read<WorkoutPlayerService>().finishWorkout();
    await db.endSession(_sessionId, DateTime.now());

    // 2.5 Auto-Sync (NEW)
    sync.syncAll();

    // 3. Show AI Insight (Blitz)
    if (mounted && logs.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => FutureBuilder<String>(
          future: gemini.generatePostWorkoutInsight(logs),
          builder: (ctx, snapshot) {
            final insight = snapshot.data ?? "...";
            return AlertDialog(
              backgroundColor: Colors.blueGrey.shade900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text("COACH BLITZ", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: snapshot.connectionState == ConnectionState.waiting
                  ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: Colors.amber)))
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (logs.any((l) => l.isPr)) ...[
                            const Text("🎉 ACHIEVEMENTS:", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 8),
                            ...logs.where((l) => l.isPr).map((l) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text("• ${l.exerciseName} PR: ${l.weight.toInt()}x${l.reps}", style: const TextStyle(color: Colors.white, fontSize: 14)),
                            )),
                            const Divider(color: Colors.white24, height: 24),
                          ],
                          Text(insight, style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close Dialog
                    Navigator.of(context).pop(); // Close Player
                  },
                  child: const Text("DONE", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ),
      );
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<WorkoutPlayerService>();
    final isResting = player.state == WorkoutState.resting;
    final isCountdown = player.state == WorkoutState.countdown;

    return Scaffold(
      backgroundColor: Colors.black, // Focused dark mode for player
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            // Save & Exit logic
            final db = context.read<DatabaseService>();
            await db.pauseSession(
              _sessionId, 
              widget.planId ?? 'unknown', 
              widget.workoutDay?.name ?? 'Unknown Day', 
              _currentStepIndex,
              {'tonnage': _sessionTotalTonnage}
            );
            if (mounted) Navigator.of(context).pop();
          },
        ),
        title: Text(widget.workoutDay?.name ?? "Session"),
        actions: [
          IconButton(
            icon: Icon(player.ttsEnabled ? Icons.volume_up : Icons.volume_off, color: Colors.blueAccent),
            onPressed: () => player.toggleTts(!player.ttsEnabled),
            tooltip: "Toggle TTS Cues",
          ),
          IconButton(
            icon: Icon(player.isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () => player.togglePause(),
          ),
          TextButton(onPressed: _finishWorkout, child: const Text("FINISH", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
      body: Column(
        children: [
          // 1. SMART TIMER DISPLAY
          _buildTimerDisplay(player),

          // NEW: VERSUS LEADERBOARD
          if (widget.versusRoomId != null) _buildVersusLeaderboard(),

          // 2. CURRENT EXERCISE FOCUS
          Expanded(
            child: _currentStepIndex < _flatFlow.length 
              ? Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildCurrentExerciseFocus(
                          _flatFlow[_currentStepIndex], 
                          player,
                          key: ValueKey("step_$_currentStepIndex"),
                          onSetLogged: () {
                            // AUTO-SAVE CHECKPOINT (NEW)
                            context.read<DatabaseService>().pauseSession(
                              _sessionId, 
                              widget.planId ?? 'unknown', 
                              widget.workoutDay?.name ?? 'Unknown Day', 
                              _currentStepIndex,
                              {'tonnage': _sessionTotalTonnage}
                            );
                          },
                        ),
                      )
                    ),
                    const Divider(color: Colors.white12),
                    _buildWorkoutQueue(),
                  ],
                )
              : const Center(child: Text("Workout Complete!", style: TextStyle(color: Colors.white))),
          ),

          // 3. NAVIGATION / SKIP
          _buildBottomControls(player),
        ],
      ),
    );
  }

  Widget _buildWorkoutQueue() {
    return Container(
      height: 120,
      width: double.infinity,
      color: Colors.white.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text("UPCOMING QUEUE", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _flatFlow.length,
              onReorder: (int oldIndex, int newIndex) {
                 if (oldIndex < newIndex) {
                   newIndex -= 1;
                 }
                 // Prevent reordering past/completed items
                 if (oldIndex < _currentStepIndex || newIndex < _currentStepIndex) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot rearrange completed exercises!"), duration: Duration(seconds: 1)));
                    return;
                 }
                 setState(() {
                   final item = _flatFlow.removeAt(oldIndex);
                   _flatFlow.insert(newIndex, item);
                   
                   final key = _flowKeys.removeAt(oldIndex);
                   _flowKeys.insert(newIndex, key);
                 });
              },
              proxyDecorator: (child, index, animation) {
                 return Material(
                   color: Colors.transparent,
                   child: child, 
                 );
              },
              itemBuilder: (ctx, index) {
                final ex = _flatFlow[index];
                final bool isCurrent = index == _currentStepIndex;
                final key = _flowKeys[index];
                
                return InkWell(
                  key: key, 
                  onTap: () => _jumpToStep(index),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCurrent ? Colors.blue.withValues(alpha: 0.2) : (_completedKeys.contains(key) ? Colors.green.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrent ? Border.all(color: Colors.blue, width: 2) : Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ex.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isCurrent ? Colors.white : Colors.grey, fontSize: 10, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                        ),
                        const SizedBox(height: 4),
                        if (_completedKeys.contains(key)) const Icon(Icons.check_circle, color: Colors.green, size: 14)
                        else Text("Set ${index + 1}", style: const TextStyle(color: Colors.grey, fontSize: 9)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersusLeaderboard() {
    final realtime = context.watch<RealtimeService>();
    final scores = realtime.competitorTonnage;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🏆 VERSUS MODE", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text("ME: ${_sessionTotalTonnage.toInt()} lbs", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (scores.isNotEmpty) ...[
                const Text("RIVALS: ", style: TextStyle(color: Colors.grey, fontSize: 10)),
                ...scores.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text("${e.key.split(' ').first}: ${e.value.toInt()}", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                )),
              ] else const Text("Waiting for rivals...", style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(WorkoutPlayerService player) {
    Color color = Colors.blue;
    String label = "WORKING";
    
    if (player.state == WorkoutState.resting) { color = Colors.green; label = "REST"; }
    if (player.state == WorkoutState.countdown) { color = Colors.orange; label = "GET READY"; }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.3))),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(
            _formatTime(player.timerSeconds),
            style: TextStyle(color: color, fontSize: 64, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          if (player.state == WorkoutState.resting) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRestAdjustButton(player, -15, Icons.remove),
                const SizedBox(width: 24),
                _buildRestAdjustButton(player, 15, Icons.add),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: () => _saveDefaultRest(player),
                  icon: const Icon(Icons.save, color: Colors.blueAccent),
                  tooltip: "Save as Default Rest",
                ),
              ],
            ),
            const SizedBox(height: 16),
              // Wrap in Builder to ensure context is valid if needed, or just plain button
              Builder(builder: (c) => ElevatedButton(
                  onPressed: () => player.skipRest(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, 
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text("SKIP REST", style: TextStyle(fontWeight: FontWeight.bold)),
              )),
          ]
        ],
      ),
    );
  }

  Widget _buildRestAdjustButton(WorkoutPlayerService player, int delta, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () => player.adjustRestTime(delta),
        icon: Icon(icon, color: Colors.green),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildCurrentExerciseFocus(WorkoutExercise ex, WorkoutPlayerService player, {Key? key, VoidCallback? onSetLogged}) {
    // Determine set number for THIS exercise
    int setNum = 0;
    for (int i = 0; i <= _currentStepIndex; i++) {
      if (_flatFlow[i] == ex) setNum++;
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("SET $setNum OF ${ex.sets}", style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            _aliases[ex.name] ?? ex.name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // HEATMAP / INFO FAST LINK
          _buildExerciseQuickInfo(ex.name),
          const SizedBox(height: 32),
          
          // INPUTS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLargeInput("LBS", ex.intensity ?? "100", _weightController),
              const SizedBox(width: 24),
              _buildLargeInput(ex.metricType == 'time' ? "SEC" : "REPS", ex.reps, _repsController),
              const SizedBox(width: 16),
              // INLINE COMPLETE BUTTON (Fail-safe)
              // Faded until selected (User Request)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _completedKeys.contains(_flowKeys[_currentStepIndex]) ? 1.0 : 0.4,
                child: Container(
                  decoration: BoxDecoration(
                    color: _completedKeys.contains(_flowKeys[_currentStepIndex]) ? Colors.green : Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.check, color: Colors.white, size: 28),
                    onPressed: () async {
                       // Allow toggle? Or just strict 'complete'? 
                       // For now, let's keep strict log.
                       final key = _flowKeys[_currentStepIndex];
                       if (!_completedKeys.contains(key)) {
                         await _logSet(ex);
                         player.completeSet(ex.restSeconds);
                         if (onSetLogged != null) onSetLogged(); // NEW
                         setState(() {
                           _currentStepIndex++;
                         });
                       }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),

          // RPE SLIDER
          Text("EFFORT (RPE): ${_currentRpe.toInt()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Slider(
            value: _currentRpe,
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: _getRpeColor(_currentRpe),
            label: _currentRpe.toInt().toString(),
            onChanged: (val) {
              setState(() => _currentRpe = val);
              context.read<WorkoutPlayerService>().updateDraft(null, null, val);
            },
          ),
          
          if (_currentRpe >= 9) 
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Text("🔥 High effort! ", 
                     style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                   const Text("Auto-apply +30s rest? ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                   Switch(
                     value: _autoApplySmartRest, 
                     onChanged: (v) => setState(() => _autoApplySmartRest = v),
                     activeColor: Colors.orange,
                     ),
                 ],
               ),
             ),
        ],
      ),
    );
  }

  Color _getRpeColor(double rpe) {
    if (rpe < 6) return Colors.green;
    if (rpe < 8) return Colors.yellow;
    if (rpe < 9.5) return Colors.orange;
    return Colors.red;
  }

  Widget _buildExerciseQuickInfo(String name) {
    final meta = _exerciseMetadata[name];
    if (meta == null) return const SizedBox.shrink();

    return Column(
      children: [
        Wrap(
          spacing: 4,
          children: meta.primaryMuscles.map((m) => Chip(
            label: Text(m, style: const TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.blueGrey.shade800,
            padding: EdgeInsets.zero,
          )).toList(),
        ),
        TextButton.icon(
          onPressed: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: meta!)));
          },
          icon: const Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
          label: const Text("Exercise Detail", style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildLargeInput(String label, String hint, TextEditingController controller) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.black26),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildBottomControls(WorkoutPlayerService player) {
    final bool isWorking = player.state == WorkoutState.working;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(player.isPaused ? Icons.play_circle_filled : Icons.pause_circle_filled, color: Colors.white70, size: 40),
            onPressed: () => player.togglePause(),
          ),
          if (player.state == WorkoutState.resting)
            ElevatedButton(
              onPressed: () => player.skipRest(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text("SKIP REST"),
            ),
          
          if (isWorking)
            ElevatedButton.icon(
              onPressed: () async {
                final ex = _flatFlow[_currentStepIndex];
                await _logSet(ex);
                
                player.completeSet(ex.restSeconds);
                setState(() {
                  _currentStepIndex++;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              icon: const Icon(Icons.check, size: 20),
              label: const Text("DONE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }
}

class ExerciseCard extends StatefulWidget {
  final WorkoutExercise exercise;
  final String sessionId;
  final String? alias;
  final double? oneRepMax;
  final String? oneRepDate;
  final Function(int) onSetCompleted;
  final VoidCallback? onSetLogged; // NEW

  const ExerciseCard({
    super.key, 
    required this.exercise, 
    required this.sessionId,
    this.alias,
    this.oneRepMax,
    this.oneRepDate,
    required this.onSetCompleted,
    this.onSetLogged, // NEW
  });

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  late List<TextEditingController> _weightCtrls;
  late List<TextEditingController> _repsCtrls;
  late List<TextEditingController> _timeCtrls;
  late List<bool> _isDone;
  
  Timer? _localTimer;
  int _localSeconds = 0;
  bool _isTimerRunning = false;
  LogEntry? _lastLog; 

  @override
  void initState() {
    super.initState();
    _weightCtrls = List.generate(widget.exercise.sets, (_) => TextEditingController());
    _repsCtrls = List.generate(widget.exercise.sets, (_) => TextEditingController());
    _timeCtrls = List.generate(widget.exercise.sets, (_) => TextEditingController());
    _isDone = List.generate(widget.exercise.sets, (_) => false);
    _loadLastLog();
  }

  Future<void> _loadLastLog() async {
    final db = context.read<DatabaseService>();
    final last = await db.getLastLogForExercise(widget.exercise.name);
    if (mounted && last != null) {
      setState(() => _lastLog = last);
    }
  }

  @override
  void dispose() {
    for (var c in _weightCtrls) { c.dispose(); }
    for (var c in _repsCtrls) { c.dispose(); }
    for (var c in _timeCtrls) { c.dispose(); }
    _localTimer?.cancel();
    super.dispose();
  }

  void _logSet(int index) {
    if (_isDone[index]) return;

    final weight = double.tryParse(_weightCtrls[index].text) ?? 0.0;
    final reps = int.tryParse(_repsCtrls[index].text) ?? 0;
    
    int duration = int.tryParse(_timeCtrls[index].text) ?? 0;
    if (duration == 0) {
      if (widget.exercise.secondsPerSet > 0) {
        duration = widget.exercise.secondsPerSet; 
      } else if (_localSeconds > 0) {
        duration = _localSeconds; 
      }
      _timeCtrls[index].text = duration.toString();
    }

    final log = LogEntry(
      id: DateTime.now().toIso8601String(),
      exerciseId: widget.exercise.name,
      exerciseName: widget.exercise.name,
      weight: weight,
      reps: reps,
      volumeLoad: weight * reps,
      duration: duration,
      timestamp: DateTime.now().toIso8601String(),
      sessionId: widget.sessionId,
    );

    context.read<DatabaseService>().logSet(log);

    setState(() => _isDone[index] = true);
    widget.onSetCompleted(widget.exercise.restSeconds);
    if (widget.onSetLogged != null) widget.onSetLogged!(); // NEW: Trigger checkpoint
    
    if (_isTimerRunning) _toggleTimer();
    setState(() => _localSeconds = 0);
  }

  void _toggleTimer() {
    setState(() => _isTimerRunning = !_isTimerRunning);
    if (_isTimerRunning) {
      _localTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() => _localSeconds++);
      });
    } else {
      _localTimer?.cancel();
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Future<void> _showDetails(String name) async {
    final dynamic connectivityResult = await Connectivity().checkConnectivity();
    
    if (!mounted) return;

    final bool isOffline = connectivityResult is List 
      ? connectivityResult.contains(ConnectivityResult.none)
      : connectivityResult == ConnectivityResult.none;

    if (isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Offline.")));
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('exercises')
          .select()
          .ilike('name', name)
          .limit(1)
          .maybeSingle();
      
      if (!mounted) return;

      if (data != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: Exercise.fromJson(data))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Details not found.")));
      }
    } catch (e, stack) {
      LoggerService().log("Detail Fetch Error", e, stack);
    }
  }

  // Calculate recommendation string for hint text
  String _getWeightHint() {
    if (widget.oneRepMax != null) {
      // Hypertrophy Range (75% of 1RM)
      final target = (widget.oneRepMax! * 0.75).round();
      return target.toString();
    } else if (_lastLog != null) {
      // Progressive Overload (Default to last known weight)
      return _lastLog!.weight.toInt().toString();
    }
    return "-";
  }

  @override
  Widget build(BuildContext context) {
    String? oneRepMaxString;
    if (widget.oneRepMax != null) {
      String dateStr = "";
      if (widget.oneRepDate != null) {
        final dt = DateTime.parse(widget.oneRepDate!);
        dateStr = " (${dt.month}/${dt.day})";
      }
      oneRepMaxString = "1RM: ${widget.oneRepMax!.toInt()}lbs$dateStr";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // Header
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.alias ?? widget.exercise.name, 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  )
                ),
                if (oneRepMaxString != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4)
                    ),
                    child: Text(oneRepMaxString, style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            // Removed Coach's Tip text from subtitle
            subtitle: Text("${widget.exercise.sets} Sets • ${widget.exercise.reps} reps${widget.alias != null ? ' (${widget.exercise.name})' : ''}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isTimerRunning || _localSeconds > 0)
                  Text(_formatTime(_localSeconds), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                IconButton(
                  icon: Icon(_isTimerRunning ? Icons.stop_circle : Icons.timer, 
                    color: _isTimerRunning ? Colors.red : Colors.blueGrey),
                  onPressed: _toggleTimer,
                  tooltip: "Start/Stop Exercise Timer",
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.blueGrey),
                  onPressed: () => _showDetails(widget.exercise.name),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Labels
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 20, child: Text("#")),
                Expanded(flex: 2, child: Text("LBS", style: TextStyle(fontSize: 12, color: Colors.grey))),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text("REPS", style: TextStyle(fontSize: 12, color: Colors.grey))),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text("TIME", style: TextStyle(fontSize: 12, color: Colors.grey))),
                SizedBox(width: 40),
              ],
            ),
          ),

          // Sets
          ...List.generate(widget.exercise.sets, (i) {
            final isDone = _isDone[i];
            
            return Container(
              color: isDone ? Colors.green.withValues(alpha: 0.1) : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 20, child: Text("${i + 1}")),
                  Expanded(flex: 2, child: TextField(
                    controller: _weightCtrls[i],
                    enabled: !isDone,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true, 
                      border: const OutlineInputBorder(), 
                      hintText: _getWeightHint(), // CHANGED: Added Hint Text Logic
                      hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)) // Semi-transparent
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextField(
                    controller: _repsCtrls[i],
                    enabled: !isDone,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true, 
                      border: const OutlineInputBorder(),
                      hintText: widget.exercise.reps,
                      hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5))
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextField(
                    controller: _timeCtrls[i],
                    enabled: !isDone,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true, 
                      border: const OutlineInputBorder(),
                      hintText: widget.exercise.secondsPerSet > 0 ? "${widget.exercise.secondsPerSet}s" : "s",
                    ),
                  )),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: isDone,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        if (val == true) {
                          _logSet(i);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
