import 'package:flutter/material.dart';
import 'package:learning_english/models/exercise_progress.dart';
import 'package:learning_english/services/exercise_progress_service.dart';
import 'package:learning_english/services/grammar_service.dart';
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
  Set<String> _submittedExercises = {}; // Track câu đã nộp
  bool _loading = true;
  int _correctCount = 0;

  @override
  void initState() {
    super.initState();
    _loadExercisesAndProgress();
  }

  Future<void> _loadExercisesAndProgress() async {
    setState(() => _loading = true);

    try {
      final exercises = await _grammarService.getExercisesByLesson(widget.lessonId);
      final progress = await _exerciseProgressService.getProgressByLesson(
        userId!,
        widget.lessonId,
      );

      Map<String, String?> loadedAnswers = {};
      Map<String, bool> results = {};
      Set<String> submitted = {};
      int correct = 0;

      if (progress.isNotEmpty) {
        for (var p in progress) {
          loadedAnswers[p.exerciseId] = p.userAnswer;
          results[p.exerciseId] = p.isCorrect;
          submitted.add(p.exerciseId);
          if (p.isCorrect) correct++;
        }
      }

      setState(() {
        _exercises = exercises;
        _answers = loadedAnswers;
        _progressResults = results;
        _submittedExercises = submitted;
        _correctCount = correct;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading: $e');
      setState(() => _loading = false);
    }
  }

  // Nộp từng câu
  Future<void> _submitSingleExercise(Map<String, dynamic> exercise) async {
    if (userId == null) return;

    final exerciseId = exercise['id'];
    final userAnswer = _answers[exerciseId]?.trim().toLowerCase() ?? '';
    final correctAnswer = exercise['correct_answer']?.trim().toLowerCase() ?? '';
    final isCorrect = userAnswer == correctAnswer;

    // Save vào DB
    await _exerciseProgressService.saveProgress(
      ExerciseProgress(
        userId: userId!,
        lessonId: widget.lessonId,
        exerciseId: exerciseId,
        userAnswer: userAnswer,
        isCorrect: isCorrect,
        explanation: exercise['explanation'] ?? '',
        completedAt: DateTime.now(),
      ),
    );

    setState(() {
      _progressResults[exerciseId] = isCorrect;
      _submittedExercises.add(exerciseId);
      if (isCorrect) {
        _correctCount++;
      } else {
        // Nếu submit lại câu đã đúng trước đó mà bây giờ sai
        if (_progressResults[exerciseId] == true && !isCorrect) {
          _correctCount--;
        }
      }
    });

    // Show snackbar feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Text(isCorrect ? 'Chính xác! 🎉' : 'Sai rồi, xem giải thích nhé!'),
          ],
        ),
        backgroundColor: isCorrect ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Reset 1 câu
  Future<void> _resetSingleExercise(String exerciseId) async {
    if (userId == null) return;

    await _exerciseProgressService.deleteSingleProgress(userId!, exerciseId);

    setState(() {
      final wasCorrect = _progressResults[exerciseId] ?? false;
      if (wasCorrect) _correctCount--;

      _answers.remove(exerciseId);
      _progressResults.remove(exerciseId);
      _submittedExercises.remove(exerciseId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã reset câu này. Hãy làm lại!'),
        backgroundColor: Colors.blue[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Reset toàn bộ
  Future<void> _resetAll() async {
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset tất cả?'),
        content: Text('Bạn có chắc muốn reset toàn bộ bài tập?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: TextStyle(color: Colors.black),),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _exerciseProgressService.resetProgress(userId!, widget.lessonId);

    setState(() {
      _answers.clear();
      _progressResults.clear();
      _submittedExercises.clear();
      _correctCount = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã reset toàn bộ bài tập!'),
        backgroundColor: Colors.blue[600],
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

    final completedCount = _submittedExercises.length;
    final totalCount = _exercises.length;

    return Column(
      children: [
        // Progress bar
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        completedCount == totalCount
                            ? Icons.check_circle
                            : Icons.pending,
                        color: completedCount == totalCount
                            ? Colors.green
                            : Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tiến độ: $completedCount/$totalCount',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '✓ $_correctCount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '✗ ${completedCount - _correctCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: completedCount / totalCount,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  completedCount == totalCount ? Colors.green : Colors.blue,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),

        // Exercise list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _exercises.length,
            itemBuilder: (context, index) {
              final exercise = _exercises[index];
              final exerciseId = exercise['id'];
              final isSubmitted = _submittedExercises.contains(exerciseId);
              final isCorrect = _progressResults[exerciseId] ?? false;
              final isWrong = isSubmitted && !isCorrect;

              return _buildExerciseCard(
                exercise,
                index,
                isSubmitted,
                isCorrect,
                isWrong,
              );
            },
          ),
        ),

        // Reset all button
        if (completedCount > 0)
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
            child: OutlinedButton(
              onPressed: _resetAll,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Reset tất cả',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExerciseCard(
      Map<String, dynamic> exercise,
      int index,
      bool isSubmitted,
      bool isCorrect,
      bool isWrong,
      ) {
    final exerciseId = exercise['id'];
    final type = exercise['question_type'];
    final options = exercise['options'] != null
        ? List<String>.from(exercise['options'])
        : [];
    final canSubmit = _answers[exerciseId] != null &&
        _answers[exerciseId]!.trim().isNotEmpty;

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
          width: isSubmitted ? 2 : 1,
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
            // Header
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
                if (isSubmitted)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCorrect ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect ? Colors.green : Colors.red,
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          isCorrect ? 'Đúng' : 'Sai',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCorrect ? Colors.green[800] : Colors.red[800],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),

            // Question
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
                final isSelected = _answers[exerciseId] == opt;
                final isCorrectOption =
                    isSubmitted && opt == exercise['correct_answer'];

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
                        color: isCorrectOption
                            ? Colors.green[800]
                            : Colors.black87,
                        fontWeight: isCorrectOption
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    value: opt,
                    groupValue: _answers[exerciseId],
                    onChanged: isSubmitted
                        ? null
                        : (value) {
                      setState(() {
                        _answers[exerciseId] = value;
                      });
                    },
                    activeColor: isCorrectOption ? Colors.green : Colors.blue,
                  ),
                );
              }).toList(),

            if (type == 'fill_in_the_blank')
              TextField(
                enabled: !isSubmitted,
                controller: TextEditingController(text: _answers[exerciseId]),
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
                  fillColor: isSubmitted ? Colors.grey[100] : Colors.white,
                ),
                onChanged: (value) {
                  setState(() {
                    _answers[exerciseId] = value;
                  });
                },
              ),

            SizedBox(height: 16),

            // Submit/Reset button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSubmitted
                        ? null
                        : (canSubmit
                        ? () => _submitSingleExercise(exercise)
                        : null),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue[600],
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isSubmitted ? 'Đã nộp' : 'Nộp câu này',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (isSubmitted) ...[
                  SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => _resetSingleExercise(exerciseId),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      side: BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Icon(Icons.refresh, color: Colors.orange),
                  ),
                ],
              ],
            ),

            // Explanation
            if (isSubmitted && exercise['explanation'] != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: isCorrect ? Colors.green : Colors.blue,
                      width: 4,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: isCorrect ? Colors.green[700] : Colors.blue[700],
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Giải thích:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCorrect ? Colors.green[700] : Colors.blue[700],
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
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check, color: Colors.green[700], size: 18),
                          SizedBox(width: 8),
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
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}