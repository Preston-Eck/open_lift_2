import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import '../services/database_service.dart';
import '../services/logger_service.dart';
import '../models/log.dart';
import '../models/plan.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import 'exercise_detail_screen.dart';

class WorkoutPlayerScreen extends StatefulWidget {
  final WorkoutDay? workoutDay;
  final String? planId;
  final bool isHiit;

  const WorkoutPlayerScreen({
    super.key, 
    this.workoutDay, 
    this.planId, 
    this.isHiit = false
  });

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  late String _sessionId;
  Timer? _sessionTimer;
  int _sessionSeconds = 0;
  bool _isPaused = false;
  
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _isResting = false;

  Map<String, String> _aliases = {}; 
  Map<String, double> _oneRepMaxes = {}; 
  Map<String, String> _oneRepDates = {};

  @override
  void initState() {
    super.initState();
    // CRITICAL FIX: Generate ID synchronously so it's ready for the build method immediately.
    _sessionId = const Uuid().v4(); 
    _initSession();
    _loadData();
  }

  Future<void> _initSession() async {
    try {
      await WakelockPlus.enable().catchError((_) {});
      
      if (widget.workoutDay != null) {
        final session = WorkoutSession(
          id: _sessionId,
          planId: widget.planId ?? 'unknown',
          dayName: widget.workoutDay!.name,
          startTime: DateTime.now(),
        );
        if (mounted) context.read<DatabaseService>().startSession(session);
      }

      _startSessionTimer();
    } catch (e, stack) {
      LoggerService().log("Session Init Error", e, stack);
    }
  }

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    final aliases = await db.getAliases();
    
    Map<String, double> maxes = {};
    Map<String, String> dates = {};

    if (widget.workoutDay != null) {
      for (var ex in widget.workoutDay!.exercises) {
        final data = await db.getLatestOneRepMaxDetailed(ex.name);
        if (data != null) {
          maxes[ex.name] = data['weight'];
          dates[ex.name] = data['date'];
        }
      }
    }

    if (mounted) {
      setState(() {
        _aliases = aliases;
        _oneRepMaxes = maxes;
        _oneRepDates = dates;
      });
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) setState(() => _sessionSeconds++);
    });
  }

  void _triggerRest(int duration) {
    _restTimer?.cancel();
    setState(() {
      _isResting = true;
      _restSeconds = duration;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          if (_restSeconds > 0) {
            _restSeconds--;
            if (_restSeconds <= 3 && _restSeconds > 0) _playBeep();
          } else {
            _playBeep(long: true);
            timer.cancel();
            _isResting = false;
          }
        });
      }
    });
  }

  Future<void> _playBeep({bool long = false}) async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource(long ? 'beep_long.mp3' : 'beep.mp3'));
    } catch (e) {
      // Ignore audio errors
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  void _finishWorkout() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    context.read<DatabaseService>().endSession(_sessionId, DateTime.now());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.workoutDay?.exercises ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.workoutDay?.name ?? "Session", style: const TextStyle(fontSize: 16)),
            Text(_isPaused ? "PAUSED" : _formatTime(_sessionSeconds), 
              style: TextStyle(fontSize: 12, color: _isPaused ? Colors.orange : Colors.greenAccent)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () => setState(() => _isPaused = !_isPaused),
          ),
          TextButton(
            onPressed: _finishWorkout,
            child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      bottomSheet: _isResting ? _buildRestOverlay() : null,
      body: exercises.isEmpty 
        ? const Center(child: Text("No exercises."))
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: exercises.length,
            itemBuilder: (ctx, i) => ExerciseCard(
              key: ValueKey("${exercises[i].name}_$i"),
              exercise: exercises[i],
              sessionId: _sessionId,
              alias: _aliases[exercises[i].name], 
              oneRepMax: _oneRepMaxes[exercises[i].name], 
              oneRepDate: _oneRepDates[exercises[i].name], 
              onSetCompleted: (restTime) => _triggerRest(restTime),
            ),
          ),
    );
  }

  Widget _buildRestOverlay() {
    return Container(
      width: double.infinity,
      color: Colors.green,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("RESTING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(_formatTime(_restSeconds), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green),
            onPressed: () => setState(() => _isResting = false),
            child: const Text("SKIP"),
          )
        ],
      ),
    );
  }
}

class ExerciseCard extends StatefulWidget {
  final WorkoutExercise exercise;
  final String sessionId;
  final String? alias;
  final double? oneRepMax;
  final String? oneRepDate;
  final Function(int) onSetCompleted;

  const ExerciseCard({
    super.key, 
    required this.exercise, 
    required this.sessionId,
    this.alias,
    this.oneRepMax,
    this.oneRepDate,
    required this.onSetCompleted,
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
    final connectivity = await Connectivity().checkConnectivity();
    
    if (!mounted) return;

    if (connectivity == ConnectivityResult.none) {
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