import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lesson_question.dart';
import '../../models/question_option.dart';
import '../../services/auth_service.dart';
import '../../services/lesson_section_service.dart';
import '../../services/user_attempt_service.dart';

class CourseQuizContent extends StatefulWidget {
  final String lessonId;
  final List<Map<String, dynamic>> questions;
  final UserAttemptService attemptService;
  final LessonSectionService sectionService;
  final double targetScore;
  final int totalQuestions;

  const CourseQuizContent({
    required this.lessonId,
    required this.questions,
    required this.attemptService,
    required this.sectionService,
    required this.targetScore,
    required this.totalQuestions,
    super.key,
  });

  @override
  State<CourseQuizContent> createState() => _CourseQuizContentState();
}

class _CourseQuizContentState extends State<CourseQuizContent> {
  late String? _attemptId;
  late Map<String, String?> _selectedAnswers;
  late Map<String, bool> _submittedQuestions;
  late Map<String, int> _questionStartTime;
  bool _isSubmitting = false;
  bool _attemptInitialized = false;
  bool _isSubmittedAll = false;
  String? _initError;
  late int _correctCount = 0;
  late bool? _attemptIsPassed; // ✅ Thêm state is_passed
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _attemptId = null;
    _selectedAnswers = {};
    _submittedQuestions = {};
    _questionStartTime = {};
    _isSubmittedAll = false;
    _attemptIsPassed = null; // ✅ Initialize is_passed
     _correctCount = 0;

    debugPrint('🎯 Quiz initialized');
    debugPrint('   Target Score: ${widget.targetScore}');
    debugPrint('   Total Questions: ${widget.totalQuestions}');
    debugPrint('   Required Correct: ${_calculateRequiredCorrect()}');

    for (var q in widget.questions) {
      final question = q['question'] as LessonQuestion;
      _selectedAnswers[question.id] = null;
      _submittedQuestions[question.id] = false;
      _questionStartTime[question.id] = DateTime.now().millisecondsSinceEpoch;
    }

