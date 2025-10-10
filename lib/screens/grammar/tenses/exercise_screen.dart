import 'package:flutter/material.dart';
import 'package:learning_english/models/exercise_progress.dart';
import 'package:learning_english/service/exercise_progress_service.dart';
import 'package:learning_english/service/grammar_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExerciseScreen extends StatefulWidget {
  final String lessonId;
  const ExerciseScreen({super.key, required this.lessonId});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  final _exerciseProgressService = ExerciseProgressService();
  final GrammarService _grammarService = GrammarService();

  List<Map<String, dynamic>> _exercises = [];
  Map<String, bool> _progressResults = {}; // Kết quả từ DB
  Map<String, String?> _answers = {};
  bool _loading = true;
  bool _submitted = false;
  bool _hasProgress = false;
  int _correctCount = 0;

  @override
  void initState() {
    super.initState();
    _loadExercisesAndProgress();
  }

  // Load exercises và progress
  Future<void> _loadExercisesAndProgress() async {
    setState(() => _loading = true);

    try {
      // Load exercises
      final exercises = await _grammarService.getExercisesByLesson(widget.lessonId);

      // Load progress từ DB
      final progress = await _exerciseProgressService.getProgressByLesson(
        userId!,
        widget.lessonId,
      );

      Map<String, String?> loadedAnswers = {};
      Map<String, bool> results = {};
      int correct = 0;

      if (progress.isNotEmpty) {
        for (var p in progress) {
          loadedAnswers[p.exerciseId] = p.userAnswer;
          results[p.exerciseId] = p.isCorrect;
          if (p.isCorrect) correct++;
        }
      }

      setState(() {
        _exercises = exercises;
        _answers = loadedAnswers;
        _progressResults = results;
        _hasProgress = progress.isNotEmpty;
        _submitted = progress.isNotEmpty;
        _correctCount = correct;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading: $e');
      setState(() => _loading = false);
    }
  }

  // Submit exercises
  void _submitExercises() async {
    if (userId == null) return;

    int correct = 0;
    Map<String, bool> results = {};

    // Tính điểm và save từng câu
    for (var exercise in _exercises) {
      final userAnswer = _answers[exercise['id']]?.trim().toLowerCase() ?? '';
      final correctAnswer = exercise['correct_answer']?.trim().toLowerCase() ?? '';
      final isCorrect = userAnswer == correctAnswer;

      if (isCorrect) correct++;
      results[exercise['id']] = isCorrect;

      // Save vào DB
      await _exerciseProgressService.saveProgress(
        ExerciseProgress(
          userId: userId!,
          lessonId: widget.lessonId,
          exerciseId: exercise['id'],
          userAnswer: userAnswer,
          isCorrect: isCorrect,
          explanation: exercise['explanation'] ?? '',
          completedAt: DateTime.now(),
        ),
      );
    }

    setState(() {
      _submitted = true;
      _correctCount = correct;
      _progressResults = results;
      _hasProgress = true;
    });

    _showResultDialog();
  }

  void _showResultDialog() {
    final total = _exercises.length;
    final percentage = ((_correctCount / total) * 100).toInt();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              percentage >= 80 ? Icons.emoji_events : Icons.mood,
              color: percentage >= 80 ? Colors.amber : Colors.blue,
              size: 32,
            ),
            SizedBox(width: 12),
            Text('Kết quả'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: percentage >= 80 ? Colors.green[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '$_correctCount/$total',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: percentage >= 80 ? Colors.green : Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Đúng $_correctCount câu / $total câu',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: percentage >= 80 ? Colors.green : Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              percentage >= 80
                  ? '🎉 Xuất sắc! Bạn đã nắm vững kiến thức!'
                  : percentage >= 60
                  ? '👍 Khá tốt! Hãy xem lại các câu sai nhé!'
                  : '💪 Đừng nản! Xem lại lý thuyết và thử lại nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Xem giải thích', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // Reset exercises - XÓA PROGRESS TRONG DB
  void _resetExercises() async {
    if (userId == null) return;

    // Xóa trong DB
    await _exerciseProgressService.resetProgress(userId!, widget.lessonId);

    setState(() {
      _answers.clear();
      _progressResults.clear();
      _submitted = false;
      _hasProgress = false;
      _correctCount = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.refresh, color: Colors.white),
            SizedBox(width: 12),
            Text('Đã reset bài tập. Hãy làm lại từ đầu!'),
          ],
        ),
        backgroundColor: Colors.blue[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text('Đang tải bài tập...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('Chưa có bài tập nào cho bài học này.'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Progress bar - CẬP NHẬT
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _hasProgress ? Icons.check_circle : Icons.pending,
                        color: _hasProgress ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _hasProgress
                            ? 'Đã hoàn thành'
                            : 'Tiến độ: ${_answers.length}/${_exercises.length}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_submitted)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Điểm: $_correctCount/${_exercises.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: _hasProgress ? 1.0 : (_answers.length / _exercises.length),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  _hasProgress ? Colors.green : Colors.blue,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),

        // Exercise list - CẬP NHẬT
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _exercises.length,
            itemBuilder: (context, index) {
              final exercise = _exercises[index];
              final exerciseId = exercise['id'];

              // Lấy kết quả từ _progressResults (đã load từ DB)
              final isCorrect = _progressResults[exerciseId] ?? false;
              final isWrong = _submitted && !isCorrect;

              return _buildExerciseCard(exercise, index, isCorrect, isWrong);
            },
          ),
        ),

        // Submit button
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_submitted)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetExercises,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Làm lại', style: TextStyle(fontSize: 16)),
                  ),
                ),
              if (_submitted) SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitted
                      ? null
                      : (_answers.length == _exercises.length ? _submitExercises : null),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue[600],
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _submitted ? 'Đã nộp bài' : 'Nộp bài',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(
      Map<String, dynamic> exercise,
      int index,
      bool isCorrect,
      bool isWrong,
      ) {
    final type = exercise['question_type'];
    final options = exercise['options'] != null
        ? List<String>.from(exercise['options'])
        : [];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect
              ? Colors.green
              : isWrong
              ? Colors.red
              : Colors.grey[300]!,
          width: isCorrect || isWrong ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question number
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Câu ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                Spacer(),
                if (isCorrect)
                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                if (isWrong) Icon(Icons.cancel, color: Colors.red, size: 24),
              ],
            ),
            SizedBox(height: 12),

            // Question text
            Text(
              exercise['question_text'],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),

            // Answer options
            if (type == 'multiple_choice')
              ...options.map((opt) {
                final isSelected = _answers[exercise['id']] == opt;
                final isCorrectOption =
                    _submitted && opt == exercise['correct_answer'];

                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isCorrectOption
                        ? Colors.green[50]
                        : isSelected && isWrong
                        ? Colors.red[50]
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCorrectOption
                          ? Colors.green
                          : isSelected && isWrong
                          ? Colors.red
                          : isSelected
                          ? Colors.blue
                          : Colors.grey[300]!,
                      width: isCorrectOption || (isSelected && isWrong) ? 2 : 1,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: Text(
                      opt,
                      style: TextStyle(
                        color: isCorrectOption ? Colors.green[800] : Colors.black87,
                        fontWeight:
                        isCorrectOption ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    value: opt,
                    groupValue: _answers[exercise['id']],
                    onChanged: _submitted
                        ? null
                        : (value) {
                      setState(() {
                        _answers[exercise['id']] = value;
                      });
                    },
                    activeColor: isCorrectOption ? Colors.green : Colors.blue,
                  ),
                );
              }).toList(),

            if (type == 'fill_in_the_blank')
              TextField(
                enabled: !_submitted,
                controller: TextEditingController(text: _answers[exercise['id']]),
                decoration: InputDecoration(
                  labelText: 'Nhập câu trả lời',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue, width: 2),
                  ),
                  filled: true,
                  fillColor: _submitted ? Colors.grey[100] : Colors.white,
                ),
                onChanged: (value) {
                  setState(() {
                    _answers[exercise['id']] = value;
                  });
                },
              ),

            // Explanation after submit
            if (_submitted && exercise['explanation'] != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(color: Colors.blue, width: 4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.blue[700], size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Giải thích:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      exercise['explanation'],
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Đáp án đúng: ${exercise['correct_answer']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}