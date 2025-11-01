import 'package:flutter/material.dart';
import 'package:learning_english/models/lesson.dart';
import 'package:learning_english/services/grammar_service.dart';
import '../tenses/lesson_detail_screen.dart';

class TensesScreen extends StatefulWidget {
  const TensesScreen({super.key});

  @override
  State<TensesScreen> createState() => _TensesScreenState();
}

class _TensesScreenState extends State<TensesScreen> {
  final GrammarService _grammarService = GrammarService();
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

      final result = await _grammarService.getLessonsByTopicName('Tenses');
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

  Map<String, List<Lesson>> _groupLessons(List<Lesson> lessons) {
    Map<String, List<Lesson>> grouped = {
      'Thì hiện tại': [],
      'Thì quá khứ': [],
      'Thì tương lai': [],
      'Khác': [],
    };

    for (var lesson in lessons) {
      final title = lesson.lessonTitleVi.toLowerCase();
      if (title.contains('hiện tại')) {
        grouped['Thì hiện tại']!.add(lesson);
      } else if (title.contains('quá khứ')) {
        grouped['Thì quá khứ']!.add(lesson);
      } else if (title.contains('tương lai')) {
        grouped['Thì tương lai']!.add(lesson);
      } else {
        grouped['Khác']!.add(lesson);
      }
    }

    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  // Icon cho từng nhóm thì
  IconData _getGroupIcon(String groupName) {
    switch (groupName) {
      case 'Thì hiện tại':
        return Icons.schedule;
      case 'Thì quá khứ':
        return Icons.history;
      case 'Thì tương lai':
        return Icons.trending_up;
      default:
        return Icons.more_horiz;
    }
  }

  // Màu cho từng nhóm thì
  Color _getGroupColor(String groupName) {
    switch (groupName) {
      case 'Thì hiện tại':
        return Colors.blue;
      case 'Thì quá khứ':
        return Colors.orange;
      case 'Thì tương lai':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Tenses",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 16),
            Text(
              'Đang tải bài học...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red[400],
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Không thể tải bài học",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage ?? "Đã có lỗi xảy ra",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadLessons,
                icon: const Icon(Icons.refresh),
                label: const Text("Thử lại"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (lessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 60,
                color: Colors.blue[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Chưa có bài học nào",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Hiện tại chưa có bài học cho chủ đề này",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final grouped = _groupLessons(lessons);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: grouped.entries.map((entry) {
        final groupColor = _getGroupColor(entry.key);
        final groupIcon = _getGroupIcon(entry.key);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header của nhóm
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: groupColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      groupIcon,
                      color: groupColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: groupColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: groupColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${entry.value.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: groupColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Danh sách bài học
            ...entry.value.asMap().entries.map((lessonEntry) {
              final index = lessonEntry.key;
              final lesson = lessonEntry.value;
              final isLast = index == entry.value.length - 1;

              return Container(
                margin: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  isLast ? 0 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonDetailScreen(
                            lessonId: lesson.id,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Số thứ tự
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  groupColor.withOpacity(0.8),
                                  groupColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Nội dung
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lesson.lessonTitleVi,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF212121),
                                    height: 1.3,
                                  ),
                                ),
                                if (lesson.lessonTitleEn != null &&
                                    lesson.lessonTitleEn!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    lesson.lessonTitleEn!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Icon mũi tên
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: groupColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: groupColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (!grouped.entries.last.key.contains(entry.key))
              const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}