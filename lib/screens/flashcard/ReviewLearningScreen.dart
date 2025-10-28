import 'package:flutter/material.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/models/word.dart';
import 'package:learning_english/service/flashcard_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum Difficulty { none, easy, medium, hard }

class ReviewLearningScreen extends StatefulWidget {
  final ListWord list;
  final bool resetProgress;

  const ReviewLearningScreen({super.key, required this.list, this.resetProgress = false});

  @override
  State<ReviewLearningScreen> createState() => _ReviewLearningScreenState();
}

class _ReviewLearningScreenState extends State<ReviewLearningScreen> {
  bool _isFlipped = false;
  int _currentIndex = 0;
  List<Word> _allWords = [];
  List<Word> _reviewWords = [];
  List<Word> _skippedWords = [];
  bool _isLoading = true;
  bool _showAnswer = false;
  bool _isSessionDone = false;
  Difficulty _currentReviewLevel = Difficulty.none;
  bool _showAllWordsInReview = true;
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _meaningController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  Map<String, String> _wordStatuses = {}; // Bỏ từ khóa `final`

  @override
  void initState() {
    super.initState();
    _initializeTts();
    if (widget.resetProgress) {
      _resetProgress();
    }
    _loadAllWords();
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
      print('Lỗi khi reset tiến độ: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi reset tiến độ: $e')),
        );
      }
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
      // Lấy trạng thái từ
      final userId = await FlashcardService().getUserId();
      final statusResponse = await Supabase.instance.client
          .from('user_word_status')
          .select('word_id, status')
          .eq('user_id', userId)
          .eq('list_word_id', listId);

      final wordStatuses = <String, String>{};
      for (var record in statusResponse) {
        wordStatuses[record['word_id'] as String] = record['status'] as String;
      }

      if (mounted) {
        setState(() {
          _allWords = words;
          _wordStatuses = wordStatuses; // Bây giờ dòng này sẽ hoạt động
          _reviewWords = List.from(words);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print('Lỗi khi tải từ: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải từ: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Các phương thức còn lại không thay đổi
  Future<void> _playAudio(String word) async {
    if (word.isNotEmpty) {
      await flutterTts.speak(word);
    }
  }

  void _moveToNextWord() {
    if (_currentIndex < _reviewWords.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
        _showAnswer = false;
        _answerController.clear();
        _meaningController.clear();
        _currentReviewLevel = Difficulty.none;
      });
    } else {
      _completeSession();
    }
  }

  void _skipCurrentWord() {
    if (_reviewWords.isEmpty) return;
    final word = _reviewWords[_currentIndex];
    _wordStatuses[word.id!] = 'remembered';
    setState(() {
      _skippedWords.add(word);
      _reviewWords.removeAt(_currentIndex);
      if (_currentIndex >= _reviewWords.length) {
        _currentIndex = _reviewWords.isNotEmpty ? _reviewWords.length - 1 : 0;
      }
      if (_reviewWords.isEmpty) {
        _isSessionDone = true;
      } else {
        _isFlipped = false;
        _showAnswer = false;
        _answerController.clear();
        _meaningController.clear();
        _currentReviewLevel = Difficulty.none;
      }
    });
    _updateWordStatus(word.id!, 'remembered');
  }

  void _toggleCardFlip() {
    if (_currentReviewLevel == Difficulty.none) {
      setState(() => _isFlipped = !_isFlipped);
    }
  }

  void _handleStopLearning() {
    flutterTts.stop();
    _completeSession();
  }

  void _startReviewLevel(Difficulty level) {
    final word = _reviewWords[_currentIndex];
    String status;
    switch (level) {
      case Difficulty.easy:
        status = 'remembered';
        break;
      case Difficulty.medium:
        status = 'studied';
        break;
      case Difficulty.hard:
        status = 'to_review';
        break;
      default:
        status = 'studied';
    }
    _wordStatuses[word.id!] = status;
    _updateWordStatus(word.id!, status);
    setState(() {
      _currentReviewLevel = level;
      _isFlipped = false;
      _answerController.clear();
      _meaningController.clear();
      _showAnswer = false;
    });
  }

  Future<void> _updateWordStatus(String wordId, String status) async {
    try {
      await FlashcardService().updateWordStatus(wordId, status, widget.list.id!);
    } catch (e) {
      print('Lỗi khi cập nhật trạng thái từ $wordId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật trạng thái từ: $e')),
        );
      }
    }
  }

  Future<void> _completeSession() async {
    setState(() => _isSessionDone = true);
    try {
      final wordsReviewed = _wordStatuses.length;
      final wordsRemembered = _wordStatuses.values.where((status) => status == 'remembered').length;
      await FlashcardService().saveReviewHistory(widget.list.id!, wordsReviewed, wordsRemembered);
    } catch (e) {
      print('Lỗi khi lưu lịch sử ôn tập: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu lịch sử ôn tập: $e')),
        );
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _advanceDifficultyLevel() {
    final word = _reviewWords[_currentIndex];
    if (_currentReviewLevel == Difficulty.easy) {
      _wordStatuses[word.id!] = 'remembered';
      _updateWordStatus(word.id!, 'remembered');
      setState(() => _currentReviewLevel = Difficulty.medium);
    } else if (_currentReviewLevel == Difficulty.medium) {
      _wordStatuses[word.id!] = 'studied';
      _updateWordStatus(word.id!, 'studied');
      setState(() => _currentReviewLevel = Difficulty.hard);
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
        _meaningController.text = word.define;
      }
    });
  }

  void _checkAnswerAndAdvance({String? selectedChoice}) {
    final word = _reviewWords[_currentIndex];
    bool isCorrect = false;

    if (_showAnswer) {
      _advanceDifficultyLevel();
      return;
    }

    if (_currentReviewLevel == Difficulty.easy) {
      isCorrect = (selectedChoice == word.define);
    } else {
      final submittedWord = _answerController.text.trim().toLowerCase();
      final correctWord = word.word.trim().toLowerCase();
      final submittedMeaning = _meaningController.text.trim().toLowerCase();
      bool isWordCorrect = submittedWord == correctWord;
      bool isMeaningCorrect = _currentReviewLevel == Difficulty.hard
          ? submittedMeaning == word.define.trim().toLowerCase()
          : true;
      isCorrect = isWordCorrect && isMeaningCorrect;
    }

    if (isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chính xác!')));
      _advanceDifficultyLevel();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sai rồi. Vui lòng kiểm tra lại.')));
      _wordStatuses[word.id!] = 'to_review';
      _updateWordStatus(word.id!, 'to_review');
    }
  }

  void _advanceToNextMode(String difficulty) {
    final word = _reviewWords[_currentIndex];
    String status;
    switch (difficulty) {
      case 'Dễ':
        status = 'remembered';
        break;
      case 'Trung bình':
        status = 'studied';
        break;
      case 'Khó':
        status = 'to_review';
        break;
      default:
        status = 'studied';
    }
    _wordStatuses[word.id!] = status;
    _updateWordStatus(word.id!, status);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đánh giá: $difficulty. Chuyển sang chế độ điền từ.')),
    );
    setState(() {
      _currentReviewLevel = Difficulty.medium;
      _isFlipped = false;
      _answerController.clear();
      _meaningController.clear();
      _showAnswer = false;
    });
  }

  void _showReviewSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              titlePadding: EdgeInsets.zero,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 24, top: 24),
                    child: Text('Thiết lập chế độ review', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hiển thị tất cả các từ đã học (kể cả khi bạn bỏ qua một từ, từ đó sẽ xuất hiện trở lại khi bạn ôn tập hết các từ cần ôn)', style: TextStyle(fontSize: 14)),
                value: _showAllWordsInReview,
                onChanged: (bool? value) {
                  setDialogState(() {
                    _showAllWordsInReview = value ?? true;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt.')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSkippedWordsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              titlePadding: EdgeInsets.zero,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 24, top: 24),
                    child: Text('Danh sách từ đã biết, bỏ qua', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Click nút "Review" để thêm từ vào danh sách review', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 24),
                    if (_skippedWords.isEmpty)
                      const Text('Bạn chưa bỏ qua từ nào.')
                    else
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('Từ')),
                          DataColumn(label: Text('Hành động')),
                        ],
                        rows: _skippedWords.map((word) {
                          return DataRow(
                            cells: [
                              DataCell(Text(word.word)),
                              DataCell(
                                TextButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      _skippedWords.remove(word);
                                      _reviewWords.add(word);
                                    });
                                    setState(() {});
                                  },
                                  child: const Text('Review'),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_reviewWords.isEmpty && !_isSessionDone) {
      return Scaffold(
        appBar: AppBar(title: Text('Luyện tập: ${widget.list.title}')),
        body: Center(
          child: _skippedWords.isNotEmpty
              ? const Text('Tất cả các từ đã được bỏ qua.')
              : const Text('Bộ thẻ chưa có từ nào để luyện tập.'),
        ),
      );
    }

    final currentWord = _reviewWords.isNotEmpty && _currentIndex < _reviewWords.length ? _reviewWords[_currentIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Luyện tập: ${widget.list.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: _handleStopLearning,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeaderLinks(context),
            const SizedBox(height: 16),
            if (!_isSessionDone) ...[
              _buildNoticeBanner(),
              const SizedBox(height: 24),
              if (currentWord != null) _buildMainCard(context, currentWord),
              const SizedBox(height: 32),
              _buildAssessmentControls(context),
            ] else
              _buildCompletionView(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(BuildContext context, Word currentWord) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 300),
            padding: const EdgeInsets.all(32.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentReviewLevel == Difficulty.none ? _buildLearningModeContent(currentWord) : _buildReviewModeContent(currentWord),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLearningModeContent(Word word) {
    return Column(
      key: const ValueKey('learning'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Học', style: TextStyle(color: Colors.yellow.shade800, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
        SizedBox(
          height: 200,
          child: Center(
            child: _isFlipped ? _buildBackSide(word) : _buildFrontSide(word),
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
    );
  }

  Widget _buildFrontSide(Word word) {
    return Column(
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
        if (word.transcription != null && word.transcription!.isNotEmpty)
          Text(word.transcription!, style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildBackSide(Word word) {
    return Column(
      key: const ValueKey('back'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Định nghĩa:', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Text(word.define, textAlign: TextAlign.center, style: const TextStyle(fontSize: 36, color: Colors.black, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildReviewModeContent(Word word) {
    return Column(
      key: const ValueKey('review'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentReviewLevel == Difficulty.easy) _buildMultipleChoice(word),
        if (_currentReviewLevel == Difficulty.medium || _currentReviewLevel == Difficulty.hard) _buildFillInInputs(),
      ],
    );
  }

  Widget _buildMultipleChoice(Word word) {
    List<String> options = [word.define];
    final otherWords = _allWords.where((w) => w.id != word.id).toList();
    otherWords.shuffle();
    options.addAll(otherWords.take(3).map((w) => w.define));
    options.shuffle();

    return Column(
      children: [
        const Text('Chọn định nghĩa đúng:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 20),
        ...options.map((option) {
          bool isCorrectAnswer = (option == word.define);
          final buttonStyle = OutlinedButton.styleFrom(
            side: BorderSide(
              color: _showAnswer && isCorrectAnswer ? Colors.green : Colors.grey,
              width: _showAnswer && isCorrectAnswer ? 2.0 : 1.0,
            ),
            backgroundColor: _showAnswer && isCorrectAnswer ? Colors.green.shade50 : null,
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _checkAnswerAndAdvance(selectedChoice: option),
                style: buttonStyle,
                child: Text(option),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFillInInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Điền từ gốc:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        TextField(
          controller: _answerController,
          decoration: InputDecoration(
            hintText: 'Điền từ...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        if (_currentReviewLevel == Difficulty.hard) ...[
          const SizedBox(height: 16),
          const Text('Điền nghĩa của từ:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          TextField(
            controller: _meaningController,
            decoration: InputDecoration(
              hintText: 'Điền nghĩa...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAssessmentControls(BuildContext context) {
    if (_currentReviewLevel == Difficulty.none) {
      return _buildInitialAssessmentControls();
    }
    return _buildActiveReviewControls();
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
                _buildReviewButton('Dễ', Colors.green, Icons.sentiment_satisfied_alt, () => _startReviewLevel(Difficulty.easy)),
                _buildReviewButton('Trung bình', Colors.orange, Icons.sentiment_neutral, () => _startReviewLevel(Difficulty.medium)),
                _buildReviewButton('Khó', Colors.red, Icons.sentiment_dissatisfied, () => _startReviewLevel(Difficulty.hard)),
              ],
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: _skipCurrentWord,
              icon: Icon(Icons.keyboard_double_arrow_right, color: Colors.blue.shade600),
              label: Text('Đã biết, loại khỏi danh sách ôn tập', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewButton(String text, Color color, IconData icon, VoidCallback onPressed) {
    return Column(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 36, color: color),
        ),
        const SizedBox(height: 4),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActiveReviewControls() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _showCorrectAnswer,
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.blue),
                  label: const Text('Hiện đáp án', style: TextStyle(color: Colors.blue)),
                ),
                ElevatedButton(
                  onPressed: () => _checkAnswerAndAdvance(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Tiếp tục'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionView(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Chúc mừng! Bạn đã hoàn thành việc ôn tập.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Bạn đã ôn tập ${_wordStatuses.length} từ trong List ${widget.list.title}.', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _handleStopLearning,
              icon: const Icon(Icons.list),
              label: const Text('Xem tất cả & Tiến độ học tập'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderLinks(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: [
              TextButton(onPressed: _handleStopLearning, child: const Text('<< Xem tất cả', style: TextStyle(color: Colors.blue))),
              TextButton.icon(
                onPressed: _showReviewSettingsDialog,
                icon: const Icon(Icons.settings, size: 14, color: Colors.blue),
                label: const Text('Cài đặt chế độ review', style: TextStyle(color: Colors.blue)),
              ),
              TextButton(
                onPressed: _showSkippedWordsDialog,
                child: const Text('• Các từ đã bỏ qua', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _handleStopLearning,
          icon: const Icon(Icons.calendar_today, size: 14, color: Colors.red),
          label: const Text('Dừng học list từ này', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildNoticeBanner() {
    // Kiểm tra xem có từ mới hay không
    bool hasNewWords = _allWords.any((word) => !_wordStatuses.containsKey(word.id!));
    bool allWordsReviewed = _allWords.isNotEmpty &&
        _allWords.every((word) => _wordStatuses.containsKey(word.id!) && _wordStatuses[word.id!] != 'to_review');

    if (allWordsReviewed && hasNewWords) {
      // Hiển thị dialog hỏi người dùng
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showReviewChoiceDialog();
      });
      return const SizedBox.shrink(); // Không hiển thị banner tĩnh
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Text(
        'Chú ý: bạn đã học xong số lượng từ cần ôn tập trong hôm nay. Bạn có thể dừng lại việc ôn tập và quay lại vào hôm sau.',
        style: TextStyle(color: Colors.brown.shade800, fontSize: 13),
      ),
    );
  }

  void _showReviewChoiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Text('Chọn chế độ ôn tập', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'Bạn đã ôn tập hết các từ trong danh sách. Có muốn ôn lại từ đầu hay chỉ ôn các từ mới vừa thêm?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Ôn lại tất cả từ
                setState(() {
                  _reviewWords = List.from(_allWords);
                  _showAllWordsInReview = true;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Ôn lại tất cả'),
            ),
            TextButton(onPressed: () {
                // Chỉ ôn từ mới
                setState(() {
                  _reviewWords = _allWords
                      .where((word) => !_wordStatuses.containsKey(word.id!) || _wordStatuses[word.id!] == 'to_review')
                      .toList();
                  _showAllWordsInReview = false;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Chỉ ôn từ mới'),
            ),
          ],
        );
      },
    );
  }
}