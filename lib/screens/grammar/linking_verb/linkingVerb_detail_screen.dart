import 'package:flutter/material.dart';
import 'package:learning_english/service/grammar_service.dart';
import 'package:learning_english/models/lesson.dart';
import 'package:learning_english/models/lesson_content.dart';
import 'package:learning_english/models/exercise.dart';
import 'package:learning_english/screens/grammar/exercise_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen>
    with SingleTickerProviderStateMixin {
  final GrammarService _grammarService = GrammarService();
  late TabController _tabController;
  List<LessonContent> _contents = [];
  int _exerciseCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLessonData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLessonData() async {
    try {
      final contents = await _grammarService.getLessonContents(widget.lesson.id);
      final exercises = await _grammarService.getExercisesByLesson(widget.lesson.id);

      setState(() {
        _contents = contents;
        _exerciseCount = exercises.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải dữ liệu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.lessonTitleEn),
        backgroundColor: Colors.green,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Nội dung', icon: Icon(Icons.book)),
            Tab(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.assignment),
                      SizedBox(width: 6),
                      Text('Bài tập'),
                    ],
                  ),
                  if (_exerciseCount > 0)
                    Positioned(
                      right: -25,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green, width: 1),
                        ),
                        child: Text(
                          '$_exerciseCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildContentTab(),
          _buildExerciseTab(),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    if (_contents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Chưa có nội dung bài học',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contents.length,
      itemBuilder: (context, index) {
        final content = _contents[index];
        return _buildContentCard(content);
      },
    );
  }

  Widget _buildContentCard(LessonContent content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.type == 'heading' || content.type == 'title')
              Text(
                content.dataTitle ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              )
            else if (content.type == 'paragraph' || content.type == 'text')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (content.dataTitle != null && content.dataTitle!.isNotEmpty) ...[
                    Text(
                      content.dataTitle!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    content.dataBody ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              )
            else if (content.type == 'example')
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
                          Icon(Icons.lightbulb, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Ví dụ:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        content.exampleSentence ?? '',
                        style: const TextStyle(fontSize: 15),
                      ),
                      if (content.exampleTranslation != null &&
                          content.exampleTranslation!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          content.exampleTranslation!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Text(content.dataBody ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTab() {
    if (_exerciseCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Chưa có bài tập',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // SỬ DỤNG CHUNG ExerciseScreen đã có
    return ExerciseScreen(lessonId: widget.lesson.id);
  }
}