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

class _ReviewLearningScreenState extends State<ReviewLearningScreen> {
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

  @override
  void initState() {
    super.initState();
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
          _reviewWords = List.from(words);
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
    } else {
      _completeSession();
    }
  }

  void _skipCurrentWord() {
    if (_reviewWords.isEmpty) return;
    final word = _reviewWords[_currentIndex];
    _wordStatuses[word.id!] = 'remembered';
    _updateWordStatus(word.id!, 'remembered');
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

  void _handleStopLearning() {
    flutterTts.stop();
    _completeSession();
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
    } catch (e) {
      _showSnackBar('Lỗi cập nhật: $e', Colors.red);
    }
  }

  Future<void> _completeSession() async {
    setState(() => _isSessionDone = true);
    try {
      final wordsReviewed = _wordStatuses.length;
      final wordsRemembered = _wordStatuses.values.where((s) => s == 'remembered').length;
      await FlashcardService().saveReviewHistory(widget.list.id!, wordsReviewed, wordsRemembered);
    } catch (e) {
      _showSnackBar('Lỗi lưu: $e', Colors.red);
    }
    if (mounted) Navigator.of(context).pop();
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
  }

  void _showCorrectAnswer() {
    if (_showAnswer) return;
    final word = _reviewWords[_currentIndex];
    setState(() {
      _showAnswer = true;
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
      _showSnackBar('Chính xác!', Colors.green);
      _advanceDifficultyLevel();
    } else {
      _showSnackBar('Sai rồi!', Colors.red);
      _wordStatuses[word.id!] = 'to_review';
      _updateWordStatus(word.id!, 'to_review');
      _moveToNextWord();
    }
  }

  void _showSnackBar(String message, Color color) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(milliseconds: 1000)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_reviewWords.isEmpty && !_isSessionDone) {
      return Scaffold(
        appBar: AppBar(title: Text('Ôn tập: ${widget.list.title}')),
        body: Center(child: Text(_skippedWords.isNotEmpty ? 'Tất cả từ đã bỏ qua.' : 'Chưa có từ để ôn.')),
      );
    }

    final currentWord = _reviewWords.isNotEmpty && _currentIndex < _reviewWords.length ? _reviewWords[_currentIndex] : null;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Luyện tập: ${widget.list.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: false,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: _handleStopLearning),
          backgroundColor: Colors.lightBlue.shade50,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeaderLinks(),
              const SizedBox(height: 16),
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
    );
  }

  Widget _buildFirstTimeBanner() {
    final isFirstTime = _allWords.any((w) => !_wordStatuses.containsKey(w.id!));
    if (!isFirstTime) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: const Text(
        'Bạn đang học từ mới lần đầu.',
        style: TextStyle(fontSize: 15, color: Color(0xFF8B4513), fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
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
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.yellow.shade200, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Học', style: TextStyle(color: Color(0xFF8A4B08), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
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
                      child: _isFlipped
                          ? _buildBackSide(word)
                          : _buildFrontSide(word),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                    onPressed: _toggleCardFlip,
                    icon: Icon(Icons.sync_alt, color: Colors.grey.shade600, size: 30),
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
            Text(word.word, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            IconButton(onPressed: () => _playAudio(word.word), icon: Icon(Icons.volume_up, color: Colors.blue.shade600, size: 32)),
          ],
        ),
        if (word.transcription?.isNotEmpty == true)
          Text(word.transcription!, style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildBackSide(Word word) {
    return Column(
      key: const ValueKey('back'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Định nghĩa:', style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 12),
        Text(word.define ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
      ],
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
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _getLevelColor(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentReviewLevel == Difficulty.easy) _buildMultipleChoice(word),
            if (_currentReviewLevel == Difficulty.medium || _currentReviewLevel == Difficulty.hard) _buildFillInInputs(),
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
        const Text('Chọn định nghĩa đúng:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 20),
        ...options.map((opt) {
          final isCorrect = opt == word.define;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ElevatedButton(
              onPressed: () => _checkAnswerAndAdvance(selectedChoice: opt),
              style: ElevatedButton.styleFrom(
                backgroundColor: _showAnswer && isCorrect ? Colors.green : Colors.white,
                foregroundColor: _showAnswer && isCorrect ? Colors.white : Colors.green,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(opt, style: const TextStyle(fontSize: 16)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFillInInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Điền từ:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        TextField(
          controller: _answerController,
          onChanged: (_) => setState(() {}), // TỰ ĐỘNG CẬP NHẬT KHI GÕ
          decoration: InputDecoration(
            hintText: 'Nhập từ...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        if (_currentReviewLevel == Difficulty.hard) ...[
          const SizedBox(height: 16),
          const Text('Điền nghĩa:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          TextField(
            controller: _meaningController,
            onChanged: (_) => setState(() {}), // TỰ ĐỘNG CẬP NHẬT
            decoration: InputDecoration(
              hintText: 'Nhập nghĩa...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
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
            // NÚT "HIỆN ĐÁP ÁN"
            OutlinedButton.icon(
              onPressed: _showCorrectAnswer,
              icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
              label: const Text('Hiện đáp án'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),

            // NÚT "KIỂM TRA" – LUÔN HIỂN THỊ
            ElevatedButton(
              onPressed: canCheck ? _checkAnswerAndAdvance : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canCheck
                    ? (_currentReviewLevel == Difficulty.medium ? Colors.orange : Colors.red)
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: canCheck ? 6 : 0,
              ),
              child: const Text(
                'Kiểm tra',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              icon: Icon(Icons.skip_next, color: Colors.blue.shade600),
              label: const Text('Đã biết, bỏ qua', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelButton(String text, Color color, IconData icon, VoidCallback onPressed) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
            elevation: 8,
          ),
          child: Icon(icon, size: 36),
        ),
        const SizedBox(height: 8),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: Card(
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text('Chúc mừng! Bạn đã hoàn thành việc ôn tập.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Bạn đã ôn tập ${_wordStatuses.length} từ trong List ${widget.list.title}.', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // CHUYỂN VỀ ReviewSessionScreen
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ReviewSessionScreen(list: widget.list), // Đảm bảo import đúng
                    ),
                  );
                },
                icon: const Icon(Icons.list),
                label: const Text('Xem tất cả & Tiến độ học tập'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Bọc Wrap trong Expanded để giới hạn chiều rộng và co giãn
        Expanded(
          child: Wrap(
            spacing: 8,
            alignment: WrapAlignment.start,
            runSpacing: 4, // Thêm khoảng cách giữa các dòng nếu có
            children: [
              TextButton(
                onPressed: _handleStopLearning,
                child: const Text('<< Xem tất cả', style: TextStyle(color: Colors.blue)),
              ),
              TextButton.icon(
                onPressed: () => _showReviewSettingsDialog(),
                icon: const Icon(Icons.settings, size: 14),
                label: const Text('Cài đặt'),
              ),
              TextButton(
                onPressed: () => _showSkippedWordsDialog(),
                child: const Text('Từ đã bỏ qua'),
              ),
            ],
          ),
        ),
        // Giới hạn chiều rộng của nút "Dừng học" bằng SizedBox
        SizedBox(
          width: 100, // Giới hạn chiều rộng cố định (có thể điều chỉnh)
          child: TextButton.icon(
            onPressed: _handleStopLearning,
            icon: const Icon(Icons.stop, size: 14, color: Colors.red),
            label: const Text('Dừng học', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }

  void _showReviewSettingsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Cài đặt ôn tập'),
          content: CheckboxListTile(
            title: const Text('Hiển thị tất cả từ'),
            value: _showAllWordsInReview,
            onChanged: (v) => setDialogState(() => _showAllWordsInReview = v ?? true),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _reviewWords = _showAllWordsInReview
                      ? List.from(_allWords)
                      : _allWords.where((w) => _wordStatuses[w.id!] == 'to_review').toList();
                });
                Navigator.of(dialogContext).pop();
                _showSnackBar('Đã lưu cài đặt', Colors.blue);
              },
              child: const Text('Lưu'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Từ đã bỏ qua'),
          content: _skippedWords.isEmpty
              ? const Text('Chưa có từ nào.')
              : SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [DataColumn(label: Text('Từ')), DataColumn(label: Text('Hành động'))],
                rows: _skippedWords.map((word) {
                  return DataRow(cells: [
                    DataCell(Text(word.word)),
                    DataCell(
                      TextButton(
                        onPressed: () {
                          if (!mounted) return;
                          setDialogState(() {
                            _skippedWords.remove(word);
                            _reviewWords.add(word);
                          });
                          setState(() {});
                        },
                        child: const Text('Ôn lại'),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Đóng'))],
        ),
      ),
    );
  }
}