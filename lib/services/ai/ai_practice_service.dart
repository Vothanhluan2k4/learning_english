import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/ai_exceptions.dart';

class AiPracticeService {
  final _supabase = SupabaseConfig.client;

  /// Tạo session mới
  Future<String> createSession({
    required String userId,
    required String topic,
    required int questionCount,
    String? apiKeyId,
  }) async {
    try {
      final usedOwnApi = apiKeyId != null;

      final response = await _supabase
          .from('ai_practice_sessions')
          .insert({
            'user_id': userId,
            'topic': topic,
            'total_questions': questionCount,
            'used_own_api': usedOwnApi,
            'api_key_id': apiKeyId,
            'questions': [],
          })
          .select('id')
          .single();

      final sessionId = response['id'] as String;

      // Log usage
      await _supabase.from('ai_practice_usage').insert({
        'user_id': userId,
        'topic': topic,
        'question_count': questionCount,
        'used_own_api': usedOwnApi,
      });

      print('✅ Session created: $sessionId');
      return sessionId;
    } catch (e) {
      print('❌ Error creating session: $e');
      throw AiException('Không thể tạo session: $e');
    }
  }

  /// Update questions
  Future<void> updateSessionQuestions({
    required String sessionId,
    required List<Map<String, dynamic>> questions,
  }) async {
    try {
      await _supabase
          .from('ai_practice_sessions')
          .update({'questions': questions})
          .eq('id', sessionId);

      print('✅ Questions updated: $sessionId (${questions.length} questions)');
    } catch (e) {
      print('❌ Error updating questions: $e');
      throw AiException('Không thể cập nhật câu hỏi: $e');
    }
  }

