import 'package:flutter/material.dart';
import 'package:learning_english/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/course_module.dart';
import '../../models/lesson_course.dart';
import '../../services/lesson_course_service.dart';
import '../../services/lesson_section_service.dart';
import '../../services/user_attempt_service.dart';
import '../../widgets/courses/section_content_widget.dart';
import 'course_quiz_content.dart'; 
import 'final_test_screen.dart'; 

class CourseLessonDetailScreen extends StatefulWidget {
  final String lessonId;

  const CourseLessonDetailScreen({
    required this.lessonId,
    super.key,
  });

  @override
  State<CourseLessonDetailScreen> createState() =>
      _CourseLessonDetailScreenState();
}

class _CourseLessonDetailScreenState extends State<CourseLessonDetailScreen>
    with TickerProviderStateMixin {
  final _lessonService = LessonCourseService();
  final _sectionService = LessonSectionService();
  final _attemptService = UserAttemptService();

  late Future<Map<String, dynamic>> _dataFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadData() async {
    try {
      debugPrint('📚 Loading lesson detail for: ${widget.lessonId}');

      final lesson = await _lessonService.fetchLessonById(widget.lessonId);
      final fullContent =
          await _sectionService.fetchFullLessonContent(widget.lessonId);

      return {
        'lesson': lesson,
        'content': fullContent,
      };
    } catch (e) {
      debugPrint('❌ Error loading lesson detail: $e');
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
        final lesson = data?['lesson'] as LessonCourse?;
        final fullContent = data?['content'] as Map<String, dynamic>? ?? {};
        final sections = fullContent['sections'] as List? ?? [];
        final content = fullContent['content'] as Map<String, dynamic>? ?? {};

        final allQuestions = <Map<String, dynamic>>[];
        for (var section in sections) {
          final sectionContent = content[section.id] as Map?;
          final questions = sectionContent?['questions'] as List? ?? [];
          allQuestions.addAll(questions.cast());
        }

        // ✅ Debug target_score
        debugPrint('📊 Lesson: ${lesson?.lessonName}');
        debugPrint('   Target Score: ${lesson?.targetScore} (type: ${lesson?.targetScore.runtimeType})');
        debugPrint('   Total Questions: ${allQuestions.length}');

        return Scaffold(
          appBar: AppBar(
            title: Text(
              lesson?.lessonName ?? 'Bài học',
              style: const TextStyle(
                fontSize: 18,
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
          body: Column(
            children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue.shade700,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: Colors.blue.shade700,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.book),
                      text: 'Ôn tập',
                    ),
                    Tab(
                      icon: Icon(Icons.quiz),
                      text: 'Bài tập',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReviewTab(lesson, sections, content),
                    // ✅ Kiểm tra loại bài
                    lesson?.lessonType == 'final_test' || lesson?.lessonType == 'mid_test'
                      ? FinalTestScreen(
                          testId: lesson!.testId ?? widget.lessonId,
                          lessonId: widget.lessonId,
                          isPlacementTest: false,
                          targetScore: _getTargetScore(lesson),
                        )
                      : CourseQuizContent(
                          lessonId: widget.lessonId,
                          questions: allQuestions,
                          attemptService: _attemptService,
                          sectionService: _sectionService,
                          targetScore: _getTargetScore(lesson),
                          totalQuestions: allQuestions.length,
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewTab(
    LessonCourse? lesson,
    List sections,
    Map<String, dynamic> content,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lesson != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.lessonName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (lesson.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            lesson.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (sections.isEmpty)
            Center(
              child: Text(
                'Không có nội dung ôn tập',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            )
          else
            ...sections.asMap().entries.map((entry) {
              final section = entry.value;
              final sectionContent = content[section.id] as Map?;
              final medias = sectionContent?['medias'] as List? ?? [];

              if (section.sectionType == 'quiz') {
                return const SizedBox.shrink();
              }

              return SectionContentWidget(
                section: section,
                medias: medias.cast(),
                questionsWithOptions: [],
                allowReplay: true,
              );
            }).toList(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// ✅ Helper: Lấy target_score an toàn
  double _getTargetScore(LessonCourse? lesson) {
    if (lesson == null) return 50.0;
    
    final score = lesson.targetScore;
    debugPrint('🎯 Using target score: $score');
    
    return score;
  }
}
