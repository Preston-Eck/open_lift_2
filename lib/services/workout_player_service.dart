import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum WorkoutState { warmup, working, resting, finished }

class WorkoutPlayerService extends ChangeNotifier {
  WorkoutState _state = WorkoutState.warmup;
  int _timerSeconds = 0;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  WorkoutState get state => _state;
  int get timerSeconds => _timerSeconds;

  void startWorkout() {
    _state = WorkoutState.working;
    WakelockPlus.enable();
    notifyListeners();
  }

  void completeSet(int restTimeSeconds) {
    _state = WorkoutState.resting;
    _startRestTimer(restTimeSeconds);
    notifyListeners();
  }

  void _startRestTimer(int seconds) {
    _timerSeconds = seconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        _timerSeconds--;
        if (_timerSeconds <= 3 && _timerSeconds > 0) {
          _playBeep();
        }
      } else {
        finishRest();
      }
      notifyListeners();
    });
  }

  void finishRest() {
    _timer?.cancel();
    _state = WorkoutState.working;
    _playBeep(long: true);
    notifyListeners();
  }

  void finishWorkout() {
    _state = WorkoutState.finished;
    _timer?.cancel();
    WakelockPlus.disable();
    notifyListeners();
  }

  Future<void> _playBeep({bool long = false}) async {
    // Ensure you add beep.mp3 to assets
    // await _audioPlayer.play(AssetSource(long ? 'beep_long.mp3' : 'beep.mp3'));
    debugPrint("BEEP!"); 
  }
}