import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

class LearningService {
  final SupabaseClient _supabase;
  final _authService = AuthService();

  LearningService({required SupabaseClient supabase}) : _supabase = supabase;

  // ==================== USER ID METHODS ====================
  
  /// 🔥 Get current user ID from auth_id (primary method)
  Future<String?> getCurrentUserId() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        return null;
      }

      final authId = authUser.id;
      final userId = await _authService.getUserIdFromAuthId(authId);
      
      if (userId == null) {
        return null;
      }
      return userId; 
    } catch (e) {
      print('❌ Error getting current user ID: $e');
      return null;
    }
  }

  /// 🔥 Fetch user ID with priority for testing (users with wrong answers)
  /// This is useful for testing/debugging purposes
  Future<String?> fetchUserId() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      return null;
    }

    try {
      // LOGIC: Prioritize user ID with wrong answers for testing
      final wrongAttemptResponse = await _supabase
          .from('user_attempt_questions')
          .select('user_lesson_attempts!inner(user_id)')
          .eq('is_correct', false)
          .limit(1)
          .maybeSingle();

      final String? wrongUserId = wrongAttemptResponse?['user_lesson_attempts']?['user_id'] as String?;

      if (wrongUserId != null && wrongUserId.isNotEmpty) {
        print('🧪 Using test user ID with wrong answers: $wrongUserId');
        return wrongUserId;
      } else {
        // Fallback to logged-in user
        final loggedInUserResponse = await _supabase
            .from('users')
            .select('id')
            .eq('auth_id', authUser.id)
            .maybeSingle();

        return loggedInUserResponse?['id'] as String?;
      }
    } catch (e) {
      print('⚠️ Error in fetchUserId: $e');
      return null;
    }
  }

  // ==================== LEARNING MISTAKES METHODS ====================

  /// Lấy top 5 bài học user làm sai nhiều nhất
  Future<List<LearningMistake>> getTopMistakes(String userId) async {
    try {
      print('📡 Calling RPC get_user_top_mistakes...');
      print('📝 Params: p_user_id = $userId');

      final response = await _supabase.rpc(
        'get_user_top_mistakes',
        params: {'p_user_id': userId},
      );

      print('📥 RPC Response type: ${response.runtimeType}');
      print('📥 RPC Response: $response');

      if (response == null || response is! List) {
        print('⚠️ No mistakes data returned');
        return [];
      }

      final mistakes = (response as List)
          .map((item) {
            print('🔍 Processing item: $item');
            return LearningMistake.fromJson(item);
          })
          .toList();

      print('✅ Parsed ${mistakes.length} mistakes');
      for (var mistake in mistakes) {
        print('   - ${mistake.lessonName}: ${mistake.mistakeCount} errors');
      }

      return mistakes;
    } catch (e) {
      print('❌ Error getting top mistakes: $e');
      return [];
    }
  }

  /// Lấy gợi ý học tập (bài học sai nhiều nhất)
  Future<String?> getLearningSuggestion(String userId) async {
    try {
      final mistakes = await getTopMistakes(userId);
      
      if (mistakes.isEmpty) {
        return null;
      }

      final topMistake = mistakes.first;
      return 'Bạn làm sai ${topMistake.mistakeCount} câu trong "${topMistake.lessonName}"!';
    } catch (e) {
      print('❌ Error getting learning suggestion: $e');
      return null;
    }
  }

  /// Lấy top mistake với full info
  Future<LearningMistake?> getTopMistake(String userId) async {
    try {
      final mistakes = await getTopMistakes(userId);
      return mistakes.isEmpty ? null : mistakes.first;
    } catch (e) {
      print('❌ Error getting top mistake: $e');
      return null;
    }
  }

  // ==================== WRONG QUESTIONS METHODS ====================

  /// Lấy danh sách câu hỏi sai
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
      print('❌ Error fetching wrong questions: $e');
      rethrow;
    }
  }

  /// Cập nhật câu hỏi là đã ôn tập (is_correct = true)
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

      print('✅ Marked question $questionId as reviewed');
    } catch (e) {
      print('❌ Error marking as reviewed: $e');
      rethrow;
    }
  }
}

// ==================== MODELS ====================

/// Model cho learning mistake
class LearningMistake {
  final String lessonName;
  final int mistakeCount;
  final String source;

  LearningMistake({
    required this.lessonName,
    required this.mistakeCount,
    required this.source,
  });

  factory LearningMistake.fromJson(Map<String, dynamic> json) {
    return LearningMistake(
      lessonName: json['lesson_name'] as String? ?? 'Unknown Lesson',
      mistakeCount: (json['mistake_count'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? 'combined',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lesson_name': lessonName,
      'mistake_count': mistakeCount,
      'source': source,
    };
  }

  @override
  String toString() {
    return 'LearningMistake(lesson: $lessonName, mistakes: $mistakeCount, source: $source)';
  }
}