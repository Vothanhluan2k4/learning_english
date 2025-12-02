import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class TestResultService {
  final _supabase = Supabase.instance.client;

  /// Save test progress
  Future<void> saveTestProgress({
    required String resultId,
    required int timeRemaining,
  }) async {
    try {
      await _supabase.from('user_test_results').update({
        'status': 'in_progress',
        'time_remaining': timeRemaining ~/ 60,
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('id', resultId);
      
      debugPrint('✅ Saved test progress: $resultId');
    } catch (e) {
      debugPrint('❌ Error saving test progress: $e');
      rethrow;
    }
  }

  /// Update last activity timestamp
  Future<void> updateLastActivity({
    required String resultId,
    required int timeRemaining,
  }) async {
    try {
      await _supabase.from('user_test_results').update({
        'time_remaining': timeRemaining ~/ 60,
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('id', resultId);
    } catch (e) {
      debugPrint('❌ Error updating last activity: $e');
      rethrow;
    }
  }

  /// Handle timeout
  Future<void> handleTimeout(String resultId) async {
    try {
      await _supabase.from('user_test_results').update({
        'status': 'timeout',
        'completed_at': DateTime.now().toIso8601String(),
        'time_remaining': 0,
      }).eq('id', resultId);
      
      debugPrint('✅ Handled timeout: $resultId');
    } catch (e) {
      debugPrint('❌ Error handling timeout: $e');
      rethrow;
    }
  }

  /// Create user test result
  Future<String?> createUserTestResult({
    required String userId,
    required String testId,
    int? timeRemaining,
  }) async {
    try {
      // Check existing result
      final existing = await _supabase
          .from('user_test_results')
          .select('id, status, time_remaining')
          .eq('user_id', userId)
          .eq('test_id', testId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('✅ Found existing result: ${existing['id']}');
        return existing['id'];
      }

      // Create new result
      final newResult = await _supabase.from('user_test_results').insert({
        'user_id': userId,
        'test_id': testId,
        'status': 'in_progress',
        'started_at': DateTime.now().toIso8601String(),
        'last_activity': DateTime.now().toIso8601String(),
        if (timeRemaining != null) 'time_remaining': timeRemaining,
      }).select('id').single();

      debugPrint('✅ Created new result: ${newResult['id']}');
      return newResult['id'];
    } catch (e) {
      debugPrint('❌ Error creating user test result: $e');
      rethrow;
    }
  }

  /// Submit test with score
  Future<void> submitTest({
    required String resultId,
    required double score,
    required int totalQuestions,
    required int correctAnswers,
    required bool isTimeout,
  }) async {
    try {
      await _supabase.from('user_test_results').update({
        'score': score,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'status': isTimeout ? 'timeout' : 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'time_remaining': 0,
      }).eq('id', resultId);
      
      debugPrint('✅ Test submitted: $resultId, score: $score');
    } catch (e) {
      debugPrint('❌ Error submitting test: $e');
      rethrow;
    }
  }

  /// Save user answer
  Future<void> saveAnswer({
    required String resultId,
    required String questionId,
    required String userAnswer,
    required String? correctAnswer,
  }) async {
    try {
      await _supabase.from('user_test_answers').upsert({
        'result_id': resultId,
        'question_id': questionId,
        'user_answer': userAnswer,
        'is_correct': userAnswer.trim().toLowerCase() == 
                      correctAnswer?.trim().toLowerCase(),
        'answered_at': DateTime.now().toIso8601String(),
      }, onConflict: 'result_id,question_id');
      
      debugPrint('✅ Saved answer for question: $questionId');
    } catch (e) {
      debugPrint('❌ Error saving answer: $e');
      rethrow;
    }
  }

  /// Update placement summary
  Future<void> updatePlacementSummary({
    required String userId,
    required String testId,
    required String resultId,
    required double score,
    String? recommendedCourseId,
  }) async {
    try {
      final result = await _supabase.rpc(
        'get_recommended_course_by_score',
        params: {
          'p_test_id': testId,
          'p_score': score,
        },
      );
      
      final actualRecommendedCourseId = result as String?;

      if (actualRecommendedCourseId == null) {
        debugPrint('⚠️ No recommended course found for score: $score');
        return;
      }

      await _supabase.from('user_placement_summary').upsert({
        'user_id': userId,
        'placement_test_id': testId,
        'latest_result_id': resultId,
        'score': score,
        'recommended_course_id': actualRecommendedCourseId, 
        'updated_at': DateTime.now().toIso8601String(),
      });
             
      debugPrint('✅ Updated placement summary');
    } catch (e) {
      debugPrint('❌ Error updating placement summary: $e');
      rethrow;
    }
  }

  /// Get placement data
  Future<Map<String, dynamic>?> getPlacementData({
    required String userId,
    required String testId,
  }) async {
    try {
      final data = await _supabase
          .from('user_placement_summary')
          .select('''
            score,
            courses:recommended_course_id (
              course_name
            )
          ''')
          .eq('user_id', userId)
          .eq('placement_test_id', testId)
          .maybeSingle();
      
      return data;
    } catch (e) {
      debugPrint('❌ Error getting placement data: $e');
      rethrow;
    }
  }
}