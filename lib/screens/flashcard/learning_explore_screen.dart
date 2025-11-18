import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learning_english/models/explore_list.dart';
import 'package:learning_english/models/explore_word.dart';
import 'package:learning_english/services/explore_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

enum Difficulty { none, easy, medium, hard }

class LearningExploreScreen extends StatefulWidget {
  final ExploreList list;
  final String mode;

  const LearningExploreScreen({
    super.key,
    required this.list,
    this.mode = 'learn',
  });

  @override
  State<LearningExploreScreen> createState() => _LearningExploreScreenState();
}

class _LearningExploreScreenState extends State<LearningExploreScreen> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final ExploreService _exploreService = ExploreService();
  final FlutterTts flutterTts = FlutterTts();
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  int _currentIndex = 0;
  List<ExploreWord> _exploreWords = [];
  bool _isLoading = true;
  bool _isFlipped = false;
  bool _isSessionDone = false;
  bool _isMarkingAsKnown = false;

  Difficulty _currentReviewLevel = Difficulty.none;
  bool _showAnswer = false;
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _meaningController = TextEditingController();

  Map<String, String> _userWordStatuses = {};
  String? _currentAuthId;

  // Modern Colors
  static const Color _PRIMARY = Color(0xFF6C5CE7);
  static const Color _ACCENT = Color(0xFF00B894);
  static const Color _BG_COLOR = Color(0xFFF8F9FE);
  static const Color _EASY_COLOR = Color(0xFF43A047);
  static const Color _MEDIUM_COLOR = Color(0xFFFB8C00);
  static const Color _HARD_COLOR = Color(0xFFE53935);
  static const Color _ERROR_COLOR = Color(0xFFFF7675);

  final List<String> _STOP_WORDS_VI = const [
    'là', 'và', 'của', 'cái', 'chiếc', 'này', 'kia', 'ở', 'tại',
    'với', 'cho', 'để', 'mà', 'như', 'bị', 'được', 'thì', 'sẽ', 'tôi', 'bạn', 'hoặc', 'những', 'một'
  ];

  @override
  void initState() {
    super.initState();
    _currentAuthId = _supabaseClient.auth.currentUser?.id;
    _initializeTts();
    _loadWordsForReview();
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

  Future<String?> _getInternalUserId() async {
    if (_currentAuthId == null) return null;

    try {
      final userResponse = await _supabaseClient
          .from('users')
          .select('id')
          .eq('auth_id', _currentAuthId!)
          .maybeSingle();

      return userResponse?['id'] as String?;
    } catch (e) {
      print('Lỗi truy vấn internal user ID: $e');
      return null;
    }
  }

  Map<String, List<ExploreWord>> _separateWordsByStatus(List<ExploreWord> allWords) {
    final Map<String, List<ExploreWord>> separated = {
      'known': [],
      'studied': [],
      'to_review': [],
    };

    for (var word in allWords) {
      final status = _userWordStatuses[word.id] ?? 'to_review';
      if (status == 'known') {
        separated['known']!.add(word);
      } else if (status == 'studied') {
        separated['studied']!.add(word);
      } else {
        separated['to_review']!.add(word);
      }
    }
    return separated;
  }

  void _startSession(List<ExploreWord> wordsToInclude) {
    if (wordsToInclude.isEmpty) {
      _showSnackBar('Không có từ nào để ôn tập trong lựa chọn này.', Colors.orange);
      _handleStopLearning();
      return;
    }

    if (widget.mode == 'random') {
      wordsToInclude.shuffle();
    } else {
      wordsToInclude = wordsToInclude.take(10).toList();
    }

    setState(() {
      _exploreWords = wordsToInclude;
      _currentIndex = 0;
      _isSessionDone = false;
      _isLoading = false;
    });
  }

  void _showLearningOptionDialog(List<ExploreWord> allWords) {
    if (!mounted) return;

    final separated = _separateWordsByStatus(allWords);
    final int knownCount = separated['known']!.length;
    final int notKnownCount = separated['studied']!.length + separated['to_review']!.length;

    if (knownCount == 0 && separated['studied']!.isEmpty) {
      _startSession(allWords);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_MEDIUM_COLOR, _MEDIUM_COLOR.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tiếp tục học tập',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Bộ thẻ có $knownCount từ đã nhớ và $notKnownCount từ cần ôn tập. Bạn muốn ôn tập như thế nào?',
          style: const TextStyle(fontSize: 15, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final wordsToReview = [...separated['studied']!, ...separated['to_review']!];
              _startSession(wordsToReview);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Học tiếp ($notKnownCount từ)', style: const TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startSession(allWords);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _PRIMARY,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ôn lại tất cả', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadWordsForReview() async {
    final listId = widget.list.id;
    if (listId == null) return;

    try {
      final allWords = await _exploreService.getExploreWords(listId);

      if (_currentAuthId != null) {
        final statusList = await _exploreService.getWordStatusesForUser(
          authId: _currentAuthId!,
          exploreListId: listId,
        );

        _userWordStatuses.clear();
        for (var r in statusList) {
          _userWordStatuses[r['explore_word_id'] as String] = r['status'] as String;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (allWords.isEmpty) {
          _showSnackBar('Bộ thẻ này chưa có từ nào để học.', Colors.orange);
          _handleStopLearning();
        } else {
          _showLearningOptionDialog(allWords);
        }
      }
    } catch (e) {
      _showSnackBar('Lỗi tải từ: $e', Colors.red);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markWordStatus(ExploreWord word, String status) async {
    final listId = widget.list.id;
    final wordId = word.id;

    if (wordId == null || _currentAuthId == null || listId == null) {
      _showSnackBar('Bạn cần đăng nhập để lưu tiến độ.', _ERROR_COLOR);
      return;
    }

    final internalUserId = await _getInternalUserId();
    if (internalUserId == null) {
      _showSnackBar('Lỗi: Không tìm thấy hồ sơ người dùng để lưu tiến độ.', _ERROR_COLOR);
      return;
    }

    setState(() {
      _userWordStatuses[wordId] = status;
    });

    try {
      await _supabaseClient
          .from('user_explore_word_status')
          .upsert({
        'user_id': internalUserId,
        'explore_word_id': wordId,
        'explore_list_id': listId,
        'status': status,
        'last_reviewed': DateTime.now().toIso8601String(),
      },
          onConflict: 'user_id, explore_word_id');

      _showSnackBar('Đã đánh dấu "${word.word}" là $status.', _EASY_COLOR);
    } catch (e) {
      _showSnackBar('Lỗi lưu tiến độ: $e', _ERROR_COLOR);
      setState(() {
        _userWordStatuses.remove(word.id);
      });
    }
  }

  Future<void> _markAllAsKnown() async {
    if (_isMarkingAsKnown || _exploreWords.isEmpty) return;

    final listId = widget.list.id;
    final authId = _currentAuthId;

    if (listId == null || authId == null) {
      _showSnackBar('Bạn cần đăng nhập để lưu tiến độ.', _ERROR_COLOR);
      return;
    }

    setState(() => _isMarkingAsKnown = true);

    try {
      final internalUserId = await _getInternalUserId();
      if (internalUserId == null) {
        _showSnackBar('Lỗi: Không tìm thấy hồ sơ người dùng.', _ERROR_COLOR);
        setState(() => _isMarkingAsKnown = false);
        return;
      }

      final List<Map<String, dynamic>> statusUpdates = [];

      for (var word in _exploreWords) {
        if (word.id != null) {
          statusUpdates.add({
            'user_id': internalUserId,
            'explore_word_id': word.id,
            'explore_list_id': listId,
            'status': 'known',
            'last_reviewed': DateTime.now().toIso8601String(),
          });
        }
      }

      if (statusUpdates.isNotEmpty) {
        await _supabaseClient
            .from('user_explore_word_status')
            .upsert(statusUpdates, onConflict: 'user_id, explore_word_id');
      }

      if (mounted) {
        _showSnackBar('Đã đánh dấu ${_exploreWords.length} từ là Đã nhớ!', _EASY_COLOR);
        setState(() => _isMarkingAsKnown = false);
      }

    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi khi đánh dấu tiến độ: $e', _ERROR_COLOR);
        setState(() => _isMarkingAsKnown = false);
      }
    }
  }

  void _moveToNextWord() {
    if (_currentIndex < _exploreWords.length - 1) {
      setState(() {
        _currentIndex++;
        _resetReviewState();
      });
    } else {
      _completeSession();
    }
  }

  void _toggleCardFlip() {
    if (_currentReviewLevel == Difficulty.none) {
      setState(() => _isFlipped = !_isFlipped);
    } else {
      _showSnackBar("Hãy hoàn thành bài tập trước.", _PRIMARY);
    }
  }

  void _playAudio(String word) async {
    if (word.isNotEmpty) await flutterTts.speak(word);
  }

  void _handleStopLearning() {
    flutterTts.stop();
    Navigator.of(context).pop();
  }

  void _completeSession() {
    setState(() => _isSessionDone = true);
  }

  void _resetReviewState() {
    _isFlipped = false;
    _showAnswer = false;
    _currentReviewLevel = Difficulty.none;
    _answerController.clear();
    _meaningController.clear();
  }

  void _startReviewLevel(Difficulty level) {
    setState(() {
      _currentReviewLevel = level;
      _isFlipped = false;
      _showAnswer = false;
      _answerController.clear();
      _meaningController.clear();
    });
    _showSnackBar('Bắt đầu luyện mức độ ${level.name.toUpperCase()}!', _ACCENT);
  }

  void _advanceDifficultyLevel() {
    final word = _exploreWords[_currentIndex];

    setState(() {
      if (_currentReviewLevel == Difficulty.easy) {
        _currentReviewLevel = Difficulty.medium;
        _showSnackBar('Chính xác! Tiếp tục với mức Trung bình.', _MEDIUM_COLOR);
      } else if (_currentReviewLevel == Difficulty.medium) {
        _currentReviewLevel = Difficulty.hard;
        _showSnackBar('Chính xác! Tiếp tục với mức Khó.', _HARD_COLOR);
      } else if (_currentReviewLevel == Difficulty.hard) {
        _markWordStatus(word, 'studied');
        _moveToNextWord();
      } else {
        _moveToNextWord();
      }
      _showAnswer = false;
    });
  }

  void _showCorrectAnswer() {
    if (_showAnswer) return;
    final word = _exploreWords[_currentIndex];
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

  List<String> _tokenizeMeaning(String text) {
    final cleaned = text.toLowerCase().replaceAll(RegExp(r'[,\.;:"()—]'), ' ').trim();
    final List<String> words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final List<String> coreWords = words.where((w) => w.length > 2 && !_STOP_WORDS_VI.contains(w)).toList();
    return coreWords;
  }

  bool _isMeaningPartiallyCorrect(String submittedMeaning, String correctMeaning) {
    if (submittedMeaning.isEmpty) return false;

    final submitted = submittedMeaning.toLowerCase().trim();
    final correct = correctMeaning.toLowerCase().trim();
    final List<String> coreKeywords = _tokenizeMeaning(correctMeaning);
    final int totalCoreKeywords = coreKeywords.length;

    if (totalCoreKeywords <= 3) {
      return submitted.contains(correct) || submitted.length >= (correct.length * 0.9);
    }

    int matches = 0;
    for (var keyword in coreKeywords) {
      if (submitted.contains(keyword)) {
        matches++;
      }
    }

    const double MIN_MATCH_RATIO = 0.75;
    final int requiredMatches = (totalCoreKeywords * MIN_MATCH_RATIO).ceil();

    return matches >= requiredMatches;
  }

  void _checkAnswerAndAdvance({String? selectedChoice}) {
    final word = _exploreWords[_currentIndex];
    bool isCorrect = false;

    if (_currentReviewLevel == Difficulty.easy) {
      isCorrect = (selectedChoice == word.define);
    } else {
      final submittedWord = _answerController.text.trim().toLowerCase();
      final correctWord = word.word.trim().toLowerCase();

      bool isWordCorrect = submittedWord == correctWord;

      bool isMeaningCorrect = true;
      if (_currentReviewLevel == Difficulty.hard) {
        isMeaningCorrect = _isMeaningPartiallyCorrect(_meaningController.text, word.define);
      }

      isCorrect = isWordCorrect && isMeaningCorrect;
    }

    if (isCorrect) {
      _advanceDifficultyLevel();
    } else {
      _showSnackBar('Sai rồi! Thử lại.', _ERROR_COLOR);
      setState(() {
        _showAnswer = false;
        _answerController.clear();
        _meaningController.clear();
      });
    }
  }

  void _showSaveFeaturePlaceholder() {
    _showSnackBar('Vui lòng lưu bộ thẻ về tài khoản của bạn trước khi ôn tập sâu.', _PRIMARY);
  }

  void _showSnackBar(String message, Color color) {
    if (mounted && _scaffoldMessengerKey.currentState != null) {
      _scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 14)),
          backgroundColor: color,
          duration: const Duration(milliseconds: 2000),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _BG_COLOR,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: const AlwaysStoppedAnimation<Color>(_PRIMARY),
              ),
              const SizedBox(height: 24),
              Text(
                'Đang tải bài học...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentWord = _exploreWords.isNotEmpty && _currentIndex < _exploreWords.length
        ? _exploreWords[_currentIndex]
        : null;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: _BG_COLOR,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth > 600 ? 40 : 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProgressBar(),
                    const SizedBox(height: 24),
                    if (!_isSessionDone && currentWord != null) ...[
                      if (_currentReviewLevel != Difficulty.none)
                        _buildReviewModeContent(currentWord)
                      else
                        _buildWordCardWithLevels(currentWord),
                    ] else if (_isSessionDone)
                      _buildCompletionView(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Khám phá: ${widget.list.title}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: false,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.close_rounded, size: 20),
        ),
        onPressed: _handleStopLearning,
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: _showSaveFeaturePlaceholder,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _PRIMARY.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bookmark_add_outlined, color: _PRIMARY, size: 20),
          ),
          tooltip: 'Lưu vào Bộ thẻ của tôi',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildProgressBar() {
    final total = _exploreWords.length;
    final progress = total > 0 ? (_currentIndex + 1) / total : 0.0;

    return Column(
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(_PRIMARY),
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Câu ${_currentIndex + 1} / $total',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_PRIMARY.withOpacity(0.15), _PRIMARY.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _PRIMARY.withOpacity(0.2)),
              ),
              child: Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: _PRIMARY,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWordCardWithLevels(ExploreWord word) {
    return Column(
      children: [
        _buildWordCard(word, allowFlip: true),
        const SizedBox(height: 28),
        _buildInitialAssessmentControls(),
      ],
    );
  }

  Widget _buildReviewModeContent(ExploreWord word) {
    return Column(
      children: [
        _buildReviewExerciseCard(word),
        const SizedBox(height: 24),
        _buildActiveReviewControls(word),
      ],
    );
  }

  Widget _buildWordCard(ExploreWord word, {required bool allowFlip}) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue[50]!.withOpacity(0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _PRIMARY.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 260, maxHeight: 300),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _isFlipped
                        ? _buildBackSide(word)
                        : _buildFrontSide(word),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: allowFlip ? _toggleCardFlip : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_PRIMARY.withOpacity(0.1), _PRIMARY.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _PRIMARY.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync_alt_rounded, color: _PRIMARY, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Xem nghĩa',
                          style: TextStyle(
                            color: _PRIMARY,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrontSide(ExploreWord word) {
    return Column(
      key: const ValueKey('front'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          word.word,
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: _PRIMARY,
            letterSpacing: -1,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        if (word.transcription?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            '/${word.transcription!}/',
            style: TextStyle(
              fontSize: 22,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_ACCENT, _ACCENT.withOpacity(0.7)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _ACCENT.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _playAudio(word.word),
              borderRadius: BorderRadius.circular(100),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Icon(Icons.volume_up_rounded, color: Colors.white, size: 40),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackSide(ExploreWord word) {
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

  Widget _buildReviewExerciseCard(ExploreWord word) {
    final Color exerciseColor = switch (_currentReviewLevel) {
      Difficulty.easy => _EASY_COLOR,
      Difficulty.medium => _MEDIUM_COLOR,
      Difficulty.hard => _HARD_COLOR,
      Difficulty.none => _PRIMARY,
    };

    final String label = switch (_currentReviewLevel) {
      Difficulty.easy => 'Định nghĩa nào đúng với từ:',
      Difficulty.medium => 'Điền từ còn thiếu:',
      Difficulty.hard => 'Điền cả từ và nghĩa:',
      Difficulty.none => 'Bài tập:',
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [exerciseColor.withOpacity(0.08), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: exerciseColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: exerciseColor.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [exerciseColor, exerciseColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: exerciseColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: exerciseColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_currentReviewLevel == Difficulty.easy)
            _buildMultipleChoice(word)
          else
            _buildFillInInputs(word),
        ],
      ),
    );
  }

  Widget _buildMultipleChoice(ExploreWord word) {
    List<String> options = [word.define];

    final others = _exploreWords.where((w) => w.word != word.word).toList()..shuffle();
    options.addAll(others.take(3).map((w) => w.define).where((d) => d.isNotEmpty));
    options.shuffle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Chọn định nghĩa đúng cho "${word.word}":',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        ...options.map((opt) {
          final isCorrect = opt == word.define;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showAnswer ? null : () => _checkAnswerAndAdvance(selectedChoice: opt),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _showAnswer && isCorrect
                        ? LinearGradient(colors: [_EASY_COLOR, _EASY_COLOR.withOpacity(0.8)])
                        : LinearGradient(colors: [Colors.white, Colors.grey[50]!]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _showAnswer && isCorrect ? _EASY_COLOR : Colors.grey.shade300,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _showAnswer && isCorrect
                            ? _EASY_COLOR.withOpacity(0.3)
                            : Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _showAnswer && isCorrect ? Colors.white : Colors.black87,
                      height: 1.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFillInInputs(ExploreWord word) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Điền từ:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _answerController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Nhập từ...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _PRIMARY, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            labelText: _showAnswer ? word.word : null,
            labelStyle: const TextStyle(
              color: _EASY_COLOR,
              fontWeight: FontWeight.bold,
            ),
          ),
          readOnly: _showAnswer,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        if (_currentReviewLevel == Difficulty.hard) ...[
          const SizedBox(height: 18),
          const Text(
            'Điền nghĩa:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _meaningController,
            onChanged: (_) => setState(() {}),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Nhập nghĩa...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _PRIMARY, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              labelText: _showAnswer ? word.define : null,
              labelStyle: const TextStyle(
                color: _EASY_COLOR,
                fontWeight: FontWeight.bold,
              ),
            ),
            readOnly: _showAnswer,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildInitialAssessmentControls() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            const Text(
              'Bạn nhớ từ này ở mức độ nào?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _PRIMARY,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 400;

                if (isNarrow) {
                  return Column(
                    children: [
                      _buildLevelButton('Dễ', _EASY_COLOR, Icons.sentiment_satisfied_alt, () => _startReviewLevel(Difficulty.easy)),
                      const SizedBox(height: 16),
                      _buildLevelButton('Trung bình', _MEDIUM_COLOR, Icons.sentiment_neutral, () => _startReviewLevel(Difficulty.medium)),
                      const SizedBox(height: 16),
                      _buildLevelButton('Khó', _HARD_COLOR, Icons.sentiment_dissatisfied, () => _startReviewLevel(Difficulty.hard)),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLevelButton('Dễ', _EASY_COLOR, Icons.sentiment_satisfied_alt, () => _startReviewLevel(Difficulty.easy)),
                    _buildLevelButton('Trung bình', _MEDIUM_COLOR, Icons.sentiment_neutral, () => _startReviewLevel(Difficulty.medium)),
                    _buildLevelButton('Khó', _HARD_COLOR, Icons.sentiment_dissatisfied, () => _startReviewLevel(Difficulty.hard)),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            TextButton.icon(
              onPressed: _moveToNextWord,
              icon: Icon(Icons.skip_next_rounded, color: Colors.blue[700], size: 24),
              label: Text(
                'Bỏ qua',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(100),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Icon(icon, size: 36, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActiveReviewControls(ExploreWord word) {
    final bool hasInput = (_currentReviewLevel == Difficulty.medium || _currentReviewLevel == Difficulty.hard) &&
        _answerController.text.trim().isNotEmpty &&
        (_currentReviewLevel != Difficulty.hard || _meaningController.text.trim().isNotEmpty);

    final bool isContinueButton = _showAnswer;

    VoidCallback? mainButtonAction;
    String mainButtonLabel;

    if (isContinueButton) {
      mainButtonAction = _advanceDifficultyLevel;
      mainButtonLabel = 'Tiếp tục';
    } else if (_currentReviewLevel == Difficulty.easy) {
      mainButtonAction = () => _showSnackBar('Vui lòng chọn đáp án trong danh sách.', _PRIMARY);
      mainButtonLabel = 'Kiểm tra';
    } else if (hasInput) {
      mainButtonAction = _checkAnswerAndAdvance;
      mainButtonLabel = 'Kiểm tra';
    } else {
      mainButtonAction = () => _showSnackBar('Vui lòng điền đủ thông tin.', _ERROR_COLOR);
      mainButtonLabel = 'Kiểm tra';
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 400;

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showAnswer ? null : () {
                      _showCorrectAnswer();
                      _playAudio(word.word);
                      setState(() {});
                    },
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
                    label: const Text('Xem Đáp án', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _PRIMARY,
                      side: BorderSide(color: _showAnswer ? Colors.grey.shade300 : _PRIMARY, width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isContinueButton
                            ? [_PRIMARY, _PRIMARY.withOpacity(0.8)]
                            : [_ACCENT, _ACCENT.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (isContinueButton ? _PRIMARY : _ACCENT).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: mainButtonAction,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isContinueButton ? Icons.arrow_forward_rounded : Icons.check_circle_outline_rounded,
                                size: 22,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                mainButtonLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAnswer ? null : () {
                      _showCorrectAnswer();
                      _playAudio(word.word);
                      setState(() {});
                    },
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
                    label: const Text('Xem Đáp án', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _PRIMARY,
                      side: BorderSide(color: _showAnswer ? Colors.grey.shade300 : _PRIMARY, width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isContinueButton
                            ? [_PRIMARY, _PRIMARY.withOpacity(0.8)]
                            : [_ACCENT, _ACCENT.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (isContinueButton ? _PRIMARY : _ACCENT).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: mainButtonAction,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isContinueButton ? Icons.arrow_forward_rounded : Icons.check_circle_outline_rounded,
                                size: 22,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                mainButtonLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.green[50]!.withOpacity(0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _ACCENT.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_ACCENT, _ACCENT.withOpacity(0.7)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _ACCENT.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  size: 72,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Xuất sắc!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Bạn đã hoàn thành ${_exploreWords.length} từ trong bộ thẻ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.6,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_PRIMARY.withOpacity(0.15), _PRIMARY.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _PRIMARY.withOpacity(0.2)),
                ),
                child: Text(
                  '"${widget.list.title}"',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _PRIMARY,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_EASY_COLOR, _EASY_COLOR.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _EASY_COLOR.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isMarkingAsKnown ? null : _markAllAsKnown,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isMarkingAsKnown)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Icon(Icons.check_circle_rounded, size: 24, color: Colors.white),
                            const SizedBox(width: 12),
                            Text(
                              _isMarkingAsKnown ? 'Đang đánh dấu...' : 'Đánh dấu tất cả là Đã nhớ',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.explore_rounded, size: 24),
                  label: const Text(
                    'Tiếp tục khám phá',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _PRIMARY,
                    side: const BorderSide(color: _PRIMARY, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}