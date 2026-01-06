import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/database_service.dart';
import '../models/log.dart';
import '../models/plan.dart';
import '../models/exercise.dart';

class WorkoutPlayerScreen extends StatefulWidget {
  final WorkoutDay? workoutDay;
  final bool isHiit; // Pass true if the plan type is HIIT

  const WorkoutPlayerScreen({super.key, this.workoutDay, this.isHiit = false});

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  Map<String, double> _oneRepMaxes = {};
  
  // --- HIIT STATE ---
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  bool _hiitActive = false;
  int _hiitTimer = 0;
  String _hiitStatus = "READY"; // READY, WORK, REST, FINISHED
  Exercise? _currentWikiData; // For showing images during HIIT

  @override
  void initState() {
    super.initState();
    _refreshOneRepMaxes();
    if (widget.isHiit) {
      _loadWikiDataForIndex(0); // Preload first image
    }
  }

  Future<void> _refreshOneRepMaxes() async {
    final db = context.read<DatabaseService>();
    final stats = await db.getLatestOneRepMaxes();
    if (mounted) setState(() => _oneRepMaxes = stats);
  }

  Future<void> _loadWikiDataForIndex(int index) async {
    if (widget.workoutDay == null) return;
    if (index >= widget.workoutDay!.exercises.length) return;
    
    final name = widget.workoutDay!.exercises[index].name;
    final data = await Supabase.instance.client.from('exercises').select().ilike('name', name).limit(1).maybeSingle();
    if (data != null && mounted) {
      setState(() => _currentWikiData = Exercise.fromJson(data));
    }
  }

  // --- HIIT LOGIC ---
  void _startHiitSession() {
    setState(() {
      _hiitActive = true;
      _hiitStatus = "GET READY";
      _hiitTimer = 3; 
    });
    WakelockPlus.enable();
    _runHiitTimer();
  }