    _initializeAttempt();
  }

  Future<void> _initializeAttempt() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final authId = authUser.id;
      final userId = await _authService.getUserIdFromAuthId(authId);
      if (userId == null) throw Exception('User not found');
      debugPrint('📝 Checking for existing attempt for lesson: ${widget.lessonId}');

      // ✅ Step 1: Kiểm tra attempt đã hoàn thành trước
      final completedAttempt =
          await widget.attemptService.getCompletedAttempt(
        lessonId: widget.lessonId,
      );

      if (completedAttempt != null) {
        debugPrint('✅ Found COMPLETED attempt: ${completedAttempt.id}');
        debugPrint('   Score: ${completedAttempt.score}');
        debugPrint('   Passed: ${completedAttempt.isPassed}');

        final savedAnswers = await widget.attemptService.getSavedAnswers(
          completedAttempt.id,
        );

        // ✅ Load số câu đúng từ user_attempt_questions
        final correctCount = await _loadCorrectCount(completedAttempt.id);

        setState(() {
          _attemptId = completedAttempt.id;
          _attemptIsPassed = completedAttempt.isPassed;
          _correctCount = correctCount; // ✅ Load số câu đúng

          for (var entry in savedAnswers.entries) {
            final questionId = entry.key;
            final data = entry.value;
            _selectedAnswers[questionId] =
                data['selected_option_id'] as String?;
            _submittedQuestions[questionId] = true;
          }

          _attemptInitialized = true;
          _initError = null;
          _isSubmittedAll = true;
        });

        debugPrint(
          '✅ Completed attempt restored with ${savedAnswers.length} saved answers, correct: $_correctCount',
        );
        return;
      }

      // ✅ Step 2: Kiểm tra attempt hiện tại (chưa nộp bài)
      final existingAttempt =
          await widget.attemptService.getCurrentAttempt(
        lessonId: widget.lessonId,
      );

      if (existingAttempt != null) {
        debugPrint('✅ Found INCOMPLETE attempt: ${existingAttempt.id}');

        final savedAnswers = await widget.attemptService.getSavedAnswers(
          existingAttempt.id,
        );

        setState(() {
          _attemptId = existingAttempt.id;

          for (var entry in savedAnswers.entries) {
            final questionId = entry.key;
            final data = entry.value;
            _selectedAnswers[questionId] =
                data['selected_option_id'] as String?;
            _submittedQuestions[questionId] = true;
          }

          _attemptInitialized = true;
          _initError = null;
          _isSubmittedAll = false;
        });

        debugPrint(
          '✅ Incomplete attempt restored with ${savedAnswers.length} saved answers',
        );
        return;
      }

      // ✅ Step 3: Không có attempt nào, tạo attempt mới
      debugPrint('📝 No existing attempt, creating new one');

      try {
        await widget.attemptService.updateLessonProgress(
          lessonId: widget.lessonId,
        );
        debugPrint('✅ Progress status updated to in_progress');
      } catch (e) {
        debugPrint('⚠️ Warning updating progress: $e');
      }

      final attempt = await widget.attemptService.createAttempt(
        lessonId: widget.lessonId,
      );

      if (attempt != null) {
        setState(() {
          _attemptId = attempt.id;
          _attemptInitialized = true;
          _initError = null;
          _isSubmittedAll = false;
        });
        debugPrint('✅ New attempt created: ${attempt.id}');
      } else {
        throw Exception('❌ Failed to create attempt - returned null');
      }
    } catch (e) {
      debugPrint('❌ Error initializing attempt: $e');
      setState(() {
        _initError = e.toString();
        _attemptInitialized = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// ✅ Helper: Load số câu đúng từ user_attempt_questions
  Future<int> _loadCorrectCount(String attemptId) async {
    try {
      final responses = await _supabase
          .from('user_attempt_questions')
          .select('is_correct')
          .eq('attempt_id', attemptId);

      final list = responses as List;
      final correctCount = list.where((item) {
        return (item['is_correct'] as bool?) == true;
      }).length;

      debugPrint('📊 Loaded correct count: $correctCount/${list.length}');
      return correctCount;
    } catch (e) {
      debugPrint('⚠️ Error loading correct count: $e');
      return 0;
    }
  }

  Future<void> _submitAnswer({
    required String questionId,
    required String selectedOptionId,
  }) async {
    if (_isSubmitting || !_attemptInitialized || _attemptId == null) return;

    try {
      setState(() => _isSubmitting = true);

      final startTime = _questionStartTime[questionId] ?? 0;
      final timeSpent =
          ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).round();

      final question = widget.questions.firstWhere(
        (q) => (q['question'] as LessonQuestion).id == questionId,
      );
      final options = question['options'] as List<QuestionOption>;
      final selectedOption =
          options.firstWhere((o) => o.id == selectedOptionId);

      final saved = await widget.attemptService.saveQuestionAnswer(
        attemptId: _attemptId!,
        questionId: questionId,
        selectedOptionId: selectedOptionId,
        isCorrect: selectedOption.isCorrect,
        timeSpent: timeSpent,
      );

      if (saved) {
        setState(() {
          _submittedQuestions[questionId] = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã lưu câu trả lời'),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(milliseconds: 800),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error submitting answer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  /// ✅ Tính số câu đúng cần thiết
  int _calculateRequiredCorrect() {
    if (widget.totalQuestions == 0) return 0;

    final required = (widget.totalQuestions * (widget.targetScore / 100)).ceil();

    debugPrint('📊 Required calculation:');
    debugPrint('   Total questions: ${widget.totalQuestions}');
    debugPrint('   Target score: ${widget.targetScore}%');
    debugPrint('   Required correct: $required');

    return required;
  }

  /// ✅ Helper: Lấy màu theo trạng thái
  MaterialColor _getStatusColor() {
    if (!_isSubmittedAll) return Colors.orange; // Chưa nộp
    if (_attemptIsPassed == true) return Colors.green; // Đã pass
    return Colors.red; // Fail
  }

  /// ✅ Helper: Lấy icon theo trạng thái
  IconData _getStatusIcon() {
    if (!_isSubmittedAll) return Icons.timer;
    if (_attemptIsPassed == true) return Icons.check_circle;
    return Icons.cancel;
  }

  /// ✅ Helper: Lấy tiêu đề theo trạng thái
  String _getStatusTitle() {
    if (!_isSubmittedAll) return 'Đang làm bài';
    if (_attemptIsPassed == true) return 'Hoàn thành - PASS ✅';
    return 'Hoàn thành - FAIL ❌';
  }
  
  /// ✅ Helper: Lấy mô tả theo trạng thái
  String _getStatusDescription() {
    if (!_isSubmittedAll) {
      final answered = _submittedQuestions.values.where((v) => v).length;
      return '$answered/${widget.questions.length} câu đã trả lời';
    }
    // ✅ Luôn hiển thị số câu đúng khi đã nộp bài
    if (_attemptIsPassed == true) {
      return '$_correctCount/${widget.questions.length} câu đúng - Đạt yêu cầu ✅';
    }
    final remaining = _calculateRequiredCorrect() - _correctCount;
    return '$_correctCount/${widget.questions.length} câu đúng - Cần $remaining câu nữa ❌';
  }

  Future<void> _submitAllAnswers() async {
    if (_isSubmitting || !_attemptInitialized || _attemptId == null) return;

    try {
      setState(() => _isSubmitting = true);

      final allAnswered = _submittedQuestions.values.every((v) => v);
      if (!allAnswered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng trả lời tất cả các câu hỏi'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final answers =
          await widget.attemptService.getAttemptAnswers(_attemptId!);
      final score = widget.attemptService.calculateScore(answers);

      final isPassed = score >= widget.targetScore;
      final correctCount = answers.where((a) => a.isCorrect ?? false).length; // ✅ Tính số câu đúng

      final finished = await widget.attemptService.finishAttempt(
        attemptId: _attemptId!,
        lessonId: widget.lessonId,
        score: score,
        isPassed: isPassed,
      );

      if (finished && mounted) {
        setState(() {
          _isSubmittedAll = true;
          _attemptIsPassed = isPassed;
          _correctCount = correctCount; // ✅ Lưu số câu đúng
        });
        _showResultDialog(
          score: score,
          isPassed: isPassed,
          correctCount: correctCount,
          totalCount: widget.questions.length,
        );
      }
    } catch (e) {
      debugPrint('❌ Error submitting quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

 Future<void> _resetAllAnswers() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset bài tập?'),
          content: const Text(
            'Bạn có chắc muốn xoá tất cả câu trả lời và làm lại?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Xoá'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _isSubmitting = true);

      if (_attemptId != null) {
        debugPrint('🗑️ Deleting attempt: $_attemptId');
        final deleted = await widget.attemptService.deleteAttempt(_attemptId!);

        if (deleted) {
          debugPrint('✅ Attempt deleted, resetting state...');

          setState(() {
            _attemptId = null;
            _selectedAnswers.clear();
            _submittedQuestions.clear();
            _isSubmittedAll = false;
            _attemptInitialized = false;
            _initError = null;
            _attemptIsPassed = null;
            _correctCount = 0; // ✅ Reset số câu đúng

            for (var q in widget.questions) {
              final question = q['question'] as LessonQuestion;
              _selectedAnswers[question.id] = null;
              _submittedQuestions[question.id] = false;
              _questionStartTime[question.id] =
                  DateTime.now().millisecondsSinceEpoch;
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✅ Đã reset bài tập'),
                backgroundColor: Colors.green.shade700,
                duration: const Duration(milliseconds: 800),
              ),
            );
          }

          await _initializeAttempt();
        } else {
          throw Exception('Failed to delete attempt');
        }
      }
    } catch (e) {
      debugPrint('❌ Error resetting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_attemptInitialized && _initError == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Đang chuẩn bị bài tập...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_initError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              'Lỗi khởi tạo bài tập',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _initError!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _attemptInitialized = false;
                  _initError = null;
                });
                _initializeAttempt();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text(
                'Thử lại',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final requiredCorrect = _calculateRequiredCorrect();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Target score info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yêu cầu đạt:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.targetScore.toStringAsFixed(0)}% ($requiredCorrect/${widget.totalQuestions} câu)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
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
          const SizedBox(height: 12),

          // ✅ Status/Progress info - UPDATED
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor().shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getStatusColor().shade200),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor().shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusTitle(),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor().shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusDescription(),
                        style: TextStyle(
                          fontSize: 11,
                          color: _getStatusColor().shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          ...widget.questions.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final question = data['question'] as LessonQuestion;
            final options = data['options'] as List<QuestionOption>;
            final isSubmitted = _submittedQuestions[question.id] ?? false;
            final selectedAnswer = _selectedAnswers[question.id];

            return _buildQuestionCard(
              index + 1,
              question,
              options,
              isSubmitted,
              selectedAnswer,
            );
          }).toList(),

          const SizedBox(height: 24),

          if (!_isSubmittedAll) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetAllAnswers,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_submittedQuestions.values.every((v) => v) &&
                            !_isSubmitting)
                        ? _submitAllAnswers
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Nộp bài',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _resetAllAnswers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Làm lại từ đầu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showResultDialog({
    required double score,
    required bool isPassed,
    required int correctCount,
    required int totalCount,
  }) {
    final requiredCorrect = _calculateRequiredCorrect();
    final remainingCorrect = requiredCorrect - correctCount;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          isPassed ? '🎉 Chúc mừng!' : '📚 Cần ôn lại',
          style: TextStyle(
            color: isPassed ? Colors.green : Colors.orange,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Điểm số',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${score.toStringAsFixed(1)}/100',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kết quả chi tiết:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Câu đúng:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '$correctCount/$totalCount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Yêu cầu:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '$requiredCorrect/$totalCount (${widget.targetScore.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPassed ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPassed
                      ? Colors.green.shade200
                      : Colors.red.shade200,
                ),
              ),
              child: Text(
                isPassed
                    ? '✅ Bạn đã đạt yêu cầu (${widget.targetScore.toStringAsFixed(0)}%)!'
                    : '❌ Bạn cần $remainingCorrect câu nữa để đạt yêu cầu',
                style: TextStyle(
                  color: isPassed
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    int number,
    LessonQuestion question,
    List<QuestionOption> options,
    bool isSubmitted,
    String? selectedAnswer,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.sectionService.getQuestionIcon(question.questionType),
                  size: 18,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Câu $number: ${question.questionText}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...options.map((option) {
              final isSelected = selectedAnswer == option.id;
              final isCorrect = option.isCorrect;

              Color? backgroundColor;
              Color? borderColor;
              Color? textColor;

              if (isSubmitted && _isSubmittedAll) {
                if (isCorrect) {
                  backgroundColor = Colors.green.shade50;
                  borderColor = Colors.green.shade400;
                  textColor = Colors.green.shade700;
                } else if (isSelected && !isCorrect) {
                  backgroundColor = Colors.red.shade50;
                  borderColor = Colors.red.shade400;
                  textColor = Colors.red.shade700;
                } else {
                  backgroundColor = Colors.grey.shade50;
                  borderColor = Colors.grey.shade300;
                  textColor = Colors.grey.shade600;
                }
              } else if (isSubmitted && !_isSubmittedAll) {
                if (isSelected) {
                  backgroundColor = Colors.blue.shade50;
                  borderColor = Colors.blue.shade400;
                  textColor = Colors.blue.shade700;
                } else {
                  backgroundColor = Colors.grey.shade50;
                  borderColor = Colors.grey.shade300;
                  textColor = Colors.grey.shade700;
                }
              } else {
                if (isSelected) {
                  backgroundColor = Colors.blue.shade50;
                  borderColor = Colors.blue.shade400;
                  textColor = Colors.blue.shade700;
                } else {
                  backgroundColor = Colors.grey.shade50;
                  borderColor = Colors.grey.shade300;
                  textColor = Colors.grey.shade700;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: (_isSubmittedAll || isSubmitted)
                      ? null
                      : () {
                          setState(() {
                            _selectedAnswers[question.id] = option.id;
                          });
                        },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor ?? Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: borderColor ?? Colors.grey.shade400,
                              width: 2,
                            ),
                            color:
                                isSelected ? borderColor : Colors.transparent,
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: borderColor,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option.optionText,
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor,
                              fontWeight: (isSubmitted &&
                                      _isSubmittedAll &&
                                      isCorrect)
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isSubmitted && _isSubmittedAll) ...[
                          const SizedBox(width: 8),
                          if (isCorrect)
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 20,
                            )
                          else if (isSelected && !isCorrect)
                            Icon(
                              Icons.cancel,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            if (!isSubmitted && !_isSubmittedAll) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (selectedAnswer == null || _isSubmitting)
                      ? null
                      : () => _submitAnswer(
                            questionId: question.id,
                            selectedOptionId: selectedAnswer,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Lưu câu trả lời',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ] else if (isSubmitted && _isSubmittedAll) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Đáp án đúng',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      options.firstWhere((o) => o.isCorrect).optionText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (question.explanation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.explanation!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}