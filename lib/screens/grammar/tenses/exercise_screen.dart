import 'package:flutter/material.dart';
import 'package:learning_english/service/grammar_service.dart';

class ExerciseScreen extends StatefulWidget {
  final String lessonId;
  const ExerciseScreen({super.key, required this.lessonId});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final GrammarService _grammarService = GrammarService();
  List<Map<String, dynamic>> _exercises = [];
  Map<String, String?> _answers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final data = await _grammarService.getExercisesByLesson(widget.lessonId);
    setState(() {
      _exercises = data;
      _loading = false;
    });
  }

  void _checkAnswer(Map<String, dynamic> exercise) {
    final userAnswer = _answers[exercise['id']];
    final isCorrect = userAnswer == exercise['correct_answer'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isCorrect ? '🎉 Chính xác!' : '❌ Sai rồi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Câu trả lời đúng: ${exercise['correct_answer']}'),
            const SizedBox(height: 10),
            if (exercise['explanation'] != null)
              Text('Giải thích: ${exercise['explanation']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_exercises.isEmpty) {
      return const Center(child: Text('Không có bài tập nào cho bài học này.'));
    }

    return ListView.builder(
      itemCount: _exercises.length,
      itemBuilder: (context, index) {
        final exercise = _exercises[index];
        final type = exercise['question_type'];
        final options = exercise['options'] != null
            ? List<String>.from(exercise['options'])
            : [];

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Câu ${index + 1}: ${exercise['question_text']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                if (type == 'multiple_choice')
                  Column(
                    children: options.map((opt) {
                      return RadioListTile<String>(
                        title: Text(opt),
                        value: opt,
                        groupValue: _answers[exercise['id']],
                        onChanged: (value) {
                          setState(() {
                            _answers[exercise['id']] = value;
                          });
                        },
                      );
                    }).toList(),
                  ),
                if (type == 'fill_in_the_blank')
                  TextField(
                    decoration:
                    const InputDecoration(labelText: 'Nhập câu trả lời'),
                    onChanged: (value) {
                      _answers[exercise['id']] = value;
                    },
                  ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _checkAnswer(exercise),
                  child: const Text('Kiểm tra'),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
