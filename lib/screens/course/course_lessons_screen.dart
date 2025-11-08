import 'package:flutter/material.dart';
import 'package:learning_english/screens/course/test_preview_screen.dart'; 
import '../../models/course_module.dart';
import '../../models/lesson_course.dart';
import '../../services/lesson_course_service.dart';
import '../../services/course_module_service.dart';
import '../../widgets/courses/lesson_card_widget.dart';

class CourseLessonsScreen extends StatefulWidget {
  final String moduleId;

  const CourseLessonsScreen({
    required this.moduleId,
    super.key,
  });

  @override
  State<CourseLessonsScreen> createState() => _CourseLessonsScreenState();
}

class _CourseLessonsScreenState extends State<CourseLessonsScreen> {
  final _lessonService = LessonCourseService();
  final _moduleService = CourseModuleService();
  bool _lessonCompleted = false;

  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    try {
      final module = await _moduleService.fetchModuleById(widget.moduleId);
      final lessons = await _lessonService.fetchLessonsByModule(widget.moduleId);

      return {
        'module': module,
        'lessons': lessons,
      };
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      rethrow;
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Đang tải...'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Lỗi'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text('Lỗi: ${snapshot.error}'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dataFuture = _loadData();
                      });
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data;
        final module = data?['module'] as CourseModule?;
        final lessons = data?['lessons'] as List<LessonCourse>? ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text(
              module?.moduleName ?? 'Bài học',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: lessons.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không có bài học nào',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _dataFuture = _loadData();
                    });
                    await _dataFuture;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: lessons.length,
                    itemBuilder: (context, index) {
                      final lesson = lessons[index];
                      return LessonCardWidget(
                        lesson: lesson,
                        onTap: () {
                          _handleLessonTap(context, lesson);
                        },
                      );
                    },
                  ),
                ),
        );
      },
    );
  }

  void _handleLessonTap(BuildContext context, LessonCourse lesson) async {
    if (lesson.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bài học "${lesson.lessonName}" đang bị khóa',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    if (lesson.lessonType == 'final_test' || lesson.lessonType == 'mid_test') {
      if (lesson.testId != null && lesson.testId!.isNotEmpty) {
        debugPrint('🚀 Navigate to TestPreviewScreen');
        
        // 🔥 UPDATED: Await navigation result
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TestPreviewScreen(
              testId: lesson.testId!,
              lessonId: lesson.id,
              lesson: lesson,
            ),
          ),
        );
        
        // 🔥 NEW: Reload data after returning
        if (mounted) {
          debugPrint('🔄 Returned from test, reloading lessons...');
          setState(() {
            _dataFuture = _loadData();
          });
        }
        
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bài kiểm tra chưa được cấu hình đúng',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      }
    }

    // 🔥 UPDATED: Await navigation result
    await Navigator.pushNamed(
      context,
      '/lessonDetail',
      arguments: {'lessonId': lesson.id},
    );
    
    // 🔥 NEW: Reload data after returning
    if (mounted) {
      debugPrint('🔄 Returned from lesson detail, reloading lessons...');
      setState(() {
        _dataFuture = _loadData();
      });
    }
  }
}