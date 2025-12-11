import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../auth/auth_service.dart';

class SpeakingSubmissionService {
  final _supabase = SupabaseConfig.client;
  final _authService = AuthService();

  /// Upload audio file to Supabase Storage
  Future<String> uploadAudioFile({
    required String audioPath,
    required String questionId,
  }) async {
    try {
      final file = File(audioPath);
      
      if (!file.existsSync()) {
        throw Exception('Audio file not found: $audioPath');
      }

      final fileSize = file.lengthSync();
      debugPrint('📤 Uploading audio: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final userId = await _authService.getUserIdFromAuthId(authUser.id);
      if (userId == null) throw Exception('User not found');

      // Create unique filename: userId_questionId_timestamp.m4a
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${userId}_${questionId}_$timestamp.m4a';
      final filePath = 'speaking_audio/$fileName';

      debugPrint('📁 Upload path: $filePath');

      // Upload to Supabase Storage
      await _supabase.storage
          .from('audio_speaking_course') 
          .upload(
            filePath,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Get public URL
      final publicUrl = _supabase.storage
          .from('audio_speaking_course')
          .getPublicUrl(filePath);

      debugPrint('✅ Audio uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Error uploading audio: $e');
      rethrow;
    }
  }

  /// Save speaking submission to database
  Future<String> saveSpeakingSubmission({
    required String questionId,
    required String audioUrl,
    required String transcript,
    required double score,
    required Map<String, dynamic> feedback,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final userId = await _authService.getUserIdFromAuthId(authUser.id);
      if (userId == null) throw Exception('User not found');

      debugPrint('💾 Saving speaking submission for question: $questionId');

      final response = await _supabase
          .from('speaking_submissions')
          .insert({
            'user_id': userId,
            'question_id': questionId,
            'audio_url': audioUrl,
            'transcript': transcript,
            'score': score,
            'feedback': feedback.toString(), // Or jsonEncode(feedback)
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final submissionId = response['id'] as String;
      debugPrint('✅ Submission saved: $submissionId');
      
      return submissionId;
    } catch (e) {
      debugPrint('❌ Error saving submission: $e');
      rethrow;
    }
  }

  /// Save speaking answer to user_attempt_questions
  Future<void> saveSpeakingAnswer({
    required String attemptId,
    required String questionId,
    required String transcript,
    required Map<String, dynamic> aiResult,
    int? timeSpent,
  }) async {
    try {
      debugPrint('💾 Saving speaking answer for attempt: $attemptId');

      await _supabase
          .from('user_attempt_questions')
          .upsert({
            'attempt_id': attemptId,
            'question_id': questionId,
            'user_answer': transcript,
            'ai_score': aiResult['total_score'],
            'ai_feedback': aiResult.toString(), 
            'ai_graded_at': DateTime.now().toIso8601String(),
            'ai_provider': 'groq', // or from aiResult
            'ai_model': aiResult['model'] ?? 'llama-3.3-70b',
            'time_spent': timeSpent,
          }, onConflict: 'attempt_id,question_id');

      debugPrint('✅ Speaking answer saved to user_attempt_questions');
    } catch (e) {
      debugPrint('❌ Error saving speaking answer: $e');
      rethrow;
    }
  }

  /// Get user's speaking submissions for a question
  Future<List<Map<String, dynamic>>> getUserSubmissions({
    required String questionId,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final userId = await _authService.getUserIdFromAuthId(authUser.id);
      if (userId == null) throw Exception('User not found');

      final response = await _supabase
          .from('speaking_submissions')
          .select()
          .eq('user_id', userId)
          .eq('question_id', questionId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Error fetching submissions: $e');
      return [];
    }
  }

  /// Delete audio file from storage
  Future<void> deleteAudioFile(String audioUrl) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(audioUrl);
      final pathSegments = uri.pathSegments;
      
      // Find 'lesson-audio' segment index
      final bucketIndex = pathSegments.indexOf('lesson-audio');
      if (bucketIndex == -1) {
        throw Exception('Invalid audio URL format');
      }

      // Get file path after bucket name
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      
      debugPrint('🗑️ Deleting audio: $filePath');

      await _supabase.storage
          .from('lesson-audio')
          .remove([filePath]);

      debugPrint('✅ Audio deleted');
    } catch (e) {
      debugPrint('❌ Error deleting audio: $e');
      // Don't throw - deletion failure shouldn't block the flow
    }
  }

  /// ✅ NEW: Get latest completed attempt for a lesson
  Future<Map<String, dynamic>?> getLatestCompletedAttempt({
    required String lessonId,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final userId = await _authService.getUserIdFromAuthId(authUser.id);
      if (userId == null) throw Exception('User not found');

      final response = await _supabase
          .from('user_lesson_attempts')
          .select()
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .not('finished_at', 'is', null)
          .order('finished_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ Error fetching completed attempt: $e');
      return null;
    }
  }

  /// ✅ NEW: Get all answers from an attempt
  Future<Map<String, Map<String, dynamic>>> getAttemptAnswers({
    required String attemptId,
  }) async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📥 LOADING ATTEMPT ANSWERS (WITH JOIN)');
      debugPrint('Attempt ID: $attemptId');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Get user_id
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final userId = await _authService.getUserIdFromAuthId(authUser.id);
      if (userId == null) throw Exception('User not found');

      // ✅ Use RPC function for complex join (create this function in Supabase)
      // Or use multiple queries as above

      // For now, let's use the approach above (separate queries per question)
      // This is more compatible with Supabase Dart client

      final attemptsResponse = await _supabase
          .from('user_attempt_questions')
          .select()
          .eq('attempt_id', attemptId);

      final Map<String, Map<String, dynamic>> answers = {};
      final List<String> questionIds = [];
      
      // Collect all question IDs
      for (var item in attemptsResponse as List) {
        final data = item as Map<String, dynamic>;
        final questionId = data['question_id'] as String;
        questionIds.add(questionId);
        answers[questionId] = {...data};
      }

      if (questionIds.isEmpty) {
        debugPrint('ℹ️ No questions found for this attempt');
        return answers;
      }

      // ✅ Batch query all audio URLs at once
      final audioSubmissions = await _supabase
          .from('speaking_submissions')
          .select('question_id, audio_url, created_at')
          .eq('user_id', userId)
          .inFilter('question_id', questionIds)
          .order('created_at', ascending: false);

      // ✅ Group by question_id and take the latest
      final Map<String, String> audioUrlsByQuestion = {};
      for (var submission in audioSubmissions as List) {
        final data = submission as Map<String, dynamic>;
        final questionId = data['question_id'] as String;
        final audioUrl = data['audio_url'] as String?;
        
        // Only set if not already set (first one is latest due to ORDER BY)
        if (audioUrl != null && !audioUrlsByQuestion.containsKey(questionId)) {
          audioUrlsByQuestion[questionId] = audioUrl;
        }
      }

      // ✅ Merge audio URLs into answers
      int audioCount = 0;
      for (var questionId in questionIds) {
        if (audioUrlsByQuestion.containsKey(questionId)) {
          answers[questionId]!['audio_url'] = audioUrlsByQuestion[questionId];
          audioCount++;
          debugPrint('🎵 Audio for $questionId: ${audioUrlsByQuestion[questionId]}');
        } else {
          debugPrint('⚠️ No audio for $questionId');
        }
      }

      debugPrint('✅ Loaded ${answers.length} answers');
      debugPrint('🎵 $audioCount answers have audio URLs');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return answers;
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading attempt answers: $e');
      debugPrint('Stack trace: $stackTrace');
      return {};
    }
  }

  /// ✅ NEW: Get speaking submission with audio for a question
  Future<Map<String, dynamic>?> getLatestSubmission({
    required String questionId,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final userId = await _authService.getUserIdFromAuthId(authUser.id);
      if (userId == null) throw Exception('User not found');

      final response = await _supabase
          .from('speaking_submissions')
          .select()
          .eq('user_id', userId)
          .eq('question_id', questionId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ Error fetching latest submission: $e');
      return null;
    }
  }
}