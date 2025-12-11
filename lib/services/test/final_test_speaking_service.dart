import 'dart:async';
import 'dart:io'; 
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/test_question.dart';
import '../course/audio_recorder_service.dart';
import '../../services/ai/groq_speech_service.dart';
import '../../services/ai/ai_grading_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinalTestSpeakingService extends ChangeNotifier {
  final AudioRecorderService _audioRecorder = AudioRecorderService();
  final GroqSpeechService _groqSpeech = GroqSpeechService();
  final AiGradingService _aiService = AiGradingService();
  final _supabase = Supabase.instance.client;

  // Recording state
  bool _recordingEnabled = false;
  bool _isRecording = false;
  bool _isPaused = false;
  String _currentTranscript = '';
  String? _currentAudioPath;
  int _secondsRecorded = 0;
  Timer? _recordingTimer;

  // Getters
  bool get recordingEnabled => _recordingEnabled;
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String get currentTranscript => _currentTranscript;
  int get secondsRecorded => _secondsRecorded;
  String? get currentAudioPath => _currentAudioPath; // ✅ ADD: Expose audio path

  /// ✅ Initialize microphone permission
  Future<void> initializeRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      
      if (!hasPermission) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          debugPrint('❌ Microphone permission denied');
          _recordingEnabled = false;
          notifyListeners();
          return;
        }
      }

      _recordingEnabled = true;
      notifyListeners();
      debugPrint('✅ Recording enabled for final test');
    } catch (e) {
      debugPrint('❌ Error initializing recording: $e');
      _recordingEnabled = false;
      notifyListeners();
    }
  }

  /// ✅ Start recording
  Future<void> startRecording(TestQuestion question) async {
    try {
      debugPrint('🎤 Starting recording for question: ${question.id}');
      
      await _audioRecorder.startRecording();


      _isRecording = true;
      _isPaused = false;
      _currentAudioPath = null; 
      _currentTranscript = '';
      _secondsRecorded = 0;
      notifyListeners();

      // Start timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _secondsRecorded++;
        notifyListeners();
        
        // ✅ FIXED: Handle null timeLimit
        final limit = question.timeLimit ?? 60;
        if (_secondsRecorded >= limit) {
          stopRecording();
        }
      });

      debugPrint('✅ Recording started: ');
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      rethrow;
    }
  }

  /// ✅ Pause recording
  Future<void> pauseRecording() async {
    await _audioRecorder.pauseRecording();
    _isPaused = true;
    _recordingTimer?.cancel();
    notifyListeners();
    debugPrint('⏸️ Recording paused');
  }

  /// ✅ Resume recording
  Future<void> resumeRecording() async {
    await _audioRecorder.resumeRecording();
    _isPaused = false;
    notifyListeners();
    
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsRecorded++;
      notifyListeners();
    });
    
    debugPrint('▶️ Recording resumed');
  }

  /// ✅ Stop recording & transcribe (FIXED - Save audio path)
  Future<void> stopRecording() async {
    try {
      final path = await _audioRecorder.stopRecording();
      _recordingTimer?.cancel();
      
      _isRecording = false;
      _isPaused = false;
      _currentAudioPath = path; // ✅ FIX: Save audio path
      _currentTranscript = 'Đang chuyển đổi giọng nói sang văn bản...';
      notifyListeners();

      debugPrint('⏹️ Recording stopped: $path');

      // Transcribe audio
      if (path != null) {
        final transcript = await _groqSpeech.transcribeAudio(path);
        
        _currentTranscript = transcript;
        notifyListeners();

        debugPrint('✅ Transcript: $transcript');
      }
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      _currentTranscript = 'Lỗi chuyển đổi giọng nói';
      notifyListeners();
      rethrow;
    }
  }

  /// ✅ Reset recording
  Future<void> resetRecording(TestQuestion question) async {
    try {
      if (_isRecording) {
        await _audioRecorder.stopRecording();
        _recordingTimer?.cancel();
      }

      if (_currentAudioPath != null) {
        await _audioRecorder.deleteRecording(_currentAudioPath!);
      }

      _currentTranscript = '';
      _currentAudioPath = null;
      _secondsRecorded = 0;
      _isRecording = false;
      _isPaused = false;
      notifyListeners();

      debugPrint('🔄 Recording reset for question: ${question.id}');

      // Auto-restart after short delay
      await Future.delayed(const Duration(milliseconds: 500));
      await startRecording(question);
    } catch (e) {
      debugPrint('❌ Error resetting recording: $e');
      rethrow;
    }
  }
  /// ✅ Save speaking answer to database (FIXED)
