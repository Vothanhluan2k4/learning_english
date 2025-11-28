import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; 
import 'package:url_launcher/url_launcher.dart';        
import '../../models/lesson_course.dart';
import '../../models/lesson_section.dart';
import '../../services/lesson_course_service.dart';
import '../../services/lesson_section_service.dart';
import '../../services/user_attempt_service.dart';
import 'course_quiz_content.dart';

class ReadingLessonScreen extends StatefulWidget {
  final String lessonId;

  const ReadingLessonScreen({
    required this.lessonId,
    super.key,
  });

  @override
  State<ReadingLessonScreen> createState() => _ReadingLessonScreenState();
}

class _ReadingLessonScreenState extends State<ReadingLessonScreen> {
  final _lessonService = LessonCourseService();
  final _sectionService = LessonSectionService();
  final _attemptService = UserAttemptService();
  final _scrollController = ScrollController();

  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadData() async {
    try {
      debugPrint('📚 Loading reading lesson: ${widget.lessonId}');

      final lesson = await _lessonService.fetchLessonById(widget.lessonId);
      final fullContent = await _sectionService.fetchFullLessonContent(widget.lessonId);

      return {
        'lesson': lesson,
        'content': fullContent,
      };
    } catch (e) {
      debugPrint('❌ Error loading reading lesson: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bài đọc hiểu',
          style: TextStyle(
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
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
            );
          }

          final data = snapshot.data;
          final lesson = data?['lesson'] as LessonCourse?;
          final fullContent = data?['content'] as Map<String, dynamic>? ?? {};
          final sections = fullContent['sections'] as List? ?? [];
          final content = fullContent['content'] as Map<String, dynamic>? ?? {};

          // ✅ Separate text sections and quiz sections
          final textSections = <LessonSection>[];
          final quizSections = <LessonSection>[];
          
          for (var section in sections) {
            if ( section.sectionType == 'reading') {
              textSections.add(section);
            } else if (section.sectionType == 'quiz') {
              quizSections.add(section);
            }
          }

          // ✅ Collect all questions
          final allQuestions = <Map<String, dynamic>>[];
          for (var section in quizSections) {
            final sectionContent = content[section.id] as Map?;
            final questions = sectionContent?['questions'] as List? ?? [];
            allQuestions.addAll(questions.cast());
          }

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ 1. Lesson Info
                if (lesson != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.purple.shade50],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.menu_book,
                            color: Colors.blue.shade700,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lesson.lessonName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              if (lesson.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  lesson.description!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
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
                  const SizedBox(height: 24),
                ],

                // ✅ 2. Reading Content (Text Sections with Markdown)
                if (textSections.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.article_outlined,
                    title: 'Đoạn văn',
                    count: textSections.length,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),

                  ...textSections.asMap().entries.map((entry) {
                    final index = entry.key;
                    final section = entry.value;
                    
                    return _buildTextSection(
                      section: section,
                      index: index + 1,
                    );
                  }).toList(),

                  const SizedBox(height: 32),
                ],

                // ✅ 3. Divider before questions
                if (textSections.isNotEmpty && allQuestions.isNotEmpty) ...[
                  Divider(
                    thickness: 2,
                    color: Colors.grey.shade300,
                    height: 40,
                  ),
                ],

                // ✅ 4. Questions Section
                if (allQuestions.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.quiz,
                    title: 'Câu hỏi',
                    count: allQuestions.length,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),

                  CourseQuizContent(
                    lessonId: widget.lessonId,
                    questions: allQuestions,
                    attemptService: _attemptService,
                    sectionService: _sectionService,
                    targetScore: _getTargetScore(lesson),
                    totalQuestions: allQuestions.length,
                  ),
                ],

                // ✅ 5. Empty state
                if (textSections.isEmpty && allQuestions.isEmpty) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không có nội dung',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// ✅ Build section header
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Build text section with Markdown support
  Widget _buildTextSection({
    required LessonSection section,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Đoạn $index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.sectionTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Divider
          Divider(color: Colors.grey.shade300),
          
          const SizedBox(height: 16),

          // ✅ NEW: Markdown Content
          if (section.content != null && section.content!.isNotEmpty)
            MarkdownBody(
              data: section.content!,
              selectable: true, // ✅ Allow text selection
              styleSheet: MarkdownStyleSheet(
                // ✅ Paragraph style
                p: const TextStyle(
                  fontSize: 15,
                  height: 1.8,
                  color: Colors.black87,
                  letterSpacing: 0.3,
                ),
                
                // ✅ Heading styles
                h1: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                  height: 1.5,
                ),
                h2: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  height: 1.5,
                ),
                h3: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                
                // ✅ Bold/Italic
                strong: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                em: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                ),
                
                // ✅ Links
                a: TextStyle(
                  color: Colors.blue.shade700,
                  decoration: TextDecoration.underline,
                ),
                
                // ✅ Lists
                listBullet: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                ),
                
                // ✅ Code block
                code: TextStyle(
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.red.shade700,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                
                // ✅ Blockquote
                blockquote: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border(
                    left: BorderSide(
                      color: Colors.blue.shade300,
                      width: 4,
                    ),
                  ),
                ),
                
                // ✅ Spacing
                h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
                h2Padding: const EdgeInsets.only(top: 14, bottom: 6),
                h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
                pPadding: const EdgeInsets.only(bottom: 12),
                blockquotePadding: const EdgeInsets.all(12),
                codeblockPadding: const EdgeInsets.all(12),
              ),
              
              // ✅ Handle link taps
              onTapLink: (text, href, title) {
                if (href != null) {
                  _launchUrl(href);
                }
              },
            )
          else
            Text(
              'Không có nội dung',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  /// ✅ Launch URL (for markdown links)
  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint('❌ Cannot launch URL: $url');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể mở liên kết: $url'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi mở liên kết: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ Get target score
  double _getTargetScore(LessonCourse? lesson) {
    if (lesson == null) return 50.0;
    return lesson.targetScore;
  }
}