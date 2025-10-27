import 'dart:math';
import 'package:flutter/material.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/models/word.dart';
import 'package:learning_english/service/flashcard_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learning_english/screens/flashcard/review_session_screen.dart';
class RandomReviewScreen extends StatefulWidget {
  final ListWord list;

  const RandomReviewScreen({super.key, required this.list});

  @override
  State<RandomReviewScreen> createState() => _RandomReviewScreenState();
}

class _RandomReviewScreenState extends State<RandomReviewScreen> {
  // --- STATE ---
  List<Word> _allWords = [];
  Word? _currentWord;
  bool _isLoading = true;
  bool _isFlipped = false;
  final FlutterTts flutterTts = FlutterTts();
  int _currentIndex = 0; // Index để theo dõi từ hiện tại

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadAndShuffleWords();
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  // --- LOGIC ---

  void _initializeTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
  }

  // SỬA ĐỔI: Sử dụng dữ liệu thật từ FlashcardService
  Future<void> _loadAndShuffleWords() async {
    final listId = widget.list.id;
    if (listId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final words = await FlashcardService().getWords(listId);
      if (mounted) {
        setState(() {
          _allWords = words;
          if (_allWords.isNotEmpty) {
            _allWords.shuffle(); // Xáo trộn danh sách từ
            _currentIndex = 0;
            _currentWord = _allWords[_currentIndex];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print('Lỗi khi tải từ: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _moveToRandomWord() {
    if (_allWords.length <= 1) return;

    int newIndex;
    final random = Random();
    do {
      newIndex = random.nextInt(_allWords.length);
    } while (newIndex == _currentIndex);

    setState(() {
      _currentIndex = newIndex;
      _currentWord = _allWords[_currentIndex];
      _isFlipped = false;
    });
  }

  void _toggleCardFlip() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  Future<void> _playAudio(String text) async {
    if (text.isNotEmpty) {
      await flutterTts.speak(text);
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Xem ngẫu nhiên: ${widget.list.title}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentWord == null) {
      return const Center(
        child: Text(
          'Không có từ nào để xem ngẫu nhiên.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Card chính
                  _buildFlashcard(context, _currentWord!),
                  const SizedBox(height: 40),
                  // Các nút điều khiển
                  _buildControlButtons(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlashcard(BuildContext context, Word word) {
    return Card(
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 350),
        padding: const EdgeInsets.all(24.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _isFlipped ? _buildBackSide(word) : _buildFrontSide(word),
        ),
      ),
    );
  }

  Widget _buildFrontSide(Word word) {
    return Container(
      key: const ValueKey('front'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              word.word,
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold),
            ),
          ),
          if (word.transcription != null && word.transcription!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(word.transcription!, style: const TextStyle(fontSize: 20, color: Colors.grey)),
            ),
          const SizedBox(height: 20),
          IconButton(
            onPressed: () => _playAudio(word.word),
            icon: const Icon(Icons.volume_up, color: Colors.blue, size: 36),
            tooltip: 'Phát âm',
          ),
        ],
      ),
    );
  }

  Widget _buildBackSide(Word word) {
    return Container(
      key: const ValueKey('back'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word.define,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          IconButton(
            onPressed: () => _playAudio(word.word),
            icon: const Icon(Icons.volume_up, color: Colors.blue, size: 36),
            tooltip: 'Phát âm',
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Wrap(
      spacing: 20,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        // Nút Lật thẻ
        OutlinedButton.icon(
          onPressed: _toggleCardFlip,
          icon: const Icon(Icons.sync_alt),
          label: const Text('Lật thẻ'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
        // Nút Từ khác
        ElevatedButton.icon(
          onPressed: _moveToRandomWord,
          icon: const Icon(Icons.shuffle),
          label: const Text('Từ khác'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ],
    );
  }
}