Future<void> saveSpeakingAnswer({
  required String resultId,
  required String questionId,
  required String transcript,
  required String? audioPath,
}) async {
  try {
    String? audioUrl;
    
    // ✅ FIX 1: Upload audio using proper storage method
    if (audioPath != null) {
      final file = File(audioPath);
      
      if (await file.exists()) {
        debugPrint('📤 Uploading audio: ${file.path}');
        
        try {
          // Create unique filename
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'speaking/${resultId}_${questionId}_$timestamp.m4a';
          
          // ✅ Use upload() instead of uploadBinary()
          final uploadResponse = await _supabase.storage
              .from('audio_speaking_tests')
              .upload(
                fileName,
                file,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: false,
                  contentType: 'audio/m4a',
                ),
              );
          
          debugPrint('✅ Upload response: $uploadResponse');
          
          // Get public URL
          audioUrl = _supabase.storage
              .from('audio_speaking_tests')
              .getPublicUrl(fileName);
          
          debugPrint('✅ Audio uploaded: $audioUrl');
        } catch (uploadError) {
          debugPrint('❌ Audio upload failed: $uploadError');
          // Continue without audio (transcript is still saved)
        }
      } else {
        debugPrint('⚠️ Audio file not found: $audioPath');
      }
    }

    // ✅ FIX 2: Save to user_test_answers with all fields
    final insertData = {
      'result_id': resultId,
      'question_id': questionId,
      'user_answer': transcript,
      'audio_url': audioUrl,
      'is_correct': null, 
      'ai_score': null, 
      'ai_feedback': null, 
      'graded_at': null, 
      'answered_at': DateTime.now().toIso8601String(),
    };

    debugPrint('💾 Saving to database: ${insertData.keys.toList()}');

    await _supabase.from('user_test_answers').upsert(
      insertData,
      onConflict: 'result_id,question_id',
    );

    debugPrint('✅ Speaking answer saved: $questionId');
  } catch (e) {
    debugPrint('❌ Error saving speaking answer: $e');
    rethrow;
  }
}


Future<Map<String, dynamic>> gradeSpeaking({
  required TestQuestion question,
  required String transcript,
}) async {
  try {
    debugPrint('🤖 Grading speaking question: ${question.id}');
    
    final result = await _aiService.gradeSpeaking(
      questionText: question.questionText ?? '',
      userAnswer: transcript,
      referenceText: question.referenceText,
      speakingMode: question.speakingMode ?? 'free_speaking',
      expectedAnswer: question.expectedAnswer,
      guideline: question.guideline,
      provider: 'groq',
    );

    debugPrint('✅ Speaking graded - Score: ${result['total_score']}');
    debugPrint('📊 Feedback: ${result}');
    
    return result;
  } catch (e) {
    debugPrint('❌ Error grading speaking: $e');
    rethrow;
  }
}
/// ✅ Update AI score in database (FIXED - Ensure all fields are updated)
Future<void> updateAiScore({
  required String resultId,
  required String questionId,
  required Map<String, dynamic> aiResult,
}) async {
  try {
    final updateData = {
      'ai_score': aiResult['total_score'],
      'ai_feedback': aiResult, // ✅ Store full feedback as JSONB
      'graded_at': DateTime.now().toIso8601String(),
      'is_correct': (aiResult['total_score'] ?? 0) >= 60,
    };

    debugPrint('💾 Updating AI score: $updateData');

    final response = await _supabase
        .from('user_test_answers')
        .update(updateData)
        .match({
          'result_id': resultId,
          'question_id': questionId,
        })
        .select();

    debugPrint('✅ AI score updated: ${response}');
  } catch (e) {
    debugPrint('❌ Error updating AI score: $e');
    debugPrint('   Result ID: $resultId');
    debugPrint('   Question ID: $questionId');
    rethrow;
  }
}
  /// ✅ Clear current recording state
  void clearState() {
    _currentTranscript = '';
    _currentAudioPath = null;
    _secondsRecorded = 0;
    _isRecording = false;
    _isPaused = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void resetState() {
    _currentTranscript = '';
    _currentAudioPath = null;
    _secondsRecorded = 0;
    _isRecording = false;
    _isPaused = false;
    notifyListeners();
    debugPrint('🔄 Speaking service state reset');
  }
  void restoreTranscript(String transcript) {
    _currentTranscript = transcript;
    notifyListeners();
    debugPrint('🔄 Transcript restored: ${transcript.substring(0, transcript.length > 50 ? 50 : transcript.length)}...');
  }
}