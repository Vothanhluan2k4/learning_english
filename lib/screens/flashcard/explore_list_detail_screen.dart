import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learning_english/models/explore_list.dart';
import 'package:learning_english/models/explore_word.dart';
import 'package:learning_english/services/explore_service.dart';
import 'package:learning_english/screens/flashcard/learning_explore_screen.dart';
// THÊM IMPORT MÀN HÌNH RANDOM CHUYÊN BIỆT
import 'package:learning_english/screens/flashcard/random_explore_screen.dart';
// KẾT THÚC THÊM IMPORT

class ExploreListDetailScreen extends StatefulWidget {
  final ExploreList list;

  const ExploreListDetailScreen({super.key, required this.list});

  @override
  State<ExploreListDetailScreen> createState() => _ExploreListDetailScreenState();
}

class _ExploreListDetailScreenState extends State<ExploreListDetailScreen> {
  final ExploreService _exploreService = ExploreService();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isLoading = true;
  List<ExploreWord> _words = [];
  late ExploreList _currentList;
  bool _isProcessing = false;
  bool _hasFollowed = false;

  // --- Color Scheme ---
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color accentColor = Color(0xFF00B894);

  @override
  void initState() {
    super.initState();
    _currentList = widget.list;
    _initTts();
    _loadWords();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
  }

  Future<void> _loadWords() async {
    final listId = widget.list.id;
    if (listId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID list không hợp lệ.')),
        );
      }
      return;
    }

    try {
      setState(() => _isLoading = true);
      final data = await _exploreService.getExploreWords(listId);
      final detail = await _exploreService.getExploreListDetail(listId);
      final hasFollowed = await _exploreService.isFollowingList(listId);

      if (mounted) {
        setState(() {
          _words = data;
          if (detail != null) {
            _currentList = detail;
          }
          _hasFollowed = hasFollowed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải danh sách: $e')),
        );
      }
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  // ===========================================
  // 🔀 CHỨC NĂNG XÁO TRỘN: TRỎ ĐẾN MÀN HÌNH RANDOM CHUYÊN BIỆT
  // ===========================================
  void _shuffleList() {
    if (widget.list.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể bắt đầu học: List ID không hợp lệ.')),
      );
      return;
    }

    // Chuyển hướng đến màn hình RandomExploreScreen (tương tự RandomReviewScreen)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RandomExploreScreen(list: widget.list), // Trỏ đến màn hình xem ngẫu nhiên Explore
      ),
    );
  }
  // KẾT THÚC CHỨC NĂNG XÁO TRỘN

  void _startFlashcardSession() {
    if (widget.list.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể bắt đầu học: List ID không hợp lệ.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningExploreScreen(
          list: widget.list,
          mode: 'learn',
        ),
      ),
    );
  }

  Future<void> _handleFollowToggle() async {
    final listId = _currentList.id;
    if (listId == null) return;

    try {
      setState(() => _isProcessing = true);

      await _exploreService.updateFollowers(listId, !_hasFollowed); // Sử dụng hàm mới với toggle

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_hasFollowed ? 'Đã bỏ theo dõi "${_currentList.title}"!' : 'Đã theo dõi "${_currentList.title}"!')),
        );
      }

      await _loadWords();

      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xử lý theo dõi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _currentList.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              // VẪN GIỮ LOGIC PLACEHOLDER (HOẶC GỌI _handleSaveToMyDecks nếu đã code)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng lưu bộ thẻ đang phát triển...')),
              );
            },
            icon: const Icon(Icons.bookmark_add_outlined, color: primaryColor),
            tooltip: 'Lưu vào bộ thẻ của tôi',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            Text(
              'Đang tải từ vựng...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadWords,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ======================
              // 🔖 Header Card (UI giữ nguyên)
              // ======================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.1), accentColor.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentList.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (_currentList.description != null && _currentList.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _currentList.description!,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.library_books_rounded, color: primaryColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "${_words.length} từ",
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "${_currentList.followersCount ?? 0}",
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ======================
              // 🧠 Action Buttons (Logic đã cập nhật với toggle follow/unfollow)
              // ======================
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _startFlashcardSession, // Học Tuần tự (LearningExploreScreen, mode: learn)
                      icon: const Icon(Icons.play_circle_filled_rounded, size: 22),
                      label: const Text(
                        "Học ngay",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                        shadowColor: primaryColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _handleFollowToggle,
                      icon: _isProcessing
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Icon(
                        _hasFollowed ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 20,
                      ),
                      label: Text(_isProcessing ? 'Đang...' : (_hasFollowed ? 'Bỏ theo dõi' : 'Theo dõi')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _hasFollowed ? Colors.grey : Colors.redAccent,
                        side: BorderSide(color: _hasFollowed ? Colors.grey : Colors.redAccent, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: IconButton(
                      onPressed: _shuffleList, // Xem Ngẫu nhiên (RandomExploreScreen)
                      icon: const Icon(Icons.shuffle_rounded, color: Colors.black87, size: 22),
                      tooltip: 'Xáo trộn',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ======================
              // 📝 Word List Header (UI giữ nguyên)
              // ======================
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Danh sách từ vựng",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ======================
              // 📝 Word Cards (UI giữ nguyên)
              // ======================
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _words.length,
                itemBuilder: (context, index) {
                  final word = _words[index];
                  final wordType = word.wordType ?? '';
                  final transcription = word.transcription;
                  final define = word.define;
                  final example = word.example;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Word Header
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      word.word,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    if (wordType.isNotEmpty || (transcription != null && transcription.isNotEmpty)) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        "${wordType.isNotEmpty ? '($wordType)' : ''} ${transcription != null && transcription.isNotEmpty ? '/$transcription/' : ''}".trim(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.volume_up_rounded, color: accentColor),
                                  onPressed: () => _speak(word.word),
                                  tooltip: 'Phát âm',
                                ),
                              ),
                            ],
                          ),

                          if (define.isNotEmpty || (example != null && example.isNotEmpty)) ...[
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                          ],

                          // Definition
                          if (define.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[700],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Nghĩa",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      define,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Example
                          if (example != null && example.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber[700],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Ví dụ",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      example,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                        color: Colors.grey[700],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}