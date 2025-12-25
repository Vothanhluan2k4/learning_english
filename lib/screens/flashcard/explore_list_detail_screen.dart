import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learning_english/models/explore_list.dart';
import 'package:learning_english/models/explore_word.dart';
import 'package:learning_english/services/explore_service.dart';
import 'package:learning_english/screens/flashcard/learning_explore_screen.dart';
import 'package:learning_english/screens/flashcard/random_explore_screen.dart';

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

  // Modern Color Scheme
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color accentColor = Color(0xFF00B894);
  static const Color bgColor = Color(0xFFF8F9FE);

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
        _showSnackBar('ID list không hợp lệ.', isError: true);
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
        _showSnackBar('Không thể tải danh sách: $e', isError: true);
      }
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _shuffleList() {
    if (widget.list.id == null) {
      _showSnackBar('Không thể bắt đầu học: List ID không hợp lệ.', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RandomExploreScreen(list: widget.list),
      ),
    );
  }

  void _startFlashcardSession() {
    if (widget.list.id == null) {
      _showSnackBar('Không thể bắt đầu học: List ID không hợp lệ.', isError: true);
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

      await _exploreService.updateFollowers(listId, !_hasFollowed);

      if (mounted) {
        _showSnackBar(
          _hasFollowed
              ? 'Đã bỏ theo dõi "${_currentList.title}"!'
              : 'Đã theo dõi "${_currentList.title}"!',
        );
      }

      await _loadWords();

      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackBar('Lỗi khi xử lý theo dõi: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[400] : accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _currentList.title,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _loadWords,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      _buildHeaderCard(),
                      const SizedBox(height: 20),

                      // Action Buttons
                      _buildActionButtons(),
                      const SizedBox(height: 32),

                      // Word List Header
                      _buildSectionHeader(),
                      const SizedBox(height: 16),

                      // Word Cards
                      _buildWordList(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'Đang tải từ vựng...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _currentList.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),

          // Description
          if (_currentList.description != null && _currentList.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _currentList.description!,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 15,
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Stats Row
          Row(
            children: [
              _buildStatBadge(
                icon: Icons.menu_book_rounded,
                label: '${_words.length} từ',
                gradient: LinearGradient(colors: [Colors.blue[600]!, Colors.blue[400]!]),
              ),
              const SizedBox(width: 12),
              _buildStatBadge(
                icon: Icons.favorite_rounded,
                label: '${_currentList.followersCount ?? 0}',
                gradient: LinearGradient(colors: [Colors.red[500]!, Colors.red[300]!]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildActionButtons() {
  return Row(
    children: [
      // 1. Nút "Học ngay" – chiếm phần lớn
      Expanded(
        child: _buildPrimaryButton(
          onPressed: _startFlashcardSession,
          icon: Icons.play_circle_filled_rounded,
          label: 'Học ',
          gradient: LinearGradient(
            colors: [primaryColor, primaryColor.withOpacity(0.8)],
          ),
        ),
      ),
      const SizedBox(width: 9),

      // 2. Nút Theo dõi / Bỏ theo dõi – dùng Flexible + FittedBox (tự co giãn thông minh)
      Flexible(
        fit: FlexFit.loose,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 150,    // Giới hạn tối đa (rất quan trọng!)
          ),
          child: _buildOutlineButton(
            onPressed: _isProcessing ? null : _handleFollowToggle,
            icon: _isProcessing
                ? null
                : (_hasFollowed ? Icons.favorite_rounded : Icons.favorite_border_rounded),
            label: _isProcessing
                ? 'Đang...'
                : (_hasFollowed ? 'Bỏ theo dõi' : 'Theo dõi'),
            color: _hasFollowed ? Colors.grey.shade600 : Colors.redAccent,
            isLoading: _isProcessing,
          ),
        ),
      ),
      const SizedBox(width: 9),

      // 3. Nút xáo trộn – cố định
      _buildIconButton(
        onPressed: _shuffleList,
        icon: Icons.shuffle_rounded,
        tooltip: 'Xáo trộn',
      ),
    ],
  );
}
  Widget _buildPrimaryButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Gradient gradient,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required VoidCallback? onPressed,
    required IconData? icon,
    required String label,
    required Color color,
    bool isLoading = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                else if (icon != null)
                  Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String tooltip,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Icon(icon, color: Colors.black87, size: 22),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, accentColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Danh sách từ vựng',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildWordList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _words.length,
      itemBuilder: (context, index) {
        final word = _words[index];
        return _WordCard(
          word: word,
          onSpeak: () => _speak(word.word),
        );
      },
    );
  }
}

class _WordCard extends StatefulWidget {
  final ExploreWord word;
  final VoidCallback onSpeak;

  const _WordCard({
    required this.word,
    required this.onSpeak,
  });

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final wordType = widget.word.wordType ?? '';
    final transcription = widget.word.transcription;
    final define = widget.word.define;
    final example = widget.word.example;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  Colors.blue[50]!.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
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
                              widget.word.word,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                            ),
                            if (wordType.isNotEmpty || (transcription != null && transcription.isNotEmpty)) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${wordType.isNotEmpty ? '($wordType)' : ''} ${transcription != null && transcription.isNotEmpty ? '/$transcription/' : ''}'.trim(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00B894),
                              const Color(0xFF00B894).withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00B894).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onSpeak,
                            borderRadius: BorderRadius.circular(14),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (define.isNotEmpty || (example != null && example.isNotEmpty)) ...[
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey[300]!,
                            Colors.grey[200]!,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Definition
                  if (define.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue[50]!,
                            Colors.blue[50]!.withOpacity(0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.blue[200]!.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[700]!, Colors.blue[500]!],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue[700]!.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Nghĩa',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              define,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: 0.1,
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
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber[50]!,
                            Colors.amber[50]!.withOpacity(0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.amber[200]!.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.amber[700]!, Colors.amber[500]!],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber[700]!.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Ví dụ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              example,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                                letterSpacing: 0.1,
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
          ),
        ),
      ),
    );
  }
}