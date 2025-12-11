import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../models/writing_question.dart';
import '../ai/ai_grading_service.dart';

class WritingLessonService {
  final _supabase = Supabase.instance.client;
  final _aiService = AiGradingService();

  /// Fetch writing questions for a section
  Future<List<WritingQuestion>> fetchWritingQuestions(String sectionId) async {
    try {
      debugPrint('📝 Fetching writing questions for section: $sectionId');

      final response = await _supabase
          .from('lesson_questions')
          .select()
          .eq('section_id', sectionId)
          .eq('question_type', 'writing')
          .order('order_index', ascending: true);

      final questions = (response as List)
          .map((json) => WritingQuestion.fromJson(json))
          .toList();

      debugPrint('✅ Loaded ${questions.length} writing questions');
      return questions;
    } catch (e) {
      debugPrint('❌ Error fetching writing questions: $e');
      rethrow;
    }
  }

  /// Save user's writing answer
  Future<void> saveWritingAnswer({
    required String attemptId,
    required String questionId,
    required String userAnswer,
    int? timeSpent,
  }) async {
    try {
      debugPrint('💾 Saving writing answer for question: $questionId');

      await _supabase.from('user_attempt_questions').upsert({
        'attempt_id': attemptId,
        'question_id': questionId,
        'user_answer': userAnswer,
        'time_spent': timeSpent,
      }, onConflict: 'attempt_id,question_id');

      debugPrint('✅ Writing answer saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving writing answer: $e');
      rethrow;
    }
  }

  /// Submit writing for AI grading
  Future<Map<String, dynamic>> submitForAIGrading({
    required String questionText,
    required String userAnswer,
    int? minWords,
    int? maxWords,
    String? guideline,
    String provider = 'groq',
  }) async {
    try {
      // Validate
      final validation = _aiService.validateWriting(
        text: userAnswer,
        minWords: minWords,
        maxWords: maxWords,
      );

      if (!validation['isValid']) {
        throw Exception(validation['message']);
      }

      // Call AI grading
      final result = await _aiService.gradeWriting(
        questionText: questionText,
        userAnswer: userAnswer,
        minWords: minWords,
        maxWords: maxWords,
        guideline: guideline,
        provider: provider,
      );

      return result;
    } catch (e) {
      debugPrint('❌ Error submitting for AI grading: $e');
      rethrow;
    }
  }

  /// Save AI grading results
  Future<void> saveAIGradingResults({
    required String attemptId,
    required String questionId,
    required Map<String, dynamic> gradingResult,
  }) async {
    try {
      debugPrint('💾 Saving AI grading results');

      await _supabase.from('user_attempt_questions').update({
        'ai_score': gradingResult['total_score'],
        'ai_feedback': jsonEncode(gradingResult),
        'ai_graded_at': DateTime.now().toIso8601String(),
        'ai_provider': gradingResult['provider'],
        'ai_model': gradingResult['model'],
        'ai_grading_time_ms': gradingResult['grading_time_ms'],
      }).match({
        'attempt_id': attemptId,
        'question_id': questionId,
      });

      debugPrint('✅ AI grading results saved');
    } catch (e) {
      debugPrint('❌ Error saving AI grading results: $e');
      rethrow;
    }
  }

  /// Update user progress for lesson
  Future<void> updateLessonProgress({
    required String userId,
    required String lessonId,
    required String status,
    required double score,
    required bool isPassed,
    required int attempts,
  }) async {
    try {
      debugPrint('📊 Updating lesson progress: $status, score: $score, attempts: $attempts');

      final now = DateTime.now().toIso8601String();

      // ✅ Get lesson type to check if final_test
      final lessonInfo = await _supabase
          .from('lessons_course')
          .select('lesson_type')
          .eq('id', lessonId)
          .single();

      final lessonType = lessonInfo['lesson_type'] as String;
      debugPrint('📝 Lesson type: $lessonType');

      // ✅ IMPORTANT: Use same logic as UserAttemptService
      final finalStatus = isPassed ? 'completed' : status;
      final completedAt = isPassed ? now : null;

      // ✅ MUST use upsert with proper conflict handling
      await _supabase.from('user_progress_lessons_course').upsert(
        {
          'user_id': userId,
          'lesson_id': lessonId,
          'status': finalStatus,
          'score': score,
          'is_passed': isPassed,
          'attempts': attempts,
          'completed_at': completedAt,
          'updated_at': now,
        },
        onConflict: 'user_id,lesson_id', // ✅ This is CRITICAL
      );

      debugPrint('✅ Lesson progress updated: $finalStatus, isPassed: $isPassed');
      debugPrint('✅ This should trigger auto_unlock_next_lesson if lesson is passed');
    } catch (e) {
      debugPrint('❌ Error updating lesson progress: $e');
      rethrow;
    }
  }

  /// Get current progress for a lesson
  Future<Map<String, dynamic>?> getLessonProgress({
    required String userId,
    required String lessonId,
  }) async {
    try {
      final response = await _supabase
          .from('user_progress_lessons_course')
          .select()
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ Error getting lesson progress: $e');
      return null;
    }
  }

  /// Calculate best score from all attempts
  Future<double> getBestScore({
    required String userId,
    required String lessonId,
  }) async {
    try {
      final attempts = await _supabase
          .from('user_lesson_attempts')
          .select('score')
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .not('finished_at', 'is', null)
          .order('score', ascending: false)
          .limit(1);

      if (attempts.isEmpty) return 0.0;

      final score = attempts.first['score'];
      return score is int ? score.toDouble() : score as double;
    } catch (e) {
      debugPrint('❌ Error getting best score: $e');
      return 0.0;
    }
  }

  /// Count total attempts
  Future<int> getTotalAttempts({
    required String userId,
    required String lessonId,
  }) async {
    try {
      final attempts = await _supabase
          .from('user_lesson_attempts')
          .select('id')
          .eq('user_id', userId)
          .eq('lesson_id', lessonId);

      return attempts.length;
    } catch (e) {
      debugPrint('❌ Error counting attempts: $e');
      return 0;
    }
  }
}