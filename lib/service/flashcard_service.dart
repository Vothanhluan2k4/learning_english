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

  // Public method to access user ID
  Future<String> getUserId() async {
    return await _getUserId();
  }

  // ... (rest of the FlashcardService code remains unchanged)
  // LIST WORD MANAGEMENT (CREATE, READ, UPDATE, DELETE)
  Future<List<ListWord>> getListWords() async {
    try {
      final userId = await _getUserId();
      final response = await _client
          .from('list_word_view')
          .select()
          .eq('user_id', userId);
      return response.map<ListWord>((json) => ListWord.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách bộ thẻ: $e');
    }
  }

  Future<void> createListWord(ListWord listWord) async {
    try {
      await _client.from('list_word').insert(listWord.toJson());
    } catch (e) {
      throw Exception('Lỗi khi tạo bộ thẻ: $e');
    }
  }

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

  Future<void> deleteListWord(String listId) async {
    try {
      await _client.from('list_word').delete().eq('id', listId);
    } catch (e) {
      throw Exception('Lỗi khi xóa list: $e');
    }
  }

  // WORD MANAGEMENT (CRUD)
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

  Future<void> createWord(Word word) async {
    try {
      await _client.from('word').insert(word.toJson());
    } catch (e) {
      throw Exception('Lỗi khi tạo thẻ: $e');
    }
  }

  Future<void> updateWord(Word word) async {
    try {
      if (word.id == null) throw Exception('ID của thẻ không hợp lệ');
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
          .update(payload)
          .eq('id', word.id!);
    } catch (e) {
      throw Exception('Lỗi khi cập nhật thẻ: $e');
    }
  }

  Future<void> createWords(List<Word> words) async {
    try {
      final wordData = words.map((word) => word.toJson()).toList();
      await _client.from('word').insert(wordData);
    } catch (e) {
      throw Exception('Lỗi khi tạo hàng loạt thẻ: $e');
    }
  }

  Future<void> deleteWord(String wordId) async {
    try {
      await _client.from('word').delete().eq('id', wordId);
    } catch (e) {
      throw Exception('Lỗi khi xóa thẻ: $e');
    }
  }

  Future<Map<String, int>> getProgress(String listId) async {
    try {
      final userId = await _getUserId();
      // Count total words in the list
      final totalWordsResponse = await _client
          .from('word')
          .select('id')
          .eq('list_word_id', listId)
          .count();
      final totalWords = totalWordsResponse.count;

      // Get word IDs for the given list
      final wordIdsResponse = await _client
          .from('word')
          .select('id')
          .eq('list_word_id', listId);
      final wordIds = wordIdsResponse.map((w) => w['id'] as String).toList();

      // Count words by status for the user and words in this list
      final statusResponse = await _client
          .from('user_word_status')
          .select('status')
          .eq('user_id', userId)
          .inFilter('word_id', wordIds); // Replaced 'in_' with 'inFilter'

      int studied = 0;
      int remembered = 0;
      int toReview = 0;

      for (var record in statusResponse) {
        final status = record['status'] as String;
        if (status == 'studied' || status == 'remembered' || status == 'to_review') {
          studied++;
        }
        if (status == 'remembered') {
          remembered++;
        }
        if (status == 'to_review') {
          toReview++;
        }
      }

      return {
        'total': totalWords,
        'studied': studied,
        'remembered': remembered,
        'to_review': toReview,
      };
    } catch (e) {
      print('Lỗi khi lấy tiến độ: $e');
      return {'total': 0, 'studied': 0, 'remembered': 0, 'to_review': 0};
    }
  }
  
  Future<void> updateWordStatus(String wordId, String status, String listId) async {  // Thêm param listId
    try {
      final userId = await _getUserId();
      await _client.from('user_word_status').upsert({
        'user_id': userId,
        'word_id': wordId,
        'status': status,
        'last_review': DateTime.now().toIso8601String(),
        'list_word_id': listId,  // Thêm này
      }, onConflict: 'user_id, word_id');
    } catch (e) {
      throw Exception('Lỗi khi cập nhật trạng thái từ: $e');
    }
  }

  Future<List<Word>> getReviewWords(String listId) async {
    try {
      final userId = await _getUserId();
      final response = await _client.rpc(
          'get_review_words_for_list',
          params: {'p_list_id': listId, 'p_user_id': userId});
      return (response as List).map((json) => Word.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải từ cần ôn tập: $e');
    }
  }

  Future<void> saveReviewHistory(String listId, int wordsReviewed, int wordsRemembered) async {
    try {
      final userId = await _getUserId();
      print('Saving review history for user $userId, list $listId'); // Debug
      await _client.from('review_history').insert({
        'user_id': userId,
        'list_word_id': listId,
        'review_date': DateTime.now().toIso8601String(),
        'words_reviewed': wordsReviewed,
        'words_remembered': wordsRemembered,
      });
    } catch (e) {
      print('Error saving review history: $e'); // Debug
      throw Exception('Lỗi khi lưu lịch sử ôn tập: $e');
    }
  }

  Future<bool> hasReviewHistory(String listId) async {
    try {
      final userId = await _getUserId();
      final response = await _client
          .from('review_history')
          .select('id')
          .eq('user_id', userId)
          .eq('list_word_id', listId)
          .limit(1);
      return response.isNotEmpty;
    } catch (e) {
      throw Exception('Lỗi khi kiểm tra lịch sử ôn tập: $e');
    }
  }
}