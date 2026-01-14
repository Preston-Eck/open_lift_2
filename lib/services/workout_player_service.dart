import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';

enum WorkoutState { idle, countdown, working, resting, finished }

class WorkoutPlayerService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  WorkoutPlayerService() {
    _initAudioSession();
  }

  void _initAudioSession() {
    AudioPlayer.global.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: const AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: [
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.duckOthers,
        ],
      ),
    ));
  }
  
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

  bool _isPaused = false;

  WorkoutState get state => _state;
  int get timerSeconds => _timerSeconds;
  int get currentExerciseIndex => _currentExerciseIndex;
  int get currentSetIndex => _currentSetIndex;
  bool get isPaused => _isPaused;
  
  String get draftWeight => _draftWeight;
  String get draftReps => _draftReps;
  double get draftRpe => _draftRpe;

  void togglePause() {
    _isPaused = !_isPaused;
    debugPrint("WorkoutPlayerService: togglePause called, isPaused: $_isPaused, state: $_state");
    if (_isPaused) {
      _timer?.cancel();
    } else {
      _resumeTimer();
    }
    notifyListeners();
  }

  void _resumeTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == WorkoutState.countdown) {
        if (_timerSeconds > 0) {
          _playBeep();
          _timerSeconds--;
        } else {
          _startWork();
        }
      } else if (_state == WorkoutState.working) {
        _timerSeconds++;
      } else if (_state == WorkoutState.resting) {
        if (_timerSeconds > 0) {
          if (_timerSeconds <= 3) _playBeep();
          _timerSeconds--;
        } else {
          _finishRest();
        }
      }
      notifyListeners();
    });
  }

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
    _isPaused = false;
    _currentExerciseIndex = 0;
    _currentSetIndex = 1;
    _startCountdown();
    WakelockPlus.enable();
  }

  void _startCountdown() {
    _state = WorkoutState.countdown;
    _timerSeconds = 3;
    _isPaused = false;
    _resumeTimer();
    notifyListeners();
  }

  void _startWork() {
    _state = WorkoutState.working;
    _isPaused = false;
    _playBeep(long: true);
    
    // Duration timer for 'time' based exercises
    _timerSeconds = 0;
    _resumeTimer();
    notifyListeners();
  }

  void completeSet(int restTimeSeconds) {
    _timer?.cancel();
    _state = WorkoutState.resting;
    _isPaused = false;
    _startRestTimer(restTimeSeconds + _nextRestAdjust);
    _nextRestAdjust = 0; // Consumption
    notifyListeners();
  }

  void _startRestTimer(int seconds) {
    _timerSeconds = seconds;
    _isPaused = false;
    _resumeTimer();
  }

  void _finishRest() {
    _timer?.cancel();
    _currentSetIndex++;
    _startCountdown();
  }

  void adjustRestTime(int deltaSeconds) {
    if (_state != WorkoutState.resting) return;
    _timerSeconds = (_timerSeconds + deltaSeconds).clamp(0, 999);
    notifyListeners();
  }

  void setNextRestAdjust(int seconds) {
    _nextRestAdjust = seconds;
  }

  void skipRest() {
    debugPrint("WorkoutPlayerService: skipRest called. Current state: $_state, seconds: $_timerSeconds");
    _timer?.cancel();
    _isPaused = false;
    _currentSetIndex++;
    _startCountdown();
    notifyListeners(); // Force immediate update
  }

  void nextExercise() {
    _isPaused = false;
    _currentExerciseIndex++;
    _currentSetIndex = 1;
    _startCountdown();
  }

  void resetToWork() {
    _isPaused = false;
    _timer?.cancel();
    _startWork();
  }

  void finishWorkout() {
    _state = WorkoutState.finished;
    _timer?.cancel();
    _isPaused = false;
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

