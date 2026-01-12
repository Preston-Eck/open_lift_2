import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';

enum WorkoutState { idle, countdown, working, resting, finished }

class WorkoutPlayerService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  WorkoutState _state = WorkoutState.idle;
  int _timerSeconds = 0;
  Timer? _timer;
  
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;

  int _nextRestAdjust = 0; // Buffer for automated adjustments (s)

  // Draft Set Persistence (v1.2.0)
  String _draftWeight = "";
  String _draftReps = "";
  double _draftRpe = 7.0;

  WorkoutState get state => _state;
  int get timerSeconds => _timerSeconds;
  int get currentExerciseIndex => _currentExerciseIndex;
  int get currentSetIndex => _currentSetIndex;
  
  String get draftWeight => _draftWeight;
  String get draftReps => _draftReps;
  double get draftRpe => _draftRpe;

  void updateDraft(String? weight, String? reps, double? rpe) {
    if (weight != null) _draftWeight = weight;
    if (reps != null) _draftReps = reps;
    if (rpe != null) _draftRpe = rpe;
    notifyListeners();
  }

  void clearDraft({bool keepWeight = true}) {
    if (!keepWeight) _draftWeight = "";
    _draftReps = "";
    _draftRpe = 7.0;
    notifyListeners();
  }

  void startWorkout() {
    clearDraft(keepWeight: false);
    _currentExerciseIndex = 0;
    _currentSetIndex = 1;
    _startCountdown();
    WakelockPlus.enable();
  }

  void _startCountdown() {
    _state = WorkoutState.countdown;
    _timerSeconds = 3;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        _playBeep();
        _timerSeconds--;
      } else {
        _startWork();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void _startWork() {
    _state = WorkoutState.working;
    _timer?.cancel();
    _playBeep(long: true);
    
    // Duration timer for 'time' based exercises
    _timerSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timerSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  void completeSet(int restTimeSeconds) {
    _timer?.cancel();
    _state = WorkoutState.resting;
    _startRestTimer(restTimeSeconds + _nextRestAdjust);
    _nextRestAdjust = 0; // Consumption
    notifyListeners();
  }

  void _startRestTimer(int seconds) {
    _timerSeconds = seconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        if (_timerSeconds <= 3) _playBeep();
        _timerSeconds--;
      } else {
        _finishRest();
      }
      notifyListeners();
    });
  }

  void adjustRestTime(int deltaSeconds) {
    if (_state != WorkoutState.resting) return;
    _timerSeconds = (_timerSeconds + deltaSeconds).clamp(0, 999);
    notifyListeners();
  }

  void setNextRestAdjust(int seconds) {
    _nextRestAdjust = seconds;
  }

  void _finishRest() {
    _timer?.cancel();
    _currentSetIndex++;
    _startCountdown();
  }

  void nextExercise() {
    _currentExerciseIndex++;
    _currentSetIndex = 1;
    _startCountdown();
  }

  void finishWorkout() {
    _state = WorkoutState.finished;
    _timer?.cancel();
    clearDraft(keepWeight: false);
    WakelockPlus.disable();
    notifyListeners();
  }

  Future<void> _playBeep({bool long = false}) async {
    try {
      await _audioPlayer.play(AssetSource(long ? 'beep_long.mp3' : 'beep.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}