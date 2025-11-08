// learning_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class LearningService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lấy user ID với logic ưu tiên test (có câu sai)
  Future<String?> fetchUserId() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      return null;
    }

    try {
      // LOGIC ƯU TIÊN ID CÓ CÂU SAI ĐỂ TEST
      final wrongAttemptResponse = await _supabase
          .from('user_attempt_questions')
          .select('user_lesson_attempts!inner(user_id)')
          .eq('is_correct', false)
          .limit(1)
          .maybeSingle();

      final String? wrongUserId = wrongAttemptResponse?['user_lesson_attempts']?['user_id'] as String?;

      if (wrongUserId != null && wrongUserId.isNotEmpty) {
        return wrongUserId;
      } else {
        final loggedInUserResponse = await _supabase
            .from('users')
            .select('id')
            .eq('auth_id', authUser.id)
            .maybeSingle();

        return loggedInUserResponse?['id'] as String?;
      }
    } catch (e) {
      // Có thể log lỗi nếu cần, nhưng không throw để giữ logic gốc
      return null;
    }
  }

  // Lấy danh sách câu hỏi sai
  Future<List<Map<String, dynamic>>> fetchWrongQuestions(String userId) async {
    if (userId.isEmpty) {
      return [];
    }

    try {
      final response = await _supabase.rpc(
        'get_user_wrong_items',
        params: {'user_uuid': userId},
      ) as List<dynamic>;

      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      rethrow;
    }
  }

  // Cập nhật câu hỏi là đã ôn tập (is_correct = true)
  Future<void> markAsReviewed(String type, Map<String, dynamic> item, String userId) async {
    final questionId = item['question_id']?.toString();
    if (questionId == null || questionId.isEmpty) {
      throw Exception('Không tìm thấy ID câu hỏi để cập nhật.');
    }

    try {
      if (type == 'roadmap') {
        // Cập nhật cho Lộ trình (Courses)
        final attemptId = item['attempt_id']?.toString();
        if (attemptId == null) {
          throw Exception('Thiếu attempt_id để cập nhật.');
        }

        await _supabase
            .from('user_attempt_questions')
            .update({'is_correct': true})
            .eq('attempt_id', attemptId)
            .eq('question_id', questionId);

      } else if (type == 'grammar') {
        // Cập nhật cho Ngữ pháp (Exercises)
        await _supabase
            .from('user_exercise_progress')
            .update({'is_correct': true})
            .eq('user_id', userId)
            .eq('exercise_id', questionId);
      }
    } catch (e) {
      rethrow;
    }
  }
}