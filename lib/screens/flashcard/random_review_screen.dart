import 'dart:math';
import 'package:flutter/material.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/models/word.dart';
import 'package:learning_english/services/flashcard_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class RandomReviewScreen extends StatefulWidget {
  final ListWord list;

  const RandomReviewScreen({super.key, required this.list});

  @override
  State<RandomReviewScreen> createState() => _RandomReviewScreenState();
}

class _RandomReviewScreenState extends State<RandomReviewScreen> with SingleTickerProviderStateMixin {
  List<Word> _allWords = [];
  Word? _currentWord;
  bool _isLoading = true;
  bool _isFront = true;
  final FlutterTts flutterTts = FlutterTts();
  int _currentIndex = 0;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // --- Modern Color Scheme ---
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color backgroundColor = Color(0xFFF5F6FA);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);

  @override
  void initState() {
    super.initState();
    _initializeTts();

    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _loadAndShuffleWords();
  }

  @override
  void dispose() {
    flutterTts.stop();
    _flipController.dispose();
    super.dispose();
  }

  void _initializeTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
  }

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
            _allWords.shuffle();
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
      _isFront = true;
      _flipController.reset();
    });
  }

  Future<void> _toggleCardFlip() async {
    if (_flipController.isAnimating) return;

    if (_isFront) {
      await _flipController.forward();
      if (mounted) {
        setState(() => _isFront = false);
        _playAudio(_currentWord!.word);
      }
    } else {
      await _flipController.reverse();
      if (mounted) setState(() => _isFront = true);
    }
  }

  Future<void> _playAudio(String text) async {
    if (text.isNotEmpty) {
      await flutterTts.stop();
      await flutterTts.speak(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_currentWord == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text('Xem ngẫu nhiên: ${widget.list.title}'),
          backgroundColor: backgroundColor,
          foregroundColor: textPrimary,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Không có từ nào trong bộ thẻ này.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            _buildNoticeBanner(),
            const SizedBox(height: 24),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SizedBox(
                  height: 400,
                  child: GestureDetector(
                    onTap: _toggleCardFlip,
                    child: AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        final double angle = _flipAnimation.value * 3.14159;
                        final bool isFront = _flipAnimation.value <= 0.5;

                        return Stack(
                          children: [
                            // === MẶT SAU (không bị ngược) ===
                            if (!isFront)
                              ClipRect(
                                child: Transform(
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001)
                                    ..rotateY(angle),
                                  alignment: Alignment.center,
                                  child: Transform(
                                    transform: Matrix4.rotationY(3.14159),
                                    alignment: Alignment.center,
                                    child: _buildBackCard(_currentWord!),
                                  ),
                                ),
                              ),

                            // === MẶT TRƯỚC ===
                            if (isFront)
                              ClipRect(
                                child: Transform(
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001)
                                    ..rotateY(angle),
                                  alignment: Alignment.center,
                                  child: _buildFrontCard(_currentWord!),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    final double progress = _allWords.isEmpty ? 0 : (_currentIndex + 1) / _allWords.length;
    return AppBar(
      title: Text('Xem ngẫu nhiên: ${widget.list.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: backgroundColor,
      foregroundColor: textPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () => Navigator.of(context).pop(),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4.0),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: primaryColor.withOpacity(0.2),
          valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
        ),
      ),
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: const Text(
        'Chế độ xem ngẫu nhiên. Nhấn vào thẻ để lật.',
        style: TextStyle(color: Color(0xFF4E2A1C), fontSize: 13),
      ),
    );
  }

  Widget _buildFrontCard(Word word) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey.shade50,
      child: Container(
        constraints: const BoxConstraints(minHeight: 320),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Nhãn "Xem"
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Xem', style: TextStyle(color: Color(0xFF4A148C), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const Spacer(),

            // Từ + loa
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  word.word,
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: IconButton(
                    onPressed: () => _playAudio(word.word),
                    icon: Icon(Icons.volume_up, color: Colors.blue.shade600, size: 32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Phiên âm
            if (word.transcription?.isNotEmpty == true)
              Text(word.transcription!, style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),

            const Spacer(),

            // Nút lật
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
    );
  }

  Widget _buildBackCard(Word word) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey.shade50,
      child: Container(
        constraints: const BoxConstraints(minHeight: 320),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Định nghĩa:', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              word.define ?? '—',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.3),
            ),
            const SizedBox(height: 24),

            if (word.example?.isNotEmpty == true) ...[
              const Text('Ví dụ:', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  word.example!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.blue.shade800),
                ),
              ),
            ],
            const Spacer(),

            // Nút lật (góc dưới)
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
    );
  }

  Widget _buildControlButtons() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _toggleCardFlip,
              icon: const Icon(Icons.sync_alt_rounded),
              label: const Text('Lật thẻ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _moveToRandomWord,
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Từ khác'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}