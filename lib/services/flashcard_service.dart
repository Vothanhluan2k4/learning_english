import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/models/word.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../services/auth_service.dart';

class FlashcardService {
  // Instance variables
  final SupabaseClient _client = Supabase.instance.client;
  String? _cachedUserId;
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;

  // PHƯƠNG THỨC MỚI ĐỂ XÓA CACHE
  void clearUserCache() {
    _cachedUserId = null;
    print('FlashcardService user cache has been cleared.');
  }

  // User authentication methods
  Future<String> _getUserId() async {
    // Logic caching vẫn được giữ nguyên để tối ưu hiệu năng
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

  Future<void> createWord(Word word, {FilePickerResult? imageFile}) async {
    try {
      if (imageFile != null && imageFile.files.isNotEmpty) {
        final file = imageFile.files.first;

        // Đọc dữ liệu bytes: nếu không có bytes thì đọc từ path (fix cho emulator)
        Uint8List? fileBytes = file.bytes;
        if (fileBytes == null && file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes == null || fileBytes.isEmpty) {
          throw Exception('Dữ liệu hình ảnh không hợp lệ: File không chứa dữ liệu byte');
        }

        // Kiểm tra kích thước file (giới hạn 10MB)
        if (file.size > 10 * 1024 * 1024) {
          throw Exception('Kích thước file vượt quá 10MB');
        }

        // Kiểm tra định dạng file
        final extension = file.extension?.toLowerCase();
        if (extension != 'jpg' && extension != 'png' && extension != 'jpeg') {
          throw Exception('Định dạng ảnh không hợp lệ. Vui lòng chọn .jpg, .png hoặc .jpeg');
        }

        final fileExtension = file.extension ?? 'jpg';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final filePath = fileName;
        final contentType = 'image/$fileExtension';

        print('Attempting to upload to: WordImage/$filePath with contentType: $contentType, size: ${fileBytes.length} bytes');

        // Upload file lên Supabase
        await _client.storage.from('WordImage').uploadBinary(
          filePath,
          fileBytes,
          fileOptions: FileOptions(contentType: contentType),
        );

        // Lấy URL công khai
        final imageUrl = _client.storage.from('WordImage').getPublicUrl(filePath);
        print('Generated public URL: $imageUrl');

        // Cập nhật thông tin ảnh cho word
        word = word.copyWith(pictureUrl: imageUrl);
      }

      // Thêm word vào cơ sở dữ liệu
      await _client.from('word').insert(word.toJson());
    } catch (e) {
      print('Error during createWord: $e');
      throw Exception('Lỗi khi tạo thẻ: $e');
    }
  }


  Future<void> updateWord(Word word, {FilePickerResult? imageFile}) async {
    try {
      if (word.id == null) throw Exception('ID của thẻ không hợp lệ');

      if (imageFile != null && imageFile.files.isNotEmpty) {
        final file = imageFile.files.first;

        // Đọc dữ liệu bytes: nếu không có bytes thì đọc từ path (dành cho emulator)
        Uint8List? fileBytes = file.bytes;
        if (fileBytes == null && file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes == null || fileBytes.isEmpty) {
          throw Exception('Dữ liệu hình ảnh không hợp lệ: File không chứa dữ liệu byte');
        }

        // Kiểm tra kích thước file (giới hạn 10MB)
        if (file.size > 10 * 1024 * 1024) {
          throw Exception('Kích thước file vượt quá 10MB');
        }

        // Kiểm tra định dạng file (chỉ chấp nhận .jpg, .png, .jpeg)
        final extension = file.extension?.toLowerCase();
        if (extension != 'jpg' && extension != 'png' && extension != 'jpeg') {
          throw Exception('Định dạng ảnh không hợp lệ. Vui lòng chọn .jpg, .png hoặc .jpeg');
        }

        final fileExtension = file.extension ?? 'jpg';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final filePath = fileName;
        final contentType = 'image/$fileExtension';

        print(
            'Attempting to upload to: WordImage/$filePath with contentType: $contentType, size: ${fileBytes.length} bytes');

        // Upload file lên Supabase
        await _client.storage.from('WordImage').uploadBinary(
          filePath,
          fileBytes,
          fileOptions: FileOptions(contentType: contentType),
        );

        // Lấy URL công khai
        final imageUrl = _client.storage.from('WordImage').getPublicUrl(filePath);
        print('Generated public URL: $imageUrl');
        word = word.copyWith(pictureUrl: imageUrl);
      }

      // Cập nhật thông tin từ điển
      final payload = {
        'word': word.word,
        'define': word.define,
        'picture_url': word.pictureUrl,
        'word_type': word.wordType,
        'transcription': word.transcription,
        'example': word.example,
        'note': word.note,
      };

      await _client.from('word').update(payload).eq('id', word.id!);
    } catch (e) {
      print('Error during updateWord: $e');
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
  /// Lấy danh sách từ CHƯA HỌC (học mới) trong một list
  Future<List<Word>> getNewWords(String listId) async {
    try {
      final userId = await _getUserId();

      // Lấy tất cả từ trong list
      final allWordsResponse = await _client
          .from('word')
          .select()
          .eq('list_word_id', listId);

      final allWords = allWordsResponse.map<Word>((json) => Word.fromJson(json)).toList();
      final allWordIds = allWords.map((w) => w.id!).toList();

      if (allWordIds.isEmpty) return [];

      // Lấy các từ đã có trạng thái (đã học hoặc đang ôn)
      final statusResponse = await _client
          .from('user_word_status')
          .select('word_id')
          .eq('user_id', userId)
          .inFilter('word_id', allWordIds);

      final studiedWordIds = statusResponse.map((s) => s['word_id'] as String).toSet();

      // Lọc ra từ chưa học
      return allWords.where((word) => !studiedWordIds.contains(word.id!)).toList();
    } catch (e) {
      throw Exception('Lỗi khi lấy từ mới: $e');
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
  // Thay thế hàm saveReviewHistory cũ bằng hàm này
  Future<void> saveReviewHistory(String listId, int wordsReviewed, int wordsRemembered) async {
  try {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) throw Exception('User not authenticated');

    final authId = authUser.id;
    print('🔍 Step 1: authId = $authId');

    final userId = await _authService.getUserIdFromAuthId(authId);
    print('🔍 Step 2: userId = $userId');

    if (userId == null) {
      throw Exception('❌ User not found in users table for authId: $authId');
    }

    // ✅ KIỂM TRA user có tồn tại trong bảng users không
    final userCheck = await _client
        .from('users')
        .select('id, auth_id, email')
        .eq('id', userId)
        .maybeSingle();

    print('🔍 Step 3: User exists in users table: $userCheck');

    if (userCheck == null) {
      throw Exception('❌ userId $userId does not exist in users table!');
    }

    // ✅ KIỂM TRA list_word_id có tồn tại không
    final listCheck = await _client
        .from('list_word')
        .select('id')
        .eq('id', listId)
        .maybeSingle();

    print('🔍 Step 4: List exists: $listCheck');

    if (listCheck == null) {
      throw Exception('❌ listId $listId does not exist in list_word table!');
    }

    print('✅ All checks passed. Inserting review history...');
    print('   - userId: $userId');
    print('   - listId: $listId');
    print('   - wordsReviewed: $wordsReviewed');
    print('   - wordsRemembered: $wordsRemembered');

    await _client.from('review_history').insert({
      'user_id': userId,
      'list_word_id': listId,
      'review_date': DateTime.now().toIso8601String(),
      'words_reviewed': wordsReviewed,
      'words_remembered': wordsRemembered,
    });

    print('✅ Review history saved successfully!');
  } catch (e) {
    print('❌ Error saving review history: $e');
    rethrow;
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
  // Dán hàm này vào bên trong class FlashcardService của bạn
  Future<void> deleteReviewHistory(String listId) async {
    try {
      final authId = _client.auth.currentUser?.id;
      if (authId == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }

      // ✅ THÊM 2 DÒNG NÀY ĐỂ KIỂM TRA
      print('--- BẮT ĐẦU XÓA LỊCH SỬ ---');
      print('Đang tìm bản ghi với user_id (authId): $authId');
      print('Và list_word_id: $listId');

      final response = await _client
          .from('review_history')
          .delete()
          .eq('user_id', authId)
          .eq('list_word_id', listId);

    } catch (e) {
      print('Error deleting review history: $e');
      throw Exception('Lỗi xóa lịch sử ôn tập: $e');
    }
  }
  /// Xóa toàn bộ tiến độ học tập của một list (học lại từ đầu)
  Future<void> resetListProgress(String listId) async {
    try {
      final userId = await _getUserId();

      // Xóa toàn bộ trạng thái từ
      await _client
          .from('user_word_status')
          .delete()
          .eq('user_id', userId)
          .eq('list_word_id', listId);

      // Xóa lịch sử ôn tập
      await _client
          .from('review_history')
          .delete()
          .eq('user_id', userId)
          .eq('list_word_id', listId);
    } catch (e) {
      throw Exception('Lỗi khi đặt lại tiến độ: $e');
    }
  }

}