  void _runHiitTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || !_hiitActive) {
        timer.cancel();
        return;
      }

      if (_hiitTimer > 0) {
        setState(() => _hiitTimer--);
        if (_hiitTimer > 0 && _hiitTimer <= 3) _playBeep();
      } else {
        // Transition
        _handleHiitTransition(timer);
      }
    });
  }

  void _handleHiitTransition(Timer timer) {
    _playBeep(long: true);
    final exercises = widget.workoutDay!.exercises;
    
    if (_hiitStatus == "GET READY" || _hiitStatus == "REST") {
      // Start Work
      setState(() {
        _hiitStatus = "WORK";
        _hiitTimer = exercises[_currentExerciseIndex].secondsPerSet > 0 
            ? exercises[_currentExerciseIndex].secondsPerSet 
            : 30; // Default fallback if not set
      });
    } else if (_hiitStatus == "WORK") {
      // Start Rest or Next Set
      // Log the set automatically
      _logHiitSet();

      if (_currentSetIndex < exercises[_currentExerciseIndex].sets - 1) {
        _currentSetIndex++; // Next set same exercise
        setState(() {
          _hiitStatus = "REST";
          _hiitTimer = exercises[_currentExerciseIndex].restSeconds;
        });
      } else {
        // Exercise Complete
        if (_currentExerciseIndex < exercises.length - 1) {
          _currentExerciseIndex++;
          _currentSetIndex = 0;
          _loadWikiDataForIndex(_currentExerciseIndex); // Load next image
          setState(() {
            _hiitStatus = "REST";
            _hiitTimer = exercises[_currentExerciseIndex - 1].restSeconds; // Rest after previous
          });
        } else {
          // All Done
          timer.cancel();
          setState(() {
            _hiitStatus = "FINISHED";
            _hiitActive = false;
          });
          WakelockPlus.disable();
        }
      }
    }
  }

  void _logHiitSet() {
     // Simplified auto-log for HIIT
     final ex = widget.workoutDay!.exercises[_currentExerciseIndex];
     context.read<DatabaseService>().logSet(LogEntry(
        id: DateTime.now().toIso8601String(),
        exerciseId: ex.name,
        exerciseName: ex.name,
        weight: 0,
        reps: 0,
        volumeLoad: 0,
        timestamp: DateTime.now().toIso8601String()
     ));
  }

  Future<void> _playBeep({bool long = false}) async {
    final player = AudioPlayer();
    await player.play(AssetSource(long ? 'beep_long.mp3' : 'beep.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHiit && _hiitActive) {
      return _buildHiitOverlay();
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.workoutDay?.name ?? "Workout")),
      body: widget.isHiit ? _buildHiitStartScreen() : _buildStandardList(),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildHiitStartScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, size: 80, color: Colors.orange),
          const SizedBox(height: 20),
          const Text("HIIT Session", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("Audio cues & Auto-advance enabled"),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
            onPressed: _startHiitSession,
            child: const Text("START WORKOUT", style: TextStyle(fontSize: 20)),
          )
        ],
      ),
    );
  }

  Widget _buildHiitOverlay() {
    final ex = widget.workoutDay!.exercises[_currentExerciseIndex];
    return Scaffold(
      backgroundColor: _hiitStatus == "WORK" ? Colors.green[900] : Colors.grey[900],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(_hiitStatus, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            // Timer
            Text("$_hiitTimer", style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, color: Colors.white)),
            
            const Divider(),
            
            // Exercise Info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(ex.name, style: const TextStyle(fontSize: 30, color: Colors.white), textAlign: TextAlign.center),
                  Text("Set ${_currentSetIndex + 1} / ${ex.sets}", style: const TextStyle(fontSize: 20, color: Colors.white70)),
                  
                  const SizedBox(height: 20),
                  // Image
                  if (_currentWikiData != null && _currentWikiData!.images.isNotEmpty)
                     SizedBox(
                       height: 200,
                       child: Image.network(
                         // Simple fix for full URL construction
                         _currentWikiData!.images.first.startsWith('http') 
                            ? _currentWikiData!.images.first 
                            : "https://nlbxwoinogqmnkvyrsyi.supabase.co/storage/v1/object/public/exercises/${_currentWikiData!.images.first}",
                         fit: BoxFit.cover,
                         errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported, size: 50, color: Colors.white),
                       ),
                     ),
                ],
              ),
            ),
            
            // Controls
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text("STOP SESSION"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => setState(() => _hiitActive = false),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStandardList() {
    final exercises = widget.workoutDay?.exercises ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        return _ExerciseCard(
          exercise: exercises[index], 
          oneRepMax: _oneRepMaxes[exercises[index].name]
        );
      },
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final WorkoutExercise exercise;
  final double? oneRepMax;

  const _ExerciseCard({required this.exercise, this.oneRepMax});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Rest: ${exercise.restSeconds}s"),
            trailing: Text(exercise.intensity ?? ""),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text("WEIGHT", style: TextStyle(color: Colors.grey, fontSize: 10))),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text("REPS", style: TextStyle(color: Colors.grey, fontSize: 10))),
                SizedBox(width: 8),
                // THIRD COLUMN HEADER
                Expanded(flex: 2, child: Text("TIME", style: TextStyle(color: Colors.grey, fontSize: 10))),
                SizedBox(width: 40), // Space for checkbox
              ],
            ),
          ),
          const Divider(),
          ...List.generate(exercise.sets, (i) => _SetRow(setNum: i + 1, exercise: exercise)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  final int setNum;
  final WorkoutExercise exercise;
  const _SetRow({required this.setNum, required this.exercise});

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  bool _done = false;
  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repsCtrl.text = widget.exercise.reps;
    if (widget.exercise.secondsPerSet > 0) {
      _timeCtrl.text = widget.exercise.secondsPerSet.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _done ? Colors.green.withValues(alpha: 0.1) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Weight
          Expanded(
            flex: 2,
            child: TextField(
              controller: _weightCtrl,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: "lbs"),
              keyboardType: TextInputType.number,
              enabled: !_done,
            ),
          ),
          const SizedBox(width: 8),
          // Reps
          Expanded(
            flex: 2,
            child: TextField(
              controller: _repsCtrl,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: "reps"),
              keyboardType: TextInputType.number,
              enabled: !_done,
            ),
          ),
          const SizedBox(width: 8),
          // Time (3rd Column)
          Expanded(
            flex: 2,
            child: TextField(
              controller: _timeCtrl,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: "sec"),
              keyboardType: TextInputType.number,
              enabled: !_done,
            ),
          ),
          const SizedBox(width: 10),
          Checkbox(
            value: _done,
            activeColor: Colors.green,
            onChanged: (val) {
              setState(() => _done = val!);
              if (val!) {
                // Save logic here
                context.read<DatabaseService>().logSet(LogEntry(
                  id: DateTime.now().toIso8601String(),
                  exerciseId: widget.exercise.name,
                  exerciseName: widget.exercise.name,
                  weight: double.tryParse(_weightCtrl.text) ?? 0,
                  reps: int.tryParse(_repsCtrl.text) ?? 0,
                  volumeLoad: (double.tryParse(_weightCtrl.text) ?? 0) * (int.tryParse(_repsCtrl.text) ?? 0),
                  timestamp: DateTime.now().toIso8601String()
                ));
              }
            },
          )
        ],
      ),
    );
  }
}