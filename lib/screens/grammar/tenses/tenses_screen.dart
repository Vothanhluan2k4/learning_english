import 'package:flutter/material.dart';
import 'package:learning_english/models/lesson.dart';
import 'package:learning_english/service/tenses_service.dart';
import '../tenses/lesson_detail_screen.dart';

class TensesScreen extends StatefulWidget {
  const TensesScreen({super.key});

  @override
  State<TensesScreen> createState() => _TensesScreenState();
}

class _TensesScreenState extends State<TensesScreen> {
  final TensesService _tensesService = TensesService();
  List<Lesson> lessons = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final result = await _tensesService.getLessonsByTopicName('Tenses');
      setState(() {
        lessons = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tenses"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 60),
            const SizedBox(height: 10),
            Text("Lỗi: $errorMessage"),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _loadLessons,
              child: const Text("Thử lại"),
            )
          ],
        ),
      );
    }

    if (lessons.isEmpty) {
      return const Center(
        child: Text("Chưa có bài học nào cho chủ đề này."),
      );
    }

    return ListView.builder(
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            title: Text(
              lesson.lessonTitleVi,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              lesson.lessonTitleEn ?? "",
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LessonDetailScreen(lessonId: lesson.id), // ✅ sửa ở đây
                ),
              );
            },
          ),
        );
      },
    );
  }
}
