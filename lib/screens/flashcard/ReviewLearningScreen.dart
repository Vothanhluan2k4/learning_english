import 'package:flutter/material.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/models/word.dart';
import 'package:learning_english/services/flashcard_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/screens/flashcard/review_session_screen.dart';
import 'dart:math';

enum Difficulty { none, easy, medium, hard }

class ReviewLearningScreen extends StatefulWidget {
  final ListWord list;
  final bool resetProgress;

  const ReviewLearningScreen({super.key, required this.list, this.resetProgress = false});

  @override
  State<ReviewLearningScreen> createState() => _ReviewLearningScreenState();
}

class _ReviewLearningScreenState extends State<ReviewLearningScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  int _currentIndex = 0;
  List<Word> _allWords = [];
  List<Word> _reviewWords = [];
  List<Word> _skippedWords = [];
  bool _isLoading = true;
  bool _isFlipped = false;
  bool _showAnswer = false;
  bool _isSessionDone = false;
  Difficulty _currentReviewLevel = Difficulty.none;
  bool _showAllWordsInReview = true;
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _meaningController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  Map<String, String> _wordStatuses = {};
  late AnimationController _progressAnimationController;
  final ScrollController _scrollController = ScrollController();

  // Biến cờ theo dõi có bất kỳ từ nào được thay đổi status trong session không
  bool _hasStatusChanged = false;

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializeTts();
    if (widget.resetProgress) {
      _resetProgress().then((_) => _loadAllWords());
    } else {
      _loadAllWords();
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _meaningController.dispose();
    _progressAnimationController.dispose();
    _scrollController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  void _initializeTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
  }

  Future<void> _resetProgress() async {
    try {
      final userId = await FlashcardService().getUserId();
      await Supabase.instance.client
          .from('user_word_status')
          .delete()
          .eq('user_id', userId)
          .eq('list_word_id', widget.list.id!);
      // Đặt lại cờ thay đổi
      _hasStatusChanged = true;
    } catch (e) {
      _showSnackBar('Lỗi reset: $e', Colors.red);
    }
  }

  Future<void> _loadAllWords() async {
    final listId = widget.list.id;
    if (listId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final words = await FlashcardService().getReviewWords(listId);
      final userId = await FlashcardService().getUserId();
      final statusResponse = await Supabase.instance.client
          .from('user_word_status')
          .select('word_id, status')
          .eq('user_id', userId)
          .eq('list_word_id', listId);

      final wordStatuses = <String, String>{};
      for (var r in statusResponse) {
        wordStatuses[r['word_id'] as String] = r['status'] as String;
      }

      if (mounted) {
        setState(() {
          _allWords = words;
          _wordStatuses = wordStatuses;
          // Lọc ra các từ cần ôn tập (mặc định)
          _reviewWords = words.where((word) => wordStatuses[word.id] != 'remembered').toList();
          if (_reviewWords.isEmpty && words.isNotEmpty) {
            // Nếu không có từ nào cần ôn tập, nhưng list không rỗng, hiển thị toàn bộ.
            _reviewWords = List.from(words);
            _showAllWordsInReview = true;
          } else if (_reviewWords.isEmpty) {
            // Nếu list rỗng hoàn toàn
            _reviewWords = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar('Lỗi tải từ: $e', Colors.red);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _playAudio(String word) async {
    if (word.isNotEmpty) await flutterTts.speak(word);
  }

  void _moveToNextWord() {
    if (_currentIndex < _reviewWords.length - 1) {
      setState(() {
        _currentIndex++;
        _resetReviewState();
      });
      _progressAnimationController.forward(from: 0);
    } else {
      _completeSession();
    }
  }

  void _skipCurrentWord() {
    if (_reviewWords.isEmpty) return;
    final word = _reviewWords[_currentIndex];

    // Cập nhật trạng thái
    _wordStatuses[word.id!] = 'remembered';
    _updateWordStatus(word.id!, 'remembered');
    _hasStatusChanged = true; // Đánh dấu có thay đổi

    setState(() {
      _skippedWords.add(word);
      _reviewWords.removeAt(_currentIndex);

      if (_currentIndex >= _reviewWords.length && _reviewWords.isNotEmpty) {
        _currentIndex = _reviewWords.length - 1;
      }
      if (_reviewWords.isEmpty) _isSessionDone = true;

      _resetReviewState();
    });
  }

  void _toggleCardFlip() {
    if (_currentReviewLevel == Difficulty.none) {
      setState(() => _isFlipped = !_isFlipped);
    }
  }

  void _resetReviewState() {
    _isFlipped = false;
    _showAnswer = false;
    _answerController.clear();
    _meaningController.clear();
    _currentReviewLevel = Difficulty.none;
  }

  // ✨ ĐÃ SỬA: Hàm thoát màn hình học (Gửi tín hiệu refresh)
  void _handleStopLearning() {
    flutterTts.stop();
    // Trả về _hasStatusChanged (bool) cho màn hình cha
    if (mounted) {
      Navigator.of(context).pop(_hasStatusChanged);
    }
  }

  void _startReviewLevel(Difficulty level) {
    final word = _reviewWords[_currentIndex];
    final status = switch (level) {
      Difficulty.easy => 'remembered',
      Difficulty.medium => 'studied',
      Difficulty.hard => 'to_review',
      _ => 'studied',
    };
    _wordStatuses[word.id!] = status;
    _updateWordStatus(word.id!, status);

    // Đánh dấu có thay đổi khi bắt đầu level review
    _hasStatusChanged = true;

    setState(() {
      _currentReviewLevel = level;
      _isFlipped = false;
      _showAnswer = false;
      _answerController.clear();
      _meaningController.clear();
    });
  }

  Future<void> _updateWordStatus(String wordId, String status) async {
    try {
      await FlashcardService().updateWordStatus(wordId, status, widget.list.id!);
      // Cờ _hasStatusChanged đã được bật trước đó
    } catch (e) {
      _showSnackBar('Lỗi cập nhật: $e', Colors.red);
    }
  }

  // Logic hoàn thành session (Chỉ lưu và chuyển sang màn hình chúc mừng)
  Future<void> _completeSession() async {
    if (_isSessionDone) return; // Tránh gọi lại nhiều lần

    setState(() => _isSessionDone = true);

    // Logic lưu lịch sử
    try {
      final wordsReviewed = _wordStatuses.length;
      final wordsRemembered = _wordStatuses.values.where((s) => s == 'remembered').length;
      await FlashcardService().saveReviewHistory(widget.list.id!, wordsReviewed, wordsRemembered);
    } catch (e) {
      _showSnackBar('Lỗi lưu: $e', Colors.red);
    }
    // KHÔNG pop ở đây. Pop được thực hiện trong _buildCompletionView khi nhấn nút.
  }

  void _advanceDifficultyLevel() {
    final word = _reviewWords[_currentIndex];
    if (_currentReviewLevel == Difficulty.easy) {
      _wordStatuses[word.id!] = 'remembered';
      _updateWordStatus(word.id!, 'remembered');
      _startReviewLevel(Difficulty.medium);
    } else if (_currentReviewLevel == Difficulty.medium) {
      _wordStatuses[word.id!] = 'studied';
      _updateWordStatus(word.id!, 'studied');
      _startReviewLevel(Difficulty.hard);
    } else if (_currentReviewLevel == Difficulty.hard) {
      _wordStatuses[word.id!] = 'to_review';
      _updateWordStatus(word.id!, 'to_review');
      _moveToNextWord();
    }
    _hasStatusChanged = true; // Đảm bảo cờ thay đổi luôn được bật
  }

  void _showCorrectAnswer() {
    if (_showAnswer) return;
    final word = _reviewWords[_currentIndex];
    setState(() {
      _showAnswer = true;
      // ... (logic hiển thị đáp án giữ nguyên) ...
      if (_currentReviewLevel == Difficulty.medium) {
        _answerController.text = word.word;
      } else if (_currentReviewLevel == Difficulty.hard) {
        _answerController.text = word.word;
        _meaningController.text = word.define ?? '';
      }
    });
  }

  void _checkAnswerAndAdvance({String? selectedChoice}) {
    final word = _reviewWords[_currentIndex];
    bool isCorrect = false;

    if (_currentReviewLevel == Difficulty.easy) {
      isCorrect = (selectedChoice == word.define);
    } else {
      final submittedWord = _answerController.text.trim().toLowerCase();
      final correctWord = word.word.trim().toLowerCase();
      final submittedMeaning = _meaningController.text.trim().toLowerCase();
      final correctMeaning = (word.define ?? '').trim().toLowerCase();
      bool isWordCorrect = submittedWord == correctWord;
      bool isMeaningCorrect = _currentReviewLevel == Difficulty.hard ? submittedMeaning == correctMeaning : true;
      isCorrect = isWordCorrect && isMeaningCorrect;
    }

    if (isCorrect) {
      // 1. Đúng: Chuyển sang cấp độ khó hơn (hoặc từ tiếp theo)
      _showSnackBar('Chính xác! 🎉', Colors.green);
      _advanceDifficultyLevel();
    } else {
      // 2. Sai: Giữ nguyên từ, reset trạng thái nhập liệu và khuyến khích làm lại
      _showSnackBar('Chưa đúng, hãy thử lại! 💪', Colors.red); // Đổi màu SnackBar thành đỏ để nhấn mạnh lỗi

      // Đặt lại status của từ hiện tại về 'to_review' (hoặc giữ nguyên nếu đã là 'to_review')
      _wordStatuses[word.id!] = 'to_review';
      _updateWordStatus(word.id!, 'to_review');
      _hasStatusChanged = true; // Đánh dấu có thay đổi

      // ✨ QUAN TRỌNG: CHỈ reset UI, KHÔNG chuyển từ
      setState(() {
        // Reset các controller và cờ show answer
        _answerController.clear();
        _meaningController.clear();
        _showAnswer = false;

        // Nếu ở cấp độ gõ (Medium/Hard) mà sai, nên chuyển về cấp độ dễ hơn (Ví dụ: Easy)
        // để giúp người dùng ôn lại định nghĩa.
        if (_currentReviewLevel != Difficulty.easy) {
          _currentReviewLevel = Difficulty.easy;
        }
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(color == Colors.green ? Icons.check_circle : Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildWordImage(String? imageUrl) {
    if (imageUrl?.isEmpty ?? true) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          height: 180,
          width: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade100, Colors.grey.shade200],
                ),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade100, Colors.grey.shade200],
                ),
              ),
              child: Center(
                child: Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey.shade400),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 3),
                SizedBox(height: 20),
                Text('Đang tải...', style: TextStyle(fontSize: 16, color: Colors.black54)),
              ],
            ),
          ),
        ),
      );
    }

    if (_reviewWords.isEmpty && !_isSessionDone) {
      return Scaffold(
        appBar: _buildModernAppBar(),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.blue.shade300),
                const SizedBox(height: 20),
                Text(
                  _skippedWords.isNotEmpty ? 'Tất cả từ đã được bỏ qua' : 'Chưa có từ để ôn tập',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentWord = _reviewWords.isNotEmpty && _currentIndex < _reviewWords.length ? _reviewWords[_currentIndex] : null;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: _buildModernAppBar(),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                if (!_isSessionDone && currentWord != null) _buildProgressIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildHeaderLinks(),
                        const SizedBox(height: 20),
                        if (!_isSessionDone && currentWord != null) ...[
                          _buildFirstTimeBanner(),
                          const SizedBox(height: 24),
                          if (_currentReviewLevel != Difficulty.none)
                            _buildExerciseOnly(currentWord)
                          else
                            _buildWordCardWithLevels(currentWord),
                        ] else if (_isSessionDone)
                          _buildCompletionView(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black87),
        ),
        // ✨ ĐÃ SỬA: Gọi _handleStopLearning để trả về kết quả refresh
        onPressed: _handleStopLearning,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Luyện tập',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
          ),
          Text(
            widget.list.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
      centerTitle: false,
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _reviewWords.isEmpty ? 1.0 : (_currentIndex + 1) / _reviewWords.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1}/${_reviewWords.length}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstTimeBanner() {
    final isFirstTime = _allWords.any((w) => !_wordStatuses.containsKey(w.id!));
    if (!isFirstTime) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade100, Colors.orange.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.stars, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Bạn đang học từ mới lần đầu',
              style: TextStyle(fontSize: 15, color: Color(0xFF8B4513), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCardWithLevels(Word word) {
    return Column(
      children: [
        _buildWordCard(word),
        const SizedBox(height: 32),
        _buildInitialAssessmentControls(),
      ],
    );
  }

  Widget _buildExerciseOnly(Word word) {
    return Column(
      children: [
        _buildReviewModeContent(word),
        const SizedBox(height: 24),
        _buildActiveReviewControls(),
      ],
    );
  }

  Widget _buildWordCard(Word word) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.blue.shade50],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Học',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 220,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) {
                        final rotate = Tween(begin: pi, end: 0.0).animate(animation);
                        return AnimatedBuilder(
                          animation: rotate,
                          child: child,
                          builder: (context, child) {
                            final isUnder = (ValueKey(_isFlipped) != child!.key);
                            final value = isUnder ? min(rotate.value, pi / 2) : rotate.value;
                            return Transform(
                              transform: Matrix4.rotationY(value),
                              alignment: Alignment.center,
                              child: child,
                            );
                          },
                        );
                      },
                      child: _isFlipped ? _buildBackSide(word) : _buildFrontSide(word),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggleCardFlip,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(Icons.flip, color: Colors.blue.shade600, size: 24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrontSide(Word word) {
    return Column(
      key: const ValueKey('front'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                word.word,
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _playAudio(word.word),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.volume_up, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
        if (word.transcription?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            word.transcription!,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  Widget _buildBackSide(Word word) {
    return Container(
      key: const ValueKey('back'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Định nghĩa',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          Text(
            word.define ?? 'Không có định nghĩa',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.3),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor() {
    return switch (_currentReviewLevel) {
      Difficulty.easy => Colors.green.shade50,
      Difficulty.medium => Colors.orange.shade50,
      Difficulty.hard => Colors.red.shade50,
      _ => Colors.grey.shade100,
    };
  }

  Widget _buildReviewModeContent(Word word) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, _getLevelColor()],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (word.pictureUrl?.isNotEmpty == true) _buildWordImage(word.pictureUrl),
            if (_currentReviewLevel == Difficulty.easy) _buildMultipleChoice(word),
            if (_currentReviewLevel == Difficulty.medium || _currentReviewLevel == Difficulty.hard)
              _buildFillInInputs(word),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoice(Word word) {
    List<String> options = [word.define ?? ''];
    final others = _allWords.where((w) => w.id != word.id).toList()..shuffle();
    options.addAll(others.take(3).map((w) => w.define ?? '').where((d) => d.isNotEmpty));
    options.shuffle();

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.quiz, color: Colors.green.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Chọn định nghĩa đúng',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...options.map((opt) {
          final isCorrect = opt == word.define;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _checkAnswerAndAdvance(selectedChoice: opt),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: _showAnswer && isCorrect ? Colors.green.shade400 : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _showAnswer && isCorrect ? Colors.green.shade600 : Colors.grey.shade300,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _showAnswer && isCorrect ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFillInInputs(Word word) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentReviewLevel == Difficulty.medium) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.create, color: Colors.orange.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Định nghĩa',
                style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade200, width: 1.5),
            ),
            child: Text(
              word.define ?? 'Không có định nghĩa',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Điền từ tiếng Anh',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _answerController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Nhập từ vựng...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
              ),
              prefixIcon: Icon(Icons.edit_outlined, color: Colors.orange.shade600),
            ),
          ),
        ],
        if (_currentReviewLevel == Difficulty.hard) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.assignment, color: Colors.red.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Thử thách',
                style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Điền từ tiếng Anh',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _answerController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Nhập từ vựng...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.red.shade400, width: 2),
              ),
              prefixIcon: Icon(Icons.edit_outlined, color: Colors.red.shade600),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Điền nghĩa tiếng Việt',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _meaningController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Nhập nghĩa...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.red.shade400, width: 2),
              ),
              prefixIcon: Icon(Icons.translate, color: Colors.red.shade600),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActiveReviewControls() {
    final bool hasWord = _answerController.text.trim().isNotEmpty;
    final bool hasMeaning = _currentReviewLevel != Difficulty.hard || _meaningController.text.trim().isNotEmpty;
    final bool canCheck = hasWord && hasMeaning;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                child: OutlinedButton.icon(
                  onPressed: _showCorrectAnswer,
                  icon: const Icon(Icons.lightbulb_outline, size: 20),
                  label: const Text('Gợi ý', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade300, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                child: ElevatedButton(
                  onPressed: canCheck ? _checkAnswerAndAdvance : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canCheck
                        ? (_currentReviewLevel == Difficulty.medium ? Colors.orange.shade500 : Colors.red.shade500)
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: canCheck ? 4 : 0,
                    shadowColor: canCheck
                        ? (_currentReviewLevel == Difficulty.medium ? Colors.orange : Colors.red).withOpacity(0.4)
                        : Colors.transparent,
                  ),
                  child: const Text(
                    'Kiểm tra',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialAssessmentControls() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            const Text(
              'Đánh giá mức độ hiểu của bạn',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLevelButton('Dễ', Colors.green, Icons.sentiment_satisfied_alt, () => _startReviewLevel(Difficulty.easy)),
                _buildLevelButton('Trung bình', Colors.orange, Icons.sentiment_neutral, () => _startReviewLevel(Difficulty.medium)),
                _buildLevelButton('Khó', Colors.red, Icons.sentiment_dissatisfied, () => _startReviewLevel(Difficulty.hard)),
              ],
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: _skipCurrentWord,
              icon: Icon(Icons.check_circle_outline, color: Colors.blue.shade600, size: 20),
              label: const Text('Đã biết, bỏ qua', style: TextStyle(color: Colors.blue, fontSize: 15, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.shade200, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelButton(String text, Color color, IconData icon, VoidCallback onPressed) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(60),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 36, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.green.shade50],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_circle, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Xuất sắc!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                'Bạn đã hoàn thành ${_wordStatuses.length} từ',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'trong List "${widget.list.title}"',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // ✨ ĐÃ SỬA: Pop màn hình học và trả về TRUE để màn hình Session refresh.
                  if (mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                icon: const Icon(Icons.analytics_outlined, size: 22),
                label: const Text('Xem tiến độ học tập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: Colors.blue.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderLinks() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Wrap(
              spacing: 4,
              alignment: WrapAlignment.start,
              runSpacing: 4,
              children: [
                _buildHeaderButton(
                  icon: Icons.list_alt,
                  label: 'Tất cả',
                  // Nút này cũng nên gọi _handleStopLearning
                  onPressed: _handleStopLearning,
                ),
                _buildHeaderButton(
                  icon: Icons.settings_outlined,
                  label: 'Cài đặt',
                  onPressed: _showReviewSettingsDialog,
                ),
                _buildHeaderButton(
                  icon: Icons.bookmark_border,
                  label: 'Đã bỏ qua',
                  onPressed: _showSkippedWordsDialog,
                ),
              ],
            ),
          ),
          _buildHeaderButton(
            icon: Icons.stop_circle_outlined,
            label: 'Dừng',
            // ✨ ĐÃ SỬA: Gọi _handleStopLearning để trả về kết quả refresh
            onPressed: _handleStopLearning,
            color: Colors.red.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final buttonColor = color ?? Colors.blue.shade600;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: buttonColor),
      label: Text(label, style: TextStyle(color: buttonColor, fontSize: 13, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showReviewSettingsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.settings, color: Colors.blue.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Cài đặt ôn tập', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CheckboxListTile(
              title: const Text('Hiển thị tất cả từ', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Bao gồm cả từ đã học', style: TextStyle(fontSize: 13)),
              value: _showAllWordsInReview,
              activeColor: Colors.blue.shade600,
              onChanged: (v) => setDialogState(() => _showAllWordsInReview = v ?? true),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Hủy', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // Logic lọc từ giữ nguyên
                  _reviewWords = _showAllWordsInReview
                      ? List.from(_allWords)
                      : _allWords.where((w) => _wordStatuses[w.id!] == 'to_review').toList();
                });
                Navigator.of(dialogContext).pop();
                _showSnackBar('Đã lưu cài đặt ✓', Colors.blue);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSkippedWordsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bookmark, color: Colors.orange.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Từ đã bỏ qua', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          content: _skippedWords.isEmpty
              ? Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('Chưa có từ nào', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ],
            ),
          )
              : SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _skippedWords.length,
              itemBuilder: (context, index) {
                final word = _skippedWords[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        word.word[0].toUpperCase(),
                        style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(word.word, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(word.define ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: TextButton(
                      onPressed: () {
                        if (!mounted) return;
                        setDialogState(() {
                          _skippedWords.remove(word);
                          _reviewWords.add(word);
                          _hasStatusChanged = true; // Đánh dấu có thay đổi
                        });
                        setState(() {});
                      },
                      child: const Text('Ôn lại', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Đóng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}