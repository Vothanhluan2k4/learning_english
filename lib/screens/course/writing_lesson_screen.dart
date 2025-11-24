import 'package:flutter/material.dart';
import 'package:learning_english/services/auth_service.dart';
import 'package:learning_english/widgets/courses/writing_editor_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/writing_question.dart';
import '../../services/writing_lesson_service.dart';
import '../../services/lesson_section_service.dart';
import '../../services/user_attempt_service.dart'; 
import 'dart:convert';

class WritingLessonScreen extends StatefulWidget {
  final String lessonId;

  const WritingLessonScreen({
    super.key,
    required this.lessonId,
  });

  @override
  State<WritingLessonScreen> createState() => _WritingLessonScreenState();
}

class _WritingLessonScreenState extends State<WritingLessonScreen> {
  final _writingService = WritingLessonService();
  final _sectionService = LessonSectionService();
  final _attemptService = UserAttemptService(); 
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  bool _isLoading = true;
  List<WritingQuestion> _questions = [];
  Map<String, String> _userAnswers = {};
  Map<String, Map<String, dynamic>> _previousResults = {};
  String? _attemptId;
  String? _userId; // ✅ Store userId
  int _currentIndex = 0;
  String _selectedProvider = 'groq';
  bool _isReview = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      debugPrint('📖 Fetching sections for lesson: ${widget.lessonId}');

      final sections = await _sectionService.fetchSectionsByLesson(widget.lessonId);
      debugPrint('✅ Loaded ${sections.length} sections');

      List<WritingQuestion> allQuestions = [];
      for (final section in sections) {
        if (section.sectionType == 'writing' || section.sectionType == 'quiz') {
          final questions = await _writingService.fetchWritingQuestions(section.id);
          debugPrint('✅ Loaded ${questions.length} questions from section ${section.id}');
          allQuestions.addAll(questions);
        }
      }

      if (allQuestions.isEmpty) {
        throw Exception('Không tìm thấy câu hỏi writing nào');
      }

      final authId = _supabase.auth.currentUser?.id;
      if (authId == null) {
        throw Exception('Vui lòng đăng nhập để tiếp tục');
      }

      final userId = await _authService.getUserIdFromAuthId(authId);
      if (userId == null) {
        throw Exception('Không tìm thấy thông tin người dùng');
      }

      _userId = userId;
      debugPrint('✅ User ID: $userId');

      final existingAttempts = await _supabase
          .from('user_lesson_attempts')
          .select('id, attempt_number, finished_at, score')
          .eq('user_id', userId)
          .eq('lesson_id', widget.lessonId)
          .order('attempt_number', ascending: false);

      String? attemptId;

      if (existingAttempts.isNotEmpty) {
        final lastAttempt = existingAttempts.first;
        final finishedAt = lastAttempt['finished_at'];
        
        if (finishedAt != null) {
          final score = lastAttempt['score'];
          final scoreValue = score is int ? score.toDouble() : score as double;
          final shouldReview = await _showRetryDialog(scoreValue);
          
          if (shouldReview == true) {
            attemptId = lastAttempt['id'];
            _isReview = true;
            debugPrint('📖 Reviewing attempt: $attemptId');
            await _loadPreviousAnswers(attemptId as String, allQuestions);
          } else if (shouldReview == false) {
            attemptId = await _createNewAttempt(userId, existingAttempts.length + 1);
            _isReview = false;
          } else {
            if (mounted) Navigator.pop(context);
            return;
          }
        } else {
          attemptId = lastAttempt['id'];
          debugPrint('📝 Continuing unfinished attempt: $attemptId');
          await _loadPreviousAnswers(attemptId as String, allQuestions);
          
          // ✅ REMOVED: await _updateProgress('in_progress');
          // Progress will be updated when finishing attempt
        }
      } else {
        attemptId = await _createNewAttempt(userId, 1);
        
        // ✅ REMOVED: await _updateProgress('in_progress');
        // Progress will be updated when finishing attempt
      }

      setState(() {
        _questions = allQuestions;
        _attemptId = attemptId;
        _isLoading = false;
      });

