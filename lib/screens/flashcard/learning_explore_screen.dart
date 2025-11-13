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

  // COLORS
  static const Color _PRIMARY = Color(0xFF6C5CE7);
  static const Color _ACCENT = Color(0xFF00B894);
  static const Color _EASY_COLOR = Color(0xFF43A047);
  static const Color _MEDIUM_COLOR = Color(0xFFFB8C00);
  static const Color _HARD_COLOR = Color(0xFFE53935);
  static const Color _ERROR_COLOR = Color(0xFFFF7675);
  static const Color _BLUE_700 = Color(0xFF1976D2);
  static const Color _AMBER_50 = Color(0xFFFFF8E1);
  static const Color _AMBER_200 = Color(0xFFFFECB3);
  static const Color _AMBER_700 = Color(0xFFFFA000);

  Color get _primaryOpacity005 => _PRIMARY.withOpacity(0.05);
  Color get _primaryOpacity01 => _PRIMARY.withOpacity(0.1);
  Color get _primaryOpacity02 => _PRIMARY.withOpacity(0.2);
  Color get _accentOpacity015 => _ACCENT.withOpacity(0.15);

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.school_rounded, color: _MEDIUM_COLOR, size: 28),
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
          style: const TextStyle(fontSize: 15, height: 1.5),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: _PRIMARY),
              const SizedBox(height: 16),
              Text(
                'Đang tải bài học...',
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
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
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'Khám phá: ${widget.list.title}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 26),
            onPressed: _handleStopLearning,
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                onPressed: _showSaveFeaturePlaceholder,
                icon: const Icon(Icons.bookmark_add_outlined, color: _PRIMARY),
                tooltip: 'Lưu vào Bộ thẻ của tôi',
              ),
            ),
          ],
        ),
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

  Widget _buildWordCardWithLevels(ExploreWord word) {
    return Column(
      children: [
        _buildWordCard(word, allowFlip: true),
        const SizedBox(height: 24),
        _buildInitialAssessmentControls(),
      ],
    );
  }

  Widget _buildReviewModeContent(ExploreWord word) {
    return Column(
      children: [
        _buildReviewExerciseCard(word),
        const SizedBox(height: 20),
        _buildActiveReviewControls(word),
      ],
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ...options.map((opt) {
          final isCorrect = opt == word.define;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showAnswer ? null : () => _checkAnswerAndAdvance(selectedChoice: opt),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _showAnswer && isCorrect ? _EASY_COLOR : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _showAnswer && isCorrect ? _EASY_COLOR : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 15,
                      color: _showAnswer && isCorrect ? Colors.white : Colors.black87,
                      height: 1.4,
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
        const Text('Điền từ:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _answerController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Nhập từ...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _PRIMARY, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            labelText: _showAnswer ? word.word : null,
            labelStyle: const TextStyle(color: _EASY_COLOR, fontWeight: FontWeight.w600),
          ),
          readOnly: _showAnswer,
        ),
        if (_currentReviewLevel == Difficulty.hard) ...[
          const SizedBox(height: 16),
          const Text('Điền nghĩa:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _meaningController,
            onChanged: (_) => setState(() {}),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Nhập nghĩa...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _PRIMARY, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              labelText: _showAnswer ? word.define : null,
              labelStyle: const TextStyle(color: _EASY_COLOR, fontWeight: FontWeight.w600),
            ),
            readOnly: _showAnswer,
          ),
        ],
      ],
    );
  }

  Widget _buildWordCard(ExploreWord word, {required bool allowFlip}) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 240, maxHeight: 280),
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
              const SizedBox(height: 16),
              Material(
                color: _primaryOpacity005,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: allowFlip ? _toggleCardFlip : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primaryOpacity02, width: 1),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync_alt_rounded, color: _PRIMARY, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Xem nghĩa',
                          style: TextStyle(
                            color: _PRIMARY,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: exerciseColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: exerciseColor.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: exerciseColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_note_rounded, color: exerciseColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: exerciseColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentReviewLevel == Difficulty.easy)
            _buildMultipleChoice(word)
          else
            _buildFillInInputs(word),
        ],
      ),
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
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _PRIMARY),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 400;

                if (isNarrow) {
                  return Column(
                    children: [
                      _buildLevelButton('Dễ', _EASY_COLOR, Icons.sentiment_satisfied_alt, () => _startReviewLevel(Difficulty.easy)),
                      const SizedBox(height: 12),
                      _buildLevelButton('Trung bình', _MEDIUM_COLOR, Icons.sentiment_neutral, () => _startReviewLevel(Difficulty.medium)),
                      const SizedBox(height: 12),
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
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _moveToNextWord,
              icon: const Icon(Icons.skip_next, color: _BLUE_700, size: 22),
              label: const Text('Bỏ qua', style: TextStyle(color: _BLUE_700, fontSize: 15)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(18),
              elevation: 0,
            ),
            child: Icon(icon, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
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
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                    label: const Text('Xem Đáp án', style: TextStyle(fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _PRIMARY,
                      side: BorderSide(color: _showAnswer ? Colors.grey.shade300 : _PRIMARY, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: mainButtonAction,
                    icon: Icon(isContinueButton ? Icons.arrow_forward_rounded : Icons.check_circle_outline_rounded, size: 20),
                    label: Text(mainButtonLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isContinueButton ? _PRIMARY : _ACCENT,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _showAnswer ? null : () {
                    _showCorrectAnswer();
                    _playAudio(word.word);
                    setState(() {});
                  },
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                  label: const Text('Xem Đáp án', style: TextStyle(fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _PRIMARY,
                    side: BorderSide(color: _showAnswer ? Colors.grey.shade300 : _PRIMARY, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: mainButtonAction,
                    icon: Icon(isContinueButton ? Icons.arrow_forward_rounded : Icons.check_circle_outline_rounded, size: 20),
                    label: Text(mainButtonLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isContinueButton ? _PRIMARY : _ACCENT,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
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

  Widget _buildProgressBar() {
    final total = _exploreWords.length;
    final progress = total > 0 ? (_currentIndex + 1) / total : 0.0;

    return Column(
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(_PRIMARY),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Câu ${_currentIndex + 1} / $total",
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _primaryOpacity01,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "${(progress * 100).toInt()}%",
                style: const TextStyle(
                  color: _PRIMARY,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFrontSide(ExploreWord word) {
    return SingleChildScrollView(
      child: Column(
        key: const ValueKey('front'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word.word,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: _PRIMARY,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (word.transcription?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              '/${word.transcription!}/',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: _accentOpacity015,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _playAudio(word.word),
              icon: const Icon(Icons.volume_up_rounded, color: _ACCENT, size: 36),
              iconSize: 56,
              padding: const EdgeInsets.all(18),
              tooltip: 'Phát âm',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackSide(ExploreWord word) {
    return SingleChildScrollView(
      child: Column(
        key: const ValueKey('back'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _BLUE_700,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Định nghĩa',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              word.define,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
          if (word.example?.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _AMBER_50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _AMBER_200, width: 1),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: _AMBER_700),
                      SizedBox(width: 6),
                      Text(
                        'Ví dụ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _AMBER_700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    word.example!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _accentOpacity015,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  size: 72,
                  color: _ACCENT,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Xuất sắc!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bạn đã hoàn thành ${_exploreWords.length} từ trong bộ thẻ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _primaryOpacity01,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '"${widget.list.title}"',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _PRIMARY,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isMarkingAsKnown ? null : _markAllAsKnown,
                  icon: _isMarkingAsKnown
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.check_circle_rounded, size: 22),
                  label: Text(
                    _isMarkingAsKnown ? 'Đang đánh dấu...' : 'Đánh dấu tất cả là Đã nhớ',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _EASY_COLOR,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.explore_rounded, size: 22),
                  label: const Text(
                    'Tiếp tục khám phá',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _PRIMARY,
                    side: const BorderSide(color: _PRIMARY, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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