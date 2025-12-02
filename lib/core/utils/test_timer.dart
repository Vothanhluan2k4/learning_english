import 'dart:async';
import 'package:flutter/material.dart';

class TestTimer {
  Timer? _timer;
  int _timeRemaining = 0;
  bool _isTimeUp = false;
  
  final VoidCallback onTick;
  final VoidCallback onTimeout;
  final Function(int) onMinutePassed;

  TestTimer({
    required this.onTick,
    required this.onTimeout,
    required this.onMinutePassed,
  });

  int get timeRemaining => _timeRemaining;
  bool get isTimeUp => _isTimeUp;

  void start(int minutes) {
    _timeRemaining = minutes * 60;
    _isTimeUp = false;
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        _timeRemaining--;
        onTick();
        
        // Trigger callback every minute
        if (_timeRemaining % 60 == 0) {
          onMinutePassed(_timeRemaining ~/ 60);
        }
      } else {
        _isTimeUp = true;
        timer.cancel();
        onTimeout();
      }
    });
  }

  void pause() {
    _timer?.cancel();
  }

  void resume() {
    if (_timeRemaining > 0 && !_isTimeUp) {
      start(_timeRemaining ~/ 60);
    }
  }

  void dispose() {
    _timer?.cancel();
  }

  String formatTime() {
    final minutes = _timeRemaining ~/ 60;
    final seconds = _timeRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}