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
  Map<String, bool> _progressResults = {};
  Map<String, String?> _answers = {};
  Set<String> _submittedExercises = {};
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

  Future<void> _submitSingleExercise(Map<String, dynamic> exercise) async {
    if (userId == null) return;

    final exerciseId = exercise['id'];
    final userAnswer = _answers[exerciseId]?.trim().toLowerCase() ?? '';
    final correctAnswer = exercise['correct_answer']?.trim().toLowerCase() ?? '';
    final isCorrect = userAnswer == correctAnswer;

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
        if (_progressResults[exerciseId] == true && !isCorrect) {
          _correctCount--;
        }
      }
    });

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
            child: Text('Hủy', style: TextStyle(color: Colors.black)),
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
            CircularProgressIndicator(color: Colors.red[700]),
            const SizedBox(height: 16),
            Text(
              'Đang tải bài tập...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Chưa có bài tập',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Bài tập sẽ sớm được cập nhật',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final completedCount = _submittedExercises.length;
    final totalCount = _exercises.length;

    return Column(
      children: [
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
                        completedCount == totalCount ? Icons.check_circle : Icons.pending,
                        color: completedCount == totalCount ? Colors.green : Colors.orange,
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
                  completedCount == totalCount ? Colors.green : Colors.red[700]!,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadExercisesAndProgress,
            color: Colors.red[700],
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _exercises.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildExerciseHeader();
                }

                final exercise = _exercises[index - 1];
                final exerciseId = exercise['id'];
                final type = exercise['question_type'];
                final options = exercise['options'] != null
                    ? List<String>.from(exercise['options'])
                    : [];
                final isSubmitted = _submittedExercises.contains(exerciseId);
                final isCorrect = _progressResults[exerciseId] ?? false;
                final isWrong = isSubmitted && !isCorrect;
                final canSubmit = _answers[exerciseId] != null &&
                    _answers[exerciseId]!.trim().isNotEmpty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
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
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red[400]!, Colors.red[600]!],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$index',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      type == 'multiple_choice'
                                          ? '📝 Trắc nghiệm'
                                          : '✍️ Điền từ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    exercise['question_text'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      height: 1.4,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSubmitted)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? Colors.green[100]
                                      : Colors.red[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isCorrect
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: isCorrect ? Colors.green : Colors.red,
                                      size: 18,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      isCorrect ? 'Đúng' : 'Sai',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCorrect
                                            ? Colors.green[800]
                                            : Colors.red[800],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (type == 'multiple_choice')
                          Column(
                            children: options.asMap().entries.map((entry) {
                              final opt = entry.value;
                              final isSelected = _answers[exerciseId] == opt;
                              final isCorrectOption = isSubmitted &&
                                  opt == exercise['correct_answer'];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
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
                                        ? Colors.red[700]!
                                        : Colors.grey[200]!,
                                    width: isCorrectOption || (isSelected && isWrong)
                                        ? 2
                                        : 1,
                                  ),
                                ),
                                child: RadioListTile<String>(
                                  title: Text(
                                    opt,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isCorrectOption
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isCorrectOption
                                          ? Colors.green[900]!
                                          : Colors.black87,
                                    ),
                                  ),
                                  value: opt,
                                  groupValue: _answers[exerciseId],
                                  activeColor: Colors.red[700],
                                  contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onChanged: isSubmitted
                                      ? null
                                      : (value) {
                                    setState(() {
                                      _answers[exerciseId] = value;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),

                        if (type == 'fill_in_the_blank')
                          TextField(
                            readOnly: isSubmitted,
                            controller:
                            TextEditingController(text: _answers[exerciseId]),
                            decoration: InputDecoration(
                              labelText: 'Nhập câu trả lời của bạn',
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: isSubmitted
                                    ? BorderSide(
                                    color: isCorrect
                                        ? Colors.green[300]!
                                        : Colors.red[300]!,
                                    width: 2)
                                    : BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Colors.red[700]!, width: 2),
                              ),
                              prefixIcon: Icon(Icons.edit, color: Colors.red[700]),
                            ),
                            style: const TextStyle(fontSize: 15),
                            onChanged: isSubmitted
                                ? null
                                : (value) {
                              setState(() {
                                _answers[exerciseId] = value;
                              });
                            },
                          ),

                        SizedBox(height: 16),

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
                                  backgroundColor: Colors.red[700],
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
                                  padding: EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
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

                        if (isSubmitted && exercise['explanation'] != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
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
                                      color: isCorrect
                                          ? Colors.green[700]
                                          : Colors.blue[700],
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Giải thích:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCorrect
                                            ? Colors.green[700]
                                            : Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(exercise['explanation'] ?? ''),
                                const SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check,
                                          color: Colors.green[700], size: 18),
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
              },
            ),
          ),
        ),

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

  Widget _buildExerciseHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange[400]!, Colors.red[600]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bài tập thực hành',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_exercises.length} câu hỏi',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_exercises.length}',
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}