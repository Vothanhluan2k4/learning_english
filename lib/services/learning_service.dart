import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

class LearningService {
  final SupabaseClient _supabase;
  final _authService = AuthService();

  LearningService({required SupabaseClient supabase}) : _supabase = supabase;

  /// 🔥 FIX: Get current user ID from auth_id
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
}

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