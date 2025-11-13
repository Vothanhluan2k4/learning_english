import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/explore_list.dart';
import 'package:learning_english/models/explore_word.dart';
import 'package:learning_english/core/supabase_config.dart';

class ExploreService {
  final SupabaseClient _client = Supabase.instance.client;

  // ===============================
  // 📘 LẤY DANH SÁCH CÁC LIST KHÁM PHÁ
  // ===============================
  Future<List<ExploreList>> getExploreLists() async {
    try {
      final response = await _client
          .from('explore_list')
          .select()
          .order('followers_count', ascending: false);

      return response.map<ExploreList>((json) => ExploreList.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách khám phá: $e');
    }
  }

  // ===============================
  // 🔍 LẤY CHI TIẾT MỘT LIST KHÁM PHÁ
  // ===============================
  Future<ExploreList?> getExploreListDetail(String listId) async {
    try {
      final response = await _client
          .from('explore_list')
          .select()
          .eq('id', listId)
          .maybeSingle();

      if (response == null) return null;
      return ExploreList.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi tải chi tiết danh sách khám phá: $e');
    }
  }

  // ===============================
  // 🧠 LẤY DANH SÁCH TỪ TRONG MỘT LIST
  // ===============================
  Future<List<ExploreWord>> getExploreWords(String exploreListId) async {
    try {
      final response = await _client
          .from('explore_word')
          .select()
          .eq('explore_list_id', exploreListId)
          .order('created_time', ascending: true);

      return response.map<ExploreWord>((json) => ExploreWord.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách từ vựng: $e');
    }
  }

  // ===============================
  // 🧮 ĐẾM SỐ TỪ TRONG DANH SÁCH KHÁM PHÁ
  // ===============================
  // Phương thức đã được định nghĩa chính xác trong ExploreService
  Future<int> getWordCountByListId(String exploreListId) async {
    try {
      // Lấy danh sách id (chỉ id) rồi trả về độ dài list
      final response = await _client
          .from('explore_word')
          .select('id') // lấy mỗi id (nhẹ hơn lấy toàn bộ trường)
          .eq('explore_list_id', exploreListId);

      if (response == null) return 0;
      if (response is List) {
        return response.length;
      }

      // Nếu SDK trả về kiểu khác, cố gắng ép về List
      final list = List.from(response);
      return list.length;
    } catch (e) {
      throw Exception('Lỗi khi đếm số từ vựng: $e');
    }
  }
  // ===============================
  // 📖 HỌC / LUYỆN TẬP TỪ (FLASHCARD)
  // ===============================
  Future<List<ExploreWord>> getWordsForLearning({
    required String exploreListId,
    String mode = 'learn',
  }) async {
    try {
      final words = await getExploreWords(exploreListId);

      if (mode == 'learn') {
        return words.take(10).toList();
      } else if (mode == 'practice') {
        words.shuffle();
        return words.take(10).toList();
      } else {
        return words;
      }
    } catch (e) {
      throw Exception('Lỗi khi lấy danh sách từ để học: $e');
    }
  }

  // ===============================
  // ❤️ THEO DÕI (FOLLOW) DANH SÁCH KHÁM PHÁ
  // ===============================
  // Future<void> followExploreList(String exploreListId) async {
  //   try {
  //     await _client.rpc('increment_followers_count', params: {'p_list_id': exploreListId});
  //   } catch (e) {
  //     throw Exception('Lỗi khi theo dõi danh sách khám phá: $e');
  //   }
  // }
  Future<void> updateFollowers(String exploreListId, bool follow) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.rpc('update_followers_count', params: {'p_list_id': exploreListId, 'p_follow': follow});
    } catch (e) {
      throw Exception('Lỗi khi cập nhật theo dõi: $e');
    }
  }
  // Future<void> unfollowExploreList(String exploreListId) async {
  //   final supabase = Supabase.instance.client;
  //   try {
  //     await supabase.rpc('decrement_followers_count', params: {'p_list_id': exploreListId});
  //   } catch (e) {
  //     throw Exception('Lỗi khi bỏ theo dõi danh sách Khám phá: $e');
  //   }
  // }
  Future<bool> isFollowingList(String listId) async {
    final supabase = Supabase.instance.client;
    final authUserId = supabase.auth.currentUser?.id;
    if (authUserId == null) return false;

    try {
      // Lấy user_id từ bảng users dựa trên auth_id
      final userResponse = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', authUserId)
          .single();

      final userId = userResponse['id'] as String?;
      if (userId == null) return false;

      // Kiểm tra đã theo dõi chưa
      final response = await supabase
          .from('list_followers')
          .select('id')
          .eq('list_id', listId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Lỗi kiểm tra theo dõi: $e');
      return false;
    }
  }
  Future<List<Map<String, dynamic>>> getWordStatusesForUser({
    required String authId,
    required String exploreListId,
  }) async {
    final supabase = Supabase.instance.client;

    // Bước 1: Lấy internal user ID (user_id từ bảng users)
    final userResponse = await supabase
        .from('users')
        .select('id')
        .eq('auth_id', authId)
        .maybeSingle();

    final internalUserId = userResponse?['id'] as String?;
    if (internalUserId == null) return []; // Không tìm thấy user nội bộ

    // Bước 2: Tải trạng thái tiến độ dựa trên ID nội bộ
    final statusResponse = await supabase
        .from('user_explore_word_status')
        .select('explore_word_id, status')
        .eq('user_id', internalUserId) // Dùng ID nội bộ đã lấy
        .eq('explore_list_id', exploreListId);

    return statusResponse as List<Map<String, dynamic>>? ?? [];
  }
}
