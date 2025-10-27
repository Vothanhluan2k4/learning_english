import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/models/word.dart';

class FlashcardService {
  // Instance variables
  final SupabaseClient _client = Supabase.instance.client;
  String? _cachedUserId;

  // User authentication methods
  Future<String> _getUserId() async {
    if (_cachedUserId != null) return _cachedUserId!;
    final authId = _client.auth.currentUser?.id;
    if (authId == null) throw Exception('Người dùng chưa đăng nhập');

    final user = await _client
        .from('users')
        .select('id')
        .eq('auth_id', authId)
        .maybeSingle();

    if (user == null) throw Exception('Người dùng không tồn tại');
    _cachedUserId = user['id'] as String;
    return _cachedUserId!;
  }

  // ====================================================================
  // LIST WORD MANAGEMENT (CREATE, READ, UPDATE, DELETE)
  // ====================================================================
// SỬA ĐỔI: Gọi VIEW để lấy cột word_count
  Future<List<ListWord>> getListWords() async {
    try {
      final userId = await _getUserId();
      // THAY ĐỔI: Gọi 'list_word_view' thay vì 'list_word'
      final response = await _client
          .from('list_word_view')
          .select()
          .eq('user_id', userId);
      return response.map<ListWord>((json) => ListWord.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách bộ thẻ: $e');
    }
  }
  // CREATE
  Future<void> createListWord(ListWord listWord) async {
    try {
      await _client.from('list_word').insert(listWord.toJson());
    } catch (e) {
      throw Exception('Lỗi khi tạo bộ thẻ: $e');
    }
  }

  // UPDATE
  Future<void> updateListWord(ListWord listWord) async {
    try {
      if (listWord.id == null) throw Exception('ID của bộ thẻ không hợp lệ');

      final String id = listWord.id!;

      await _client
          .from('list_word')
          .update(listWord.toJson())
          .eq('id', id);
    } catch (e) {
      throw Exception('Lỗi khi cập nhật bộ thẻ: $e');
    }
  }

  // DELETE: XÓA LIST TỪ VÀ TẤT CẢ TỪ LIÊN QUAN (Sửa và Hoàn thiện)
  Future<void> deleteListWord(String listId) async {
    try {
      // Giả định bảng 'word' có FOREIGN KEY với ON DELETE CASCADE
      await _client.from('list_word').delete().eq('id', listId);
    } catch (e) {
      throw Exception('Lỗi khi xóa list: $e');
    }
  }
// Trong FlashcardService.dart
  // ====================================================================
  // WORD MANAGEMENT (CRUD)
  // ====================================================================

  // COUNT
  Future<int> getWordCount(String listWordId) async {
    try {
      final query = _client
          .from('word')
          .select('id')
          .eq('list_word_id', listWordId);

      final postgrestFilterBuilder = query.count();
      final countResponse = await postgrestFilterBuilder;

      return countResponse.count.toInt();

    } catch (e) {
      print('Lỗi khi lấy số lượng từ cho list $listWordId: $e');
      return 0;
    }
  }

  // READ
  Future<List<Word>> getWords(String listWordId) async {
    try {
      final response = await _client
          .from('word')
          .select()
          .eq('list_word_id', listWordId);
      return response.map<Word>((json) => Word.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách thẻ: $e');
    }
  }

  // CREATE
  Future<void> createWord(Word word) async {
    try {
      await _client.from('word').insert(word.toJson());
    } catch (e) {
      throw Exception('Lỗi khi tạo thẻ: $e');
    }
  }

  // Trong FlashcardService.dart

// UPDATE: CHỈNH SỬA NỘI DUNG TỪ
  Future<void> updateWord(Word word) async {
    try {
      if (word.id == null) throw Exception('ID của thẻ không hợp lệ');

      // Tạo payload chỉ với các trường cần thiết, tránh gửi createdTime và các trường null
      final payload = {
        'word': word.word,
        'define': word.define,
        'picture_url': word.pictureUrl,
        'word_type': word.wordType,
        'transcription': word.transcription,
        'example': word.example,
        'note': word.note,
      };

      await _client
          .from('word')
          .update(payload) // Gửi payload đã lọc
          .eq('id', word.id!);

    } catch (e) {
      throw Exception('Lỗi khi cập nhật thẻ: $e');
    }
  }

  // CREATE BULK
  Future<void> createWords(List<Word> words) async {
    try {
      final wordData = words.map((word) => word.toJson()).toList();
      await _client.from('word').insert(wordData);
    } catch (e) {
      throw Exception('Lỗi khi tạo hàng loạt thẻ: $e');
    }
  }

  // DELETE
  Future<void> deleteWord(String wordId) async {
    try {
      await _client.from('word').delete().eq('id', wordId);
    } catch (e) {
      throw Exception('Lỗi khi xóa thẻ: $e');
    }
  }


  // BỔ SUNG: Hàm lấy dữ liệu tiến độ từ RPC Function
  Future<Map<String, int>> getProgress(String listId) async {
    try {
      final data = await _client.rpc(
          'get_list_progress',
          params: {'list_id_param': listId}
      );

      if (data != null && data.isNotEmpty) {
        final progress = data[0];
        return {
          'total': (progress['total_words'] ?? 0) as int,
          'studied': (progress['learning_words'] ?? 0) as int,
          'remembered': (progress['mastered_words'] ?? 0) as int,
          'to_review': (progress['new_words'] ?? 0) as int,
        };
      }
      return {'total': 0, 'studied': 0, 'remembered': 0, 'to_review': 0};
    } catch (e) {
      print('Lỗi khi lấy tiến độ: $e');
      return {'total': 0, 'studied': 0, 'remembered': 0, 'to_review': 0};
    }
  }

  // BỔ SUNG: Hàm cập nhật/thêm mới trạng thái của một từ
  Future<void> updateWordStatus(String wordId, String status) async {
    try {
      final userId = await _getUserId();
      await _client.from('user_word_status').upsert({
        'user_id': userId,
        'word_id': wordId,
        'status': status,
        'last_review': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, word_id');
    } catch (e) {
      throw Exception('Lỗi khi cập nhật trạng thái từ: $e');
    }
  }
  // BỔ SUNG: Hàm chỉ tải các từ cần ôn tập
  Future<List<Word>> getReviewWords(String listId) async {
    try {
      final userId = await _getUserId();
      final response = await _client.rpc(
          'get_review_words_for_list',
          params: {'p_list_id': listId, 'p_user_id': userId}
      );
      return (response as List).map((json) => Word.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải từ cần ôn tập: $e');
    }
  }
}