  /// 🔥 FIX: Submit answers với mapping đúng
  Future<Map<String, dynamic>> submitAnswers({
    required String sessionId,
    required List<Map<String, dynamic>> userAnswers,
  }) async {
    try {
      print('📝 Submitting ${userAnswers.length} answers...');
      
      final session = await _supabase
          .from('ai_practice_sessions')
          .select('questions, total_questions, api_key_id')
          .eq('id', sessionId)
          .single();

      final questionsFromDb = List<Map<String, dynamic>>.from(session['questions'] ?? []);
      final totalQuestions = session['total_questions'] as int;
      final apiKeyId = session['api_key_id'];

      print('📊 Questions from DB: ${questionsFromDb.length}');
      print('📊 Total questions: $totalQuestions');
      print('📊 User answers: ${userAnswers.length}');

      // 🔥 FIX: Tạo map từ question_id → order_index
      final answerMap = <String, String>{};
      for (var answer in userAnswers) {
        final questionId = answer['question_id']?.toString();
        final selectedAnswer = answer['selected_answer']?.toString();
        
        if (questionId != null && selectedAnswer != null) {
          answerMap[questionId] = selectedAnswer;
        }
      }

      print('🗺️ Answer map: $answerMap');

      // Calculate score
      int correctCount = 0;
      
      for (int i = 0; i < questionsFromDb.length; i++) {
        final dbQuestion = questionsFromDb[i];
        final orderIndex = dbQuestion['order_index'] as int;
        final correctAnswer = dbQuestion['correct_answer']?.toString();
        
        // 🔥 FIX: Tìm user answer theo order_index
        // Giả sử question_id format: 'q1', 'q2', ... hoặc index-based
        String? userAnswer;
        
        // Try multiple formats
        final possibleIds = [
          'q${orderIndex + 1}',           // q1, q2, q3...
          'q_$orderIndex',                // q_0, q_1, q_2...
          orderIndex.toString(),          // 0, 1, 2...
        ];
        
        for (var id in possibleIds) {
          if (answerMap.containsKey(id)) {
            userAnswer = answerMap[id];
            break;
          }
        }
        
        // Also check by question_text hash (fallback)
        if (userAnswer == null) {
          for (var answer in userAnswers) {
            final answerId = answer['question_id']?.toString();
            if (answerId != null && answerMap.containsKey(answerId)) {
              // Last resort: match by index
              if (userAnswers.indexOf(answer) == orderIndex) {
                userAnswer = answer['selected_answer']?.toString();
                break;
              }
            }
          }
        }

        print('❓ Q$i (order: $orderIndex): user=$userAnswer, correct=$correctAnswer');

        if (userAnswer != null && correctAnswer != null && userAnswer == correctAnswer) {
          correctCount++;
        }
      }

      final score = totalQuestions > 0 
          ? (correctCount / totalQuestions * 100).toDouble()
          : 0.0;

      print('✅ Score calculated: $score% ($correctCount/$totalQuestions)');

      // Update session
      await _supabase
          .from('ai_practice_sessions')
          .update({
            'user_answers': userAnswers,
            'correct_answers': correctCount,
            'score': score,
            'completed': true,
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      // Update last_used_at
      if (apiKeyId != null) {
        await _supabase
            .from('user_api_keys')
            .update({'last_used_at': DateTime.now().toIso8601String()})
            .eq('id', apiKeyId);
      }

      print('✅ Answers submitted. Score: $score ($correctCount/$totalQuestions)');
      
      return {
        'score': score,
        'correct_count': correctCount,
        'total_questions': totalQuestions,
      };
    } catch (e) {
      print('❌ Error submitting answers: $e');
      throw AiException('Không thể submit: $e');
    }
  }

  /// Get session detail
  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    try {
      return await _supabase
          .from('ai_practice_sessions')
          .select()
          .eq('id', sessionId)
          .maybeSingle();
    } catch (e) {
      print('❌ Error getting session: $e');
      return null;
    }
  }

  /// Get user sessions
  Future<List<Map<String, dynamic>>> getUserSessions(
    String userId, {
    int limit = 10,
    bool completedOnly = false,
  }) async {
    try {
      var query = _supabase
          .from('ai_practice_sessions')
          .select('id, topic, score, total_questions, correct_answers, completed, created_at, completed_at, used_own_api')
          .eq('user_id', userId);

      if (completedOnly) {
        query = query.eq('completed', true);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting sessions: $e');
      return [];
    }
  }

  /// Get stats
  Future<Map<String, dynamic>> getStats(String userId) async {
    try {
      final sessions = await _supabase
          .from('ai_practice_sessions')
          .select('score, completed, total_questions, correct_answers')
          .eq('user_id', userId);

      final completedSessions = sessions.where((s) => s['completed'] == true).toList();
      
      final totalSessions = sessions.length;
      final completedCount = completedSessions.length;
      final avgScore = completedSessions.isEmpty
          ? 0.0
          : completedSessions.map((s) => s['score'] as num).reduce((a, b) => a + b) / completedCount;
      
      final totalQuestions = sessions.fold<int>(
        0, 
        (sum, s) => sum + (s['total_questions'] as int? ?? 0),
      );
      
      final totalCorrect = completedSessions.fold<int>(
        0,
        (sum, s) => sum + (s['correct_answers'] as int? ?? 0),
      );

      return {
        'total_sessions': totalSessions,
        'completed_sessions': completedCount,
        'avg_score': double.parse(avgScore.toStringAsFixed(2)),
        'total_questions': totalQuestions,
        'total_correct': totalCorrect,
        'accuracy': totalQuestions > 0 
            ? double.parse((totalCorrect / totalQuestions * 100).toStringAsFixed(2))
            : 0.0,
      };
    } catch (e) {
      print('❌ Error getting stats: $e');
      return {
        'total_sessions': 0,
        'completed_sessions': 0,
        'avg_score': 0.0,
        'total_questions': 0,
        'total_correct': 0,
        'accuracy': 0.0,
      };
    }
  }

  /// Delete incomplete session
  Future<bool> deleteSession(String sessionId) async {
    try {
      final session = await getSession(sessionId);
      
      if (session == null) {
        throw AiException('Session không tồn tại');
      }
      
      if (session['completed'] == true) {
        throw AiException('Không thể xóa session đã hoàn thành');
      }

      await _supabase
          .from('ai_practice_sessions')
          .delete()
          .eq('id', sessionId);

      print('✅ Session deleted: $sessionId');
      return true;
    } catch (e) {
      print('❌ Error deleting session: $e');
      return false;
    }
  }
}