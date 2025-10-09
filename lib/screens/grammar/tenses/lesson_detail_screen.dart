import 'package:flutter/material.dart';
import 'package:learning_english/service/grammar_service.dart';
import 'package:learning_english/models/lesson_content.dart';
import 'exercise_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final String lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final GrammarService _grammarService = GrammarService();
  Map<String, dynamic>? _lesson;
  List<LessonContent> _contents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    final lesson = await _grammarService.getLessonById(widget.lessonId);
    final contents = await _grammarService.getLessonContents(widget.lessonId);

    setState(() {
      _lesson = lesson;
      _contents = contents;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_lesson == null) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy bài học.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_lesson!['title'] ?? 'Chi tiết bài học'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Nội dung'),
              Tab(text: 'Bài tập'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _contents.length,
              itemBuilder: (context, index) {
                final content = _contents[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(content.dataTitle ?? '',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(content.dataBody ?? ''),
                    const Divider(height: 24),
                  ],
                );
              },
            ),
            ExerciseScreen(lessonId: widget.lessonId),
          ],
        ),
      ),
    );
  }
}
