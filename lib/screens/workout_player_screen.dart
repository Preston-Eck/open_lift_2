import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/workout_player_service.dart';
import '../services/database_service.dart';
import '../models/log.dart';
import '../models/plan.dart';
import '../widgets/one_rep_max_dialog.dart';

class WorkoutPlayerScreen extends StatefulWidget {
  final WorkoutDay? workoutDay;

  const WorkoutPlayerScreen({super.key, this.workoutDay});

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  // Local cache of 1RM data to calculate suggestions instantly
  Map<String, double> _oneRepMaxes = {};

  @override
  void initState() {
    super.initState();
    _refreshOneRepMaxes();
  }

  Future<void> _refreshOneRepMaxes() async {
    final db = context.read<DatabaseService>();
    // Try catching both method names in case DB service wasn't fully updated yet
    try {
      // Prefer the new history-aware method
      final stats = await db.getLatestOneRepMaxes();
      if (mounted) setState(() => _oneRepMaxes = stats);
    } catch (e) {
      try {
        // Fallback to old method name
        // ignore: deprecated_member_use
        final stats = await db.getAllOneRepMaxes();
        if (mounted) setState(() => _oneRepMaxes = stats);
      } catch (e2) {
        debugPrint("Error fetching 1RMs: $e2");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<WorkoutPlayerService>(context);
    
    // Default fallback if no plan loaded
    final exercises = widget.workoutDay?.exercises ?? [
      WorkoutExercise(name: "Freestyle Workout", sets: 1, reps: "0", restSeconds: 60)
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutDay?.name ?? "Active Workout"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmExit(context, player),
        ),
      ),
      body: Column(
        children: [
          // --- Global Timer / Rest Timer Header ---
          _buildTimerHeader(player),
          
          // --- Exercise List ---
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              separatorBuilder: (c, i) => const Divider(height: 40, thickness: 2),
              itemBuilder: (context, index) {
                final ex = exercises[index];
                final oneRepMax = _oneRepMaxes[ex.name];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Exercise Header (Name + 1RM + Suggestion)
                    _buildExerciseHeader(context, ex, oneRepMax),
                    
                    const SizedBox(height: 10),
                    
                    // 2. Column Headers
                    _buildSetHeaders(ex),

                    // 3. Sets
                    ...List.generate(ex.sets, (setIndex) => 
                      _ExerciseSetRow(
                        exercise: ex, 
                        setNumber: setIndex + 1,
                        suggestedWeight: _calculateTargetWeight(ex.intensity, oneRepMax),
                      )
                    ),
                  ],
                );
              },
            ),
          ),
          
          // --- Finish Button ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white
                ),
                onPressed: () {
                  player.finishWorkout();
                  Navigator.pop(context);
                },
                child: const Text("FINISH WORKOUT", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerHeader(WorkoutPlayerService player) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: player.state == WorkoutState.resting 
        ? Colors.red.withValues(alpha: 0.2) 
        : Colors.transparent,
      child: Column(
        children: [
          Text(
            player.state == WorkoutState.resting ? "RESTING" : "ACTIVE",
            style: TextStyle(
              color: player.state == WorkoutState.resting ? Colors.redAccent : Colors.grey,
              fontWeight: FontWeight.bold,
              letterSpacing: 2
            ),
          ),
          Text(
            player.state == WorkoutState.resting 
              ? "${player.timerSeconds}" 
              : _formatDuration(Duration(seconds: 0)), // In a real app, bind to player.elapsedTime
            style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseHeader(BuildContext context, WorkoutExercise ex, double? oneRepMax) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ex.name, 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
              ),
              // Explicit 1RM Button
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () async {
                  await showDialog(
                    context: context, 
                    builder: (_) => EditOneRepMaxDialog(
                      exerciseName: ex.name,
                      currentMax: oneRepMax,
                    )
                  );
                  _refreshOneRepMaxes();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14, color: Colors.blue[300]),
                      const SizedBox(width: 4),
                      Text(
                        oneRepMax != null 
                          ? "1RM: ${oneRepMax.toInt()} lbs" 
                          : "Set 1RM",
                        style: TextStyle(
                          color: Colors.blue[300], 
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue[300]
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Suggestion Bubble
        if (ex.intensity != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Goal: ${ex.intensity}", 
                  style: const TextStyle(fontSize: 10, color: Colors.grey)
                ),
                if (_calculateTargetWeight(ex.intensity, oneRepMax) != null)
                  Text(
                    "${_calculateTargetWeight(ex.intensity, oneRepMax)!.toInt()} lbs",
                    style: const TextStyle(fontSize: 16, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSetHeaders(WorkoutExercise ex) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          const SizedBox(width: 32), // Checkbox space
          const SizedBox(width: 16),
          const Expanded(child: Text("LBS", style: TextStyle(color: Colors.grey, fontSize: 10))),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              ex.secondsPerSet > 0 ? "TIME (s)" : "REPS", 
              style: const TextStyle(color: Colors.grey, fontSize: 10)
            )
          ),
        ],
      ),
    );
  }

  void _confirmExit(BuildContext context, WorkoutPlayerService player) {
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("End Workout?"),
        content: const Text("Progress will be saved in logs."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              player.finishWorkout();
              Navigator.pop(context);
            }, 
            child: const Text("End")
          )
        ],
      )
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
  }

  double? _calculateTargetWeight(String? intensity, double? oneRepMax) {
    if (intensity == null || oneRepMax == null) return null;
    if (intensity.contains('%')) {
      final pct = double.tryParse(intensity.replaceAll('%', '')) ?? 0;
      if (pct > 0) {
        final suggested = oneRepMax * (pct / 100);
        // Round to nearest 5 lbs for standard plates
        return (suggested / 5).round() * 5.0;
      }
    }
    return null;
  }
}

