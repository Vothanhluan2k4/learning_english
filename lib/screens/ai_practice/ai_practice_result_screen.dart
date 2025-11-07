import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class AiPracticeResultScreen extends StatefulWidget {
  final String sessionId;
  final String topic;
  final double score;
  final int correctCount;
  final int totalQuestions;
  final int timeSpent;
  final List<Map<String, dynamic>> questions;
  final Map<String, String> userAnswers;

  const AiPracticeResultScreen({
    super.key,
    required this.sessionId,
    required this.topic,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
    required this.timeSpent,
    required this.questions,
    required this.userAnswers,
  });

  @override
  State<AiPracticeResultScreen> createState() => _AiPracticeResultScreenState();
}

class _AiPracticeResultScreenState extends State<AiPracticeResultScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scoreAnimation;

  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    
    _confettiController = ConfettiController(duration: Duration(seconds: 3));
    
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    _scoreAnimation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // Show confetti if passed (score >= 50%)
    if (widget.score >= 50) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) _confettiController.play();
      });
    }

    _animationController.forward();
  }

  String _getResultMessage() {
    if (widget.score >= 80) return 'Xuất sắc! 🎉';
    if (widget.score >= 60) return 'Tốt lắm! 👍';
    if (widget.score >= 40) return 'Cố gắng thêm! 💪';
    return 'Hãy học lại nhé! 📚';
  }

  Color _getResultColor() {
    if (widget.score >= 80) return Color(0xFF4CAF50);
    if (widget.score >= 60) return Color(0xFF2196F3);
    if (widget.score >= 40) return Color(0xFFFF9800);
    return Color(0xFFEF5350);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}m ${secs}s';
  }

  // 🔥 NEW: Smart split function - ignore commas inside parentheses
  List<String> _smartSplitTopics(String text) {
    List<String> result = [];
    StringBuffer current = StringBuffer();
    int parenthesesDepth = 0;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == '(') {
        parenthesesDepth++;
        current.write(char);
      } else if (char == ')') {
        parenthesesDepth--;
        current.write(char);
      } else if (char == ',' && parenthesesDepth == 0) {
        // Split only if comma is OUTSIDE parentheses
        final trimmed = current.toString().trim();
        if (trimmed.isNotEmpty) {
          result.add(trimmed);
        }
        current.clear();
      } else {
        current.write(char);
      }
    }

    // Add last part
    final trimmed = current.toString().trim();
    if (trimmed.isNotEmpty) {
      result.add(trimmed);
    }

    return result;
  }

  // 🔥 NEW: Build topic with line breaks
  Widget _buildTopicText() {
    final topics = _smartSplitTopics(widget.topic);

    // If single topic, display normally
    if (topics.length == 1) {
      return Text(
        topics.first,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: Color(0xFF757575),
          height: 1.4,
        ),
      );
    }

    // Multiple topics - display each on new line
    return Column(
      children: topics.asMap().entries.map((entry) {
        final index = entry.key;
        final topic = entry.value;
        final isLast = index == topics.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
          child: Text(
            topic + (isLast ? '' : ','),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF757575),
              height: 1.4,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // CONFETTI
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.3,
              shouldLoop: false,
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF2196F3),
                Color(0xFFFF9800),
                Color(0xFFE91E63),
                Color(0xFF9C27B0),
              ],
            ),
          ),

          // CONTENT
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // APP BAR
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: false,
                  leading: IconButton(
                    icon: Icon(Icons.close, color: Color(0xFF1A1A1A)),
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  ),
                ),

                // BODY
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // RESULT CARD
                        _buildResultCard(),
                        SizedBox(height: 24),

                        // STATS GRID
                        _buildStatsGrid(),
                        SizedBox(height: 24),

                        // TOGGLE DETAILS BUTTON
                        _buildToggleDetailsButton(),
                        SizedBox(height: 16),

                        // DETAILS (if shown)
                        if (_showDetails) ...[
                          _buildQuestionDetails(),
                          SizedBox(height: 24),
                        ],

                        // ACTION BUTTONS
                        _buildActionButtons(),
                      ],
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

  Widget _buildResultCard() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getResultColor().withOpacity(0.1),
            _getResultColor().withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _getResultColor(), width: 2),
      ),
      child: Column(
        children: [
          // EMOJI/ICON
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _getResultColor().withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.score >= 50 ? Icons.emoji_events : Icons.school,
              size: 40,
              color: _getResultColor(),
            ),
          ),
          SizedBox(height: 20),

          // MESSAGE
          Text(
            _getResultMessage(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _getResultColor(),
            ),
          ),
          SizedBox(height: 12),

          // 🔥 UPDATED: TOPIC with line breaks
          _buildTopicText(),
          
          SizedBox(height: 24),

          // ANIMATED SCORE
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              return Column(
                children: [
                  Text(
                    '${_scoreAnimation.value.toInt()}%',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: _getResultColor(),
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${widget.correctCount}/${widget.totalQuestions} câu đúng',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.timer,
            label: 'Thời gian',
            value: _formatTime(widget.timeSpent),
            color: Color(0xFF2196F3),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.speed,
            label: 'Tốc độ TB',
            value: '${(widget.timeSpent / widget.totalQuestions).toStringAsFixed(1)}s/câu',
            color: Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF757575),
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleDetailsButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _showDetails = !_showDetails);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE0E0E0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showDetails ? Icons.visibility_off : Icons.visibility,
              size: 20,
              color: Color(0xFF2196F3),
            ),
            SizedBox(width: 12),
            Text(
              _showDetails ? 'Ẩn chi tiết' : 'Xem chi tiết từng câu',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
            SizedBox(width: 8),
            Icon(
              _showDetails ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Color(0xFF2196F3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chi tiết từng câu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: 16),
        ...widget.questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          final userAnswer = widget.userAnswers[question['id']];
          final correctAnswer = question['correct_answer'];
          final isCorrect = userAnswer == correctAnswer;

          return _buildQuestionDetailCard(
            index: index,
            question: question,
            userAnswer: userAnswer,
            correctAnswer: correctAnswer,
            isCorrect: isCorrect,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildQuestionDetailCard({
    required int index,
    required Map<String, dynamic> question,
    String? userAnswer,
    required String correctAnswer,
    required bool isCorrect,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Color(0xFF4CAF50) : Color(0xFFEF5350),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Color(0xFF4CAF50).withOpacity(0.1)
                      : Color(0xFFEF5350).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: isCorrect ? Color(0xFF4CAF50) : Color(0xFFEF5350),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Câu ${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? Color(0xFF4CAF50) : Color(0xFFEF5350),
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              Text(
                isCorrect ? 'Đúng' : 'Sai',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Color(0xFF4CAF50) : Color(0xFFEF5350),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // QUESTION
          Text(
            question['question'],
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              height: 1.4,
            ),
          ),
          SizedBox(height: 12),

          // USER ANSWER
          if (userAnswer != null) ...[
            _buildAnswerRow(
              label: 'Bạn chọn:',
              answer: userAnswer,
              isCorrect: isCorrect,
              isUserAnswer: true,
            ),
            SizedBox(height: 8),
          ],

          // CORRECT ANSWER (if wrong)
          if (!isCorrect) ...[
            _buildAnswerRow(
              label: 'Đáp án đúng:',
              answer: correctAnswer,
              isCorrect: true,
              isUserAnswer: false,
            ),
            SizedBox(height: 8),
          ],

          // EXPLANATION (if exists)
          if (question['explanation'] != null) ...[
            Divider(),
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFFF9800)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question['explanation'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF757575),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerRow({
    required String label,
    required String answer,
    required bool isCorrect,
    required bool isUserAnswer,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757575),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCorrect
                  ? Color(0xFF4CAF50).withOpacity(0.1)
                  : Color(0xFFEF5350).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isCorrect ? Color(0xFF4CAF50) : Color(0xFFEF5350),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // PRIMARY BUTTON
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: Icon(Icons.home),
            label: Text(
              'Về trang chủ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2196F3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        SizedBox(height: 12),

        // SECONDARY BUTTON
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement practice again with same topic
              Navigator.of(context).pop();
            },
            icon: Icon(Icons.refresh),
            label: Text(
              'Luyện lại chủ đề này',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFF2196F3),
              side: BorderSide(color: Color(0xFF2196F3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}