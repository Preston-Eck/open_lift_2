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
  Map<String, double> _oneRepMaxes = {};

  @override
  void initState() {
    super.initState();
    _refreshOneRepMaxes();
  }

  Future<void> _refreshOneRepMaxes() async {
    final db = context.read<DatabaseService>();
    final stats = await db.getAllOneRepMaxes();
    if (mounted) {
      setState(() {
        _oneRepMaxes = stats;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<WorkoutPlayerService>(context);
    
    final exercises = widget.workoutDay?.exercises ?? [
      WorkoutExercise(name: "Freestyle Workout", sets: 1, reps: "0", restSeconds: 60)
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutDay?.name ?? "Active Workout"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            player.finishWorkout();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // --- Timer Header ---
          Container(
            padding: const EdgeInsets.all(24),
            color: player.state == WorkoutState.resting 
              ? Colors.red.withValues(alpha: 0.2) 
              : Colors.transparent,
            child: Center(
              child: Text(
                player.state == WorkoutState.resting 
                  ? "REST: ${player.timerSeconds}s" 
                  : "WORKING",
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          // --- Exercise List ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final ex = exercises[index];
                final oneRepMax = _oneRepMaxes[ex.name];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: InkWell(
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
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    ex.name, 
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.edit, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        
                        if (ex.intensity != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "Target: ${ex.intensity}", 
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                                ),
                                if (_getSuggestion(ex.intensity, oneRepMax) != null)
                                  Text(
                                    _getSuggestion(ex.intensity, oneRepMax)!,
                                    style: const TextStyle(fontSize: 14, color: Colors.blueAccent),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(ex.sets, (setIndex) => 
                      _ExerciseSetRow(
                        exercise: ex, 
                        setNumber: setIndex + 1
                      )
                    ),
                    const Divider(height: 30),
                  ],
                );
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                player.finishWorkout();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.flag),
              label: const Text("Finish Workout"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getSuggestion(String? intensity, double? oneRepMax) {
    if (intensity == null || oneRepMax == null) return null;
    
    if (intensity.contains('%')) {
      final pct = double.tryParse(intensity.replaceAll('%', '')) ?? 0;
      if (pct > 0) {
        final suggested = oneRepMax * (pct / 100);
        final rounded = (suggested / 5).round() * 5;
        return "$rounded lbs";
      }
    }
    return null;
  }
}

class _ExerciseSetRow extends StatefulWidget {
  final WorkoutExercise exercise;
  final int setNumber;

  const _ExerciseSetRow({required this.exercise, required this.setNumber});

  @override
  State<_ExerciseSetRow> createState() => _ExerciseSetRowState();
}

class _ExerciseSetRowState extends State<_ExerciseSetRow> {
  bool _isCompleted = false;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  
  // Timer vars
  Timer? _timer;
  int _currentSeconds = 0;
  bool _timerRunning = false;
  final AudioPlayer _audio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _currentSeconds = widget.exercise.secondsPerSet;
    if (int.tryParse(widget.exercise.reps) != null) {
      _repsController.text = widget.exercise.reps;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _timerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_currentSeconds > 0) {
        setState(() => _currentSeconds--);
        if (_currentSeconds <= 3 && _currentSeconds > 0) {
          // Play short beep
          await _audio.play(AssetSource('beep.mp3')); // Make sure to add 'beep.mp3' to assets
        }
      } else {
        timer.cancel();
        await _audio.play(AssetSource('beep_long.mp3'));
        setState(() => _timerRunning = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isTimed = widget.exercise.secondsPerSet > 0;

    return Card(
      color: _isCompleted ? Colors.green.withValues(alpha: 0.1) : null,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _isCompleted ? Colors.green : Colors.grey,
              child: Text(
                "${widget.setNumber}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 16),
            
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                enabled: !_isCompleted,
                decoration: const InputDecoration(
                  labelText: "Weight (lbs)", 
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            Expanded(
              child: TextField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                enabled: !_isCompleted,
                decoration: InputDecoration(
                  labelText: "Reps",
                  hintText: widget.exercise.reps, 
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Timer Button logic
            if (isTimed) ...[
              if (_timerRunning)
                Text("$_currentSeconds s", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))
              else if (_currentSeconds == 0)
                const Icon(Icons.check, color: Colors.green)
              else
                IconButton(icon: const Icon(Icons.timer), onPressed: _startTimer),
              const SizedBox(width: 8),
            ],

            Checkbox(
              value: _isCompleted,
              onChanged: (val) {
                if (val == true) {
                  _logSet(context);
                } else {
                  setState(() => _isCompleted = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _logSet(BuildContext context) {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final reps = int.tryParse(_repsController.text) ?? 0;

    if (reps == 0 && weight == 0) return; 

    final db = Provider.of<DatabaseService>(context, listen: false);
    db.logSet(LogEntry(
      id: DateTime.now().toIso8601String(),
      exerciseId: widget.exercise.name, 
      exerciseName: widget.exercise.name,
      weight: weight,
      reps: reps,
      volumeLoad: weight * reps,
      timestamp: DateTime.now().toIso8601String(),
    ));

    final player = Provider.of<WorkoutPlayerService>(context, listen: false);
    player.completeSet(widget.exercise.restSeconds);

    setState(() {
      _isCompleted = true;
    });
  }
}