import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;
  bool _isRecording = false;
  bool _isPaused = false;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String? get currentPath => _currentPath;

  /// Check microphone permission
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording audio
  Future<void> startRecording() async {
    try {
      if (!await hasPermission()) {
        throw Exception('Microphone permission denied');
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${directory.path}/speaking_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, 
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1, 
        ),
        path: _currentPath!,
      );

      _isRecording = true;
      _isPaused = false;
      debugPrint('🎤 Recording started: $_currentPath');
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      rethrow;
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    try {
      if (!_isRecording || _isPaused) return;
      
      await _recorder.pause();
      _isPaused = true;
      debugPrint('⏸️ Recording paused');
    } catch (e) {
      debugPrint('❌ Error pausing recording: $e');
      rethrow;
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    try {
      if (!_isRecording || !_isPaused) return;
      
      await _recorder.resume();
      _isPaused = false;
      debugPrint('▶️ Recording resumed');
    } catch (e) {
      debugPrint('❌ Error resuming recording: $e');
      rethrow;
    }
  }

  /// Stop recording and return file path
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _recorder.stop();
      _isRecording = false;
      _isPaused = false;
      
      debugPrint('⏹️ Recording stopped: $path');
      
      if (path != null) {
        final file = File(path);
        final size = file.lengthSync();
        debugPrint('📁 File size: ${(size / 1024).toStringAsFixed(2)} KB');
      }
      
      return path;
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      return null;
    }
  }

  /// Delete recorded file
  Future<void> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
        debugPrint('🗑️ Deleted: $path');
      }
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
    }
  }

  /// Dispose recorder
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}