import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/ai/ai_practice_service.dart';
import 'ai_practice_result_screen.dart';

class AiPracticeQuizScreen extends StatefulWidget {
  final String sessionId;
  final List<Map<String, dynamic>> questions;
  final String topic;

  const AiPracticeQuizScreen({
    super.key,
    required this.sessionId,
    required this.questions,
    required this.topic,
  });

  @override
  State<AiPracticeQuizScreen> createState() => _AiPracticeQuizScreenState();
}

class _AiPracticeQuizScreenState extends State<AiPracticeQuizScreen> {
  final _practiceService = AiPracticeService();
  
  int _currentQuestionIndex = 0;
  Map<int, String> _userAnswers = {}; // 🔥 FIX: order_index -> selected_answer
  bool _isSubmitting = false;

  // Timer
  late Timer _timer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _validateQuestions();
    _startTimer();
  }

  void _validateQuestions() {
    print('📋 Validating ${widget.questions.length} questions...');
    
    for (var i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      
      // Ensure order_index exists
      if (q['order_index'] == null) {
        q['order_index'] = i;
      }
      
      print('✅ Q${i + 1}: id=${q['id']}, order=${q['order_index']}');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> get _currentQuestion => widget.questions[_currentQuestionIndex];

  int get _currentOrderIndex => _currentQuestion['order_index'] ?? _currentQuestionIndex;

  bool get _hasAnswered => _userAnswers.containsKey(_currentOrderIndex);

  bool get _isLastQuestion => _currentQuestionIndex == widget.questions.length - 1;

  void _selectAnswer(String answer) {
    setState(() {
      _userAnswers[_currentOrderIndex] = answer;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
  }

  Future<void> _submitQuiz() async {
    // Check if all questions answered
    final unanswered = widget.questions
        .where((q) {
          final orderIndex = q['order_index'] ?? widget.questions.indexOf(q);
          return !_userAnswers.containsKey(orderIndex);
        })
        .length;

    if (unanswered > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Chưa hoàn thành'),
          content: Text(
            'Bạn còn $unanswered câu chưa trả lời.\nBạn có muốn nộp bài không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Tiếp tục làm'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Color(0xFFEF5350)),
              child: Text('Nộp bài'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 🔥 FIX: Convert to format với question_id
      final answers = _userAnswers.entries.map((entry) {
        final orderIndex = entry.key;
        final question = widget.questions[orderIndex];
        
        return {
          'question_id': question['id'] ?? 'q${orderIndex + 1}',
          'order_index': orderIndex,
          'selected_answer': entry.value,
        };
      }).toList();

      print('📤 Submitting answers: $answers');

      final result = await _practiceService.submitAnswers(
        sessionId: widget.sessionId,
        userAnswers: answers,
      );

      _timer.cancel();

      if (mounted) {
        // 🔥 Convert _userAnswers back to Map<String, String> for result screen
        final userAnswersForResult = <String, String>{};
        for (var entry in _userAnswers.entries) {
          final question = widget.questions[entry.key];
          final questionId = question['id'] ?? 'q${entry.key + 1}';
          userAnswersForResult[questionId] = entry.value;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AiPracticeResultScreen(
              sessionId: widget.sessionId,
              topic: widget.topic,
              score: result['score'],
              correctCount: result['correct_count'],
              totalQuestions: result['total_questions'],
              timeSpent: _secondsElapsed,
              questions: widget.questions,
              userAnswers: userAnswersForResult,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: $e'),
            backgroundColor: Color(0xFFEF5350),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Thoát bài tập?'),
            content: Text('Tiến trình sẽ bị mất. Bạn có chắc muốn thoát?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Ở lại'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('Thoát'),
              ),
            ],
          ),
        );

        return confirmed ?? false;
      },
      child: Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 2,
          title: Text(
            widget.topic,
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            // TIMER
            Container(
              margin: EdgeInsets.only(right: 16),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Color(0xFF2196F3)),
                  SizedBox(width: 6),
                  Text(
                    _formatTime(_secondsElapsed),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // PROGRESS BAR
            _buildProgressBar(),

            // QUESTION CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuestionCard(),
                    SizedBox(height: 20),
                    _buildOptionsGrid(),
                  ],
                ),
              ),
            ),

            // NAVIGATION BUTTONS
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentQuestionIndex + 1) / widget.questions.length;
    
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Câu ${_currentQuestionIndex + 1}/${widget.questions.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF424242),
                ),
              ),
              Text(
                '${_userAnswers.length}/${widget.questions.length} đã trả lời',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF757575),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2196F3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q${_currentQuestionIndex + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Spacer(),
              if (_hasAnswered)
                Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
            ],
          ),
          SizedBox(height: 16),
          Text(
            _currentQuestion['question'],
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid() {
    final options = List<String>.from(_currentQuestion['options']);
    final selectedAnswer = _userAnswers[_currentOrderIndex];

    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = selectedAnswer == option;
        final label = String.fromCharCode(65 + index); // A, B, C, D

        return GestureDetector(
          onTap: () => _selectAnswer(option),
          child: Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Color(0xFF2196F3) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Color(0xFF2196F3) : Color(0xFFE0E0E0),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Color(0xFF2196F3).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Color(0xFFF5F5F5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Color(0xFF2196F3) : Color(0xFFBDBDBD),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Color(0xFF2196F3) : Color(0xFF757575),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 15,
                      color: isSelected ? Colors.white : Color(0xFF1A1A1A),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // PREVIOUS BUTTON
          if (_currentQuestionIndex > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousQuestion,
                icon: Icon(Icons.arrow_back, size: 18),
                label: Text('Trước'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF757575),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          if (_currentQuestionIndex > 0) SizedBox(width: 12),

          // NEXT/SUBMIT BUTTON
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : (_isLastQuestion ? _submitQuiz : _nextQuestion),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLastQuestion
                    ? Color(0xFF4CAF50)
                    : Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLastQuestion ? 'Nộp bài' : 'Tiếp theo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          _isLastQuestion
                              ? Icons.check_circle
                              : Icons.arrow_forward,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}