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
  
  // Progress tracking
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  
  WorkoutState get state => _state;
  int get timerSeconds => _timerSeconds;
  int get currentExerciseIndex => _currentExerciseIndex;
  int get currentSetIndex => _currentSetIndex;

  void startWorkout() {
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
    _startRestTimer(restTimeSeconds);
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