// --- Individual Set Row ---
class _ExerciseSetRow extends StatefulWidget {
  final WorkoutExercise exercise;
  final int setNumber;
  final double? suggestedWeight;

  const _ExerciseSetRow({
    required this.exercise, 
    required this.setNumber,
    this.suggestedWeight,
  });

  @override
  State<_ExerciseSetRow> createState() => _ExerciseSetRowState();
}

class _ExerciseSetRowState extends State<_ExerciseSetRow> with AutomaticKeepAliveClientMixin {
  bool _isCompleted = false;
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  
  // Timer State
  Timer? _timer;
  int _currentSeconds = 0;
  bool _timerRunning = false;
  final AudioPlayer _audio = AudioPlayer();

  @override
  bool get wantKeepAlive => true; // Keeps data when scrolling

  @override
  void initState() {
    super.initState();
    _currentSeconds = widget.exercise.secondsPerSet;
    
    // Pre-fill weight
    _weightController = TextEditingController(
      text: widget.suggestedWeight != null ? widget.suggestedWeight!.toInt().toString() : ''
    );
    
    // Pre-fill reps
    _repsController = TextEditingController();
    if (int.tryParse(widget.exercise.reps) != null) {
      _repsController.text = widget.exercise.reps;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audio.dispose();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _timerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_currentSeconds > 0) {
        setState(() => _currentSeconds--);
        // Beep at 3, 2, 1
        if (_currentSeconds <= 3 && _currentSeconds > 0) {
          await _audio.play(AssetSource('beep.mp3'));
        }
      } else {
        timer.cancel();
        // Long beep at 0
        await _audio.play(AssetSource('beep_long.mp3'));
        setState(() => _timerRunning = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    bool isTimed = widget.exercise.secondsPerSet > 0;

    return Container(
      color: _isCompleted ? Colors.green.withValues(alpha: 0.1) : null,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Set Bubble
          Container(
            width: 30,
            alignment: Alignment.center,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: _isCompleted ? Colors.green : Colors.grey[800],
              child: Text(
                "${widget.setNumber}",
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Weight Input
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8)
              ),
              child: TextField(
                controller: _weightController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                enabled: !_isCompleted,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "-",
                  contentPadding: EdgeInsets.only(bottom: 8)
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Reps Input OR Timer Control
          Expanded(
            child: isTimed 
              ? InkWell(
                  onTap: _isCompleted ? null : (_timerRunning ? null : _startTimer),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _timerRunning ? Colors.orange.withValues(alpha: 0.2) : Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: _timerRunning ? Border.all(color: Colors.orange) : null
                    ),
                    child: _timerRunning
                      ? Text("$_currentSeconds", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18))
                      : (_currentSeconds == 0 
                          ? const Icon(Icons.check, color: Colors.green) 
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                                const SizedBox(width: 4),
                                Text("${widget.exercise.secondsPerSet}s"),
                              ],
                            )),
                  ),
                )
              : Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: TextField(
                    controller: _repsController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    enabled: !_isCompleted,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "-",
                      contentPadding: EdgeInsets.only(bottom: 8)
                    ),
                  ),
                ),
          ),
          const SizedBox(width: 10),

          // Checkbox
          Transform.scale(
            scale: 1.3,
            child: Checkbox(
              value: _isCompleted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              activeColor: Colors.green,
              onChanged: (val) {
                if (val == true) {
                  _logSet(context);
                } else {
                  setState(() => _isCompleted = false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _logSet(BuildContext context) {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    
    int resultValue;
    if (widget.exercise.secondsPerSet > 0) {
      resultValue = widget.exercise.secondsPerSet; 
    } else {
      resultValue = int.tryParse(_repsController.text) ?? 0;
    }

    if (resultValue == 0 && weight == 0) return; 

    // Log to DB
    final db = Provider.of<DatabaseService>(context, listen: false);
    db.logSet(LogEntry(
      id: DateTime.now().toIso8601String(),
      exerciseId: widget.exercise.name, 
      exerciseName: widget.exercise.name,
      weight: weight,
      reps: resultValue,
      volumeLoad: weight * resultValue,
      timestamp: DateTime.now().toIso8601String(),
    ));

    // Trigger Rest Timer
    Provider.of<WorkoutPlayerService>(context, listen: false).completeSet(widget.exercise.restSeconds);

    setState(() {
      _isCompleted = true;
    });
  }
}