      debugPrint('✅ Data loaded successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading data: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() => _isLoading = false);
      
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

  Future<String> _createNewAttempt(String userId, int attemptNumber) async {
    debugPrint('📝 Creating new attempt #$attemptNumber');
    
    final attempt = await _supabase
        .from('user_lesson_attempts')
        .insert({
          'user_id': userId,
          'lesson_id': widget.lessonId,
          'attempt_number': attemptNumber,
          'started_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    final attemptId = attempt['id'] as String;
    debugPrint('✅ Attempt created: $attemptId');
    return attemptId;
  }

  Future<void> _loadPreviousAnswers(String attemptId, List<WritingQuestion> questions) async {
    try {
      debugPrint('📖 Loading previous answers for attempt: $attemptId');
      
      final previousAnswers = await _supabase
          .from('user_attempt_questions')
          .select('question_id, user_answer, ai_score, ai_feedback, ai_graded_at')
          .eq('attempt_id', attemptId);

      for (final answer in previousAnswers) {
        final questionId = answer['question_id'] as String;
        final userAnswer = answer['user_answer'] as String?;
        
        if (userAnswer != null) {
          _userAnswers[questionId] = userAnswer;
        }

        if (answer['ai_score'] != null) {
          final score = answer['ai_score'];
          final scoreValue = score is int ? score.toDouble() : score as double;
          
          _previousResults[questionId] = {
            'ai_score': scoreValue,
            'ai_feedback': answer['ai_feedback'],
            'ai_graded_at': answer['ai_graded_at'],
          };
        }
      }

      debugPrint('✅ Loaded ${_userAnswers.length} previous answers');
    } catch (e) {
      debugPrint('❌ Error loading previous answers: $e');
    }
  }

  Future<bool?> _showRetryDialog(double previousScore) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Bài học đã hoàn thành'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              'Điểm số lần trước: ${previousScore.toStringAsFixed(1)}/100',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Bạn muốn:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Quay lại'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xem lại kết quả'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Làm lại'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAnswer(String text) async {
    if (_attemptId == null || _isReview) return;

    final question = _questions[_currentIndex];
    setState(() => _userAnswers[question.id] = text);

    try {
      await _writingService.saveWritingAnswer(
        attemptId: _attemptId!,
        questionId: question.id,
        userAnswer: text,
      );
      debugPrint('✅ Saved answer for question: ${question.id}');
      
      // ✅ REMOVED: await _updateProgress('in_progress');
      // No need to update progress on every save
      // Progress will be updated when finishing attempt
    } catch (e) {
      debugPrint('❌ Error saving answer: $e');
    }
  }

  Future<void> _navigateToQuestion(int index) async {
    if (index < 0 || index >= _questions.length) return;
    
    if (!_isReview && _attemptId != null) {
      final currentQuestion = _questions[_currentIndex];
      final currentAnswer = _userAnswers[currentQuestion.id];
      
      if (currentAnswer != null && currentAnswer.isNotEmpty) {
        debugPrint('💾 Auto-saving answer before navigation...');
        await _saveAnswer(currentAnswer);
      }
    }
    
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _nextQuestion() async {
    if (_currentIndex < _questions.length - 1) {
      await _navigateToQuestion(_currentIndex + 1);
    }
  }

  Future<void> _previousQuestion() async {
    if (_currentIndex > 0) {
      await _navigateToQuestion(_currentIndex - 1);
    }
  }

  Future<void> _submitForGrading() async {
    if (_isReview) {
      final question = _questions[_currentIndex];
      final previousResult = _previousResults[question.id];
      
      if (previousResult != null) {
        _showPreviousResults(previousResult);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa có kết quả chấm điểm cho câu này'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final question = _questions[_currentIndex];
    final userAnswer = _userAnswers[question.id] ?? '';

    if (userAnswer.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập câu trả lời trước khi nộp bài'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang chấm bài...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      debugPrint('🤖 Submitting for AI grading with provider: $_selectedProvider');

      final result = await _writingService.submitForAIGrading(
        questionText: question.questionText,
        userAnswer: userAnswer,
        minWords: question.minWords,
        maxWords: question.maxWords,
        guideline: question.guideline,
        provider: _selectedProvider,
      );

      debugPrint('✅ Grading result received: ${result['total_score']}');

      if (_attemptId != null) {
        await _writingService.saveAIGradingResults(
          attemptId: _attemptId!,
          questionId: question.id,
          gradingResult: result,
        );
        
        final totalScore = result['total_score'];
        _previousResults[question.id] = {
          'ai_score': totalScore is int ? totalScore.toDouble() : totalScore,
          'ai_feedback': result['detailed_feedback'],
        };
      }

      if (mounted) Navigator.pop(context);
      _showGradingResults(result);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add this method to display formatted grading results
  Widget _buildGradingDetail(String label, dynamic value, {bool isScore = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: isScore
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      value.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  )
                : Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<dynamic>? items, {Color? color}) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color ?? Colors.grey.shade600,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  void _showPreviousResults(Map<String, dynamic> result) {
    // Parse feedback if it's stored as JSON string
    Map<String, dynamic> feedback;
    if (result['ai_feedback'] is String) {
      try {
        feedback = jsonDecode(result['ai_feedback']);
      } catch (e) {
        feedback = {'detailed_feedback': result['ai_feedback']};
      }
    } else {
      feedback = result;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.history, color: Colors.blue, size: 32),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Kết quả đã chấm',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Score Circle
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade700],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade200,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(feedback['total_score'] ?? result['ai_score'])?.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              '/100',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Score Breakdown
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi tiết điểm:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (feedback['grammar_score'] != null)
                          _buildGradingDetail('Ngữ pháp', '${feedback['grammar_score']}/100', isScore: true),
                        if (feedback['content_score'] != null)
                          _buildGradingDetail('Nội dung', '${feedback['content_score']}/100', isScore: true),
                        if (feedback['organization_score'] != null)
                          _buildGradingDetail('Cấu trúc', '${feedback['organization_score']}/100', isScore: true),
                        if (feedback['task_score'] != null)
                          _buildGradingDetail('Hoàn thành', '${feedback['task_score']}/100', isScore: true),
                        if (feedback['word_count'] != null)
                          _buildGradingDetail('Số từ', '${feedback['word_count']} từ'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Strengths
                  if (feedback['strengths'] != null && (feedback['strengths'] as List).isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: _buildListSection(
                        '✅ Điểm mạnh:',
                        feedback['strengths'],
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Weaknesses
                  if (feedback['weaknesses'] != null && (feedback['weaknesses'] as List).isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: _buildListSection(
                        '⚠️ Cần cải thiện:',
                        feedback['weaknesses'],
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Suggestions
                  if (feedback['suggestions'] != null && (feedback['suggestions'] as List).isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: _buildListSection(
                        '💡 Gợi ý:',
                        feedback['suggestions'],
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Detailed Feedback
                  if (feedback['detailed_feedback'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.feedback, color: Colors.amber.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Nhận xét tổng quan:',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            feedback['detailed_feedback'],
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Close Button
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Đóng', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showGradingResults(Map<String, dynamic> result) {
    final isLastQuestion = _currentIndex == _questions.length - 1;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isLastQuestion ? 'Kết quả câu cuối' : 'Kết quả chấm bài',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Score Circle
                  Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade700],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade200,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${result['total_score']}/100',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Score Breakdown
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi tiết điểm:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (result['grammar_score'] != null)
                          _buildGradingDetail('Ngữ pháp', '${result['grammar_score']}/100', isScore: true),
                        if (result['content_score'] != null)
                          _buildGradingDetail('Nội dung', '${result['content_score']}/100', isScore: true),
                        if (result['organization_score'] != null)
                          _buildGradingDetail('Cấu trúc', '${result['organization_score']}/100', isScore: true),
                        if (result['task_score'] != null)
                          _buildGradingDetail('Hoàn thành', '${result['task_score']}/100', isScore: true),
                        if (result['word_count'] != null)
                          _buildGradingDetail('Số từ', '${result['word_count']} từ'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Strengths
                  if (result['strengths'] != null && (result['strengths'] as List).isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: _buildListSection(
                        '✅ Điểm mạnh:',
                        result['strengths'],
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Weaknesses
                  if (result['weaknesses'] != null && (result['weaknesses'] as List).isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: _buildListSection(
                        '⚠️ Cần cải thiện:',
                        result['weaknesses'],
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Suggestions
                  if (result['suggestions'] != null && (result['suggestions'] as List).isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: _buildListSection(
                        '💡 Gợi ý:',
                        result['suggestions'],
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Detailed Feedback
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.feedback, color: Colors.amber.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Nhận xét tổng quan:',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          result['detailed_feedback'] ?? 'Không có nhận xét',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Đóng', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      if (!isLastQuestion) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _nextQuestion();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Tiếp tục', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Remove old _updateProgress method
  // Delete this entire method as we're using UserAttemptService now

  Future<void> _finishAttempt() async {
    if (_attemptId == null || _isReview || _userId == null) return;

    try {
      double totalScore = 0;
      int gradedCount = 0;
      
      for (final result in _previousResults.values) {
        if (result['ai_score'] != null) {
          final score = result['ai_score'];
          final scoreValue = score is int ? score.toDouble() : score as double;
          
          totalScore += scoreValue;
          gradedCount++;
        }
      }
      
      final avgScore = gradedCount > 0 ? totalScore / gradedCount : 0.0;
      final isPassed = avgScore >= 60;

      debugPrint('📊 Finishing attempt: $gradedCount graded questions, avg score: $avgScore');

      // ✅ 1. Update attempt and progress
      await _attemptService.finishAttempt(
        attemptId: _attemptId!,
        lessonId: widget.lessonId,
        score: avgScore,
        isPassed: isPassed,
      );

      debugPrint('✅ Attempt finished with score: $avgScore, isPassed: $isPassed');

      // ✅ 2. FORCE unlock next lesson if passed (since trigger might not fire)
      if (isPassed) {
        try {
          debugPrint('🔓 Calling unlock_next_lesson RPC...');
          await _supabase.rpc('unlock_next_lesson', params: {
            'p_user_id': _userId,
            'p_current_lesson_id': widget.lessonId,
          });
          debugPrint('✅ unlock_next_lesson RPC completed');
        } catch (e) {
          debugPrint('⚠️ unlock_next_lesson error (might be already unlocked): $e');
          // Don't fail - lesson might already be unlocked
        }
      }
      
      // ✅ 3. Show completion dialog
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isPassed ? Icons.emoji_events : Icons.refresh,
                  color: isPassed ? Colors.amber : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Text('Hoàn thành bài học'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isPassed
                          ? [Colors.green.shade400, Colors.green.shade700]
                          : [Colors.orange.shade400, Colors.orange.shade700],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${avgScore.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isPassed ? '🎉 Xuất sắc!' : '💪 Cố gắng lên!',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  isPassed
                      ? 'Bạn đã hoàn thành bài học với điểm số tốt!'
                      : 'Bạn có thể làm lại để cải thiện điểm số.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildStatRow('Số câu đã chấm', '$gradedCount/${_questions.length}'),
                      const Divider(height: 16),
                      _buildStatRow('Điểm trung bình', '${avgScore.toStringAsFixed(1)}/100'),
                      const Divider(height: 16),
                      _buildStatRow(
                        'Kết quả',
                        isPassed ? 'Đạt ✅' : 'Chưa đạt ⚠️',
                        valueColor: isPassed ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (!isPassed) ...[
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Back to lesson list
                  },
                  child: const Text('Về trang chủ'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog
                    setState(() {
                      _isLoading = true;
                      _currentIndex = 0;
                      _userAnswers.clear();
                      _previousResults.clear();
                    });
                    await _loadData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Back to lesson list
                  },
                  child: const Text('Đóng'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Back to lesson list - next lesson should be unlocked
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Bài tiếp theo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error finishing attempt: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi hoàn thành bài học: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ✅ Helper widget for stats row
  Widget _buildStatRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Writing Lesson')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Writing Lesson')),
        body: const Center(child: Text('Không có câu hỏi nào')),
      );
    }

    final question = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isReview ? 'Xem lại kết quả' : 'Writing Lesson'),
        backgroundColor: _isReview ? Colors.orange : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (!_isReview) ...[
            DropdownButton<String>(
              value: _selectedProvider,
              dropdownColor: Colors.blue.shade700,
              style: const TextStyle(color: Colors.white),
              underline: Container(),
              items: const [
                DropdownMenuItem(value: 'groq', child: Text('Groq')),
                DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedProvider = value);
                }
              },
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Câu ${_currentIndex + 1}/${_questions.length}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isReview) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Xem lại',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                Row(
                  children: [
                    IconButton(
                      onPressed: _currentIndex > 0 ? _previousQuestion : null,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Câu trước',
                    ),
                    IconButton(
                      onPressed: _currentIndex < _questions.length - 1 ? _nextQuestion : null,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Câu sau',
                    ),
                    PopupMenuButton<int>(
                      icon: const Icon(Icons.list),
                      tooltip: 'Chọn câu',
                      onSelected: _navigateToQuestion,
                      itemBuilder: (context) => List.generate(
                        _questions.length,
                        (index) => PopupMenuItem<int>(
                          value: index,
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _currentIndex == index
                                      ? Colors.blue
                                      : _userAnswers.containsKey(_questions[index].id)
                                          ? Colors.green.shade100
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _currentIndex == index ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _questions[index].questionText.length > 40
                                      ? '${_questions[index].questionText.substring(0, 40)}...'
                                      : _questions[index].questionText,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              if (_previousResults.containsKey(_questions[index].id))
                                const Icon(Icons.check_circle, color: Colors.green, size: 20)
                              else if (_userAnswers.containsKey(_questions[index].id))
                                const Icon(Icons.edit, color: Colors.orange, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      question.questionText,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),

                  WritingEditorWidget(
                    key: ValueKey(_currentIndex),
                    initialText: _userAnswers[question.id],
                    minWords: question.minWords,
                    maxWords: question.maxWords,
                    guideline: question.guideline,
                    onTextChanged: _saveAnswer,
                    onSubmit: _submitForGrading,
                    readOnly: _isReview,
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                if (_currentIndex > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _previousQuestion,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Câu trước'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (_currentIndex < _questions.length - 1)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nextQuestion,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Câu sau'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _finishAttempt,
                      icon: const Icon(Icons.check),
                      label: const Text('Hoàn thành'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}