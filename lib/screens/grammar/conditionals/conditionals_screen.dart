import 'package:flutter/material.dart';
import 'package:learning_english/models/lesson.dart';
import 'package:learning_english/services/grammar/grammar_service.dart';
import '../conditionals/conditionals_detail_screen.dart';

class ConditionalsScreen extends StatefulWidget {
  const ConditionalsScreen({super.key});

  @override
  State<ConditionalsScreen> createState() => _ConditionalsScreenState();
}

class _ConditionalsScreenState extends State<ConditionalsScreen> with TickerProviderStateMixin {
  final GrammarService _grammarService = GrammarService();
  List<Lesson> lessons = [];
  bool isLoading = true;
  String? errorMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadLessons();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLessons() async {
    try {
      if (!mounted) return;
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final result = await _grammarService.getLessonsByTopicName('Conditionals');
      if (mounted) {
        setState(() {
          lessons = result;
          isLoading = false;
        });
        if (lessons.isNotEmpty) {
          _animationController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Không thể tải được danh sách bài học. Vui lòng kiểm tra kết nối mạng và thử lại.";
        });
      }
    }
  }

  Map<String, List<Lesson>> _groupLessons(List<Lesson> lessons) {
    Map<String, List<Lesson>> grouped = {
      'Câu điều kiện loại 0 và 1': [],
      'Câu điều kiện loại 2 và 3': [],
      'Trường hợp đặc biệt': [],
      'Khác': [],
    };

    for (var lesson in lessons) {
      final title = lesson.lessonTitleVi.toLowerCase();
      if (title.contains('loại 0') || title.contains('loại 1') || title.contains('type 0') || title.contains('type 1')) {
        grouped['Câu điều kiện loại 0 và 1']!.add(lesson);
      } else if (title.contains('loại 2') || title.contains('loại 3') || title.contains('type 2') || title.contains('type 3')) {
        grouped['Câu điều kiện loại 2 và 3']!.add(lesson);
      } else if (title.contains('đặc biệt') || title.contains('mixed') || title.contains('inversion')) {
        grouped['Trường hợp đặc biệt']!.add(lesson);
      } else {
        grouped['Khác']!.add(lesson);
      }
    }

    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  IconData _getGroupIcon(String groupName) {
    switch (groupName) {
      case 'Câu điều kiện loại 0 và 1':
        return Icons.filter_1;
      case 'Câu điều kiện loại 2 và 3':
        return Icons.filter_2;
      case 'Trường hợp đặc biệt':
        return Icons.star_border;
      default:
        return Icons.more_horiz;
    }
  }

  Color _getGroupColor(String groupName) {
    switch (groupName) {
      case 'Câu điều kiện loại 0 và 1':
        return Colors.purple[400]!;
      case 'Câu điều kiện loại 2 và 3':
        return Colors.purple[600]!;
      case 'Trường hợp đặc biệt':
        return Colors.purple[800]!;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Câu điều kiện",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[700]!),
            ),
            const SizedBox(height: 20),
            const Text(
              'Đang tải bài học...',
              style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, color: Colors.purple[400], size: 60),
              ),
              const SizedBox(height: 24),
              const Text(
                "Đã xảy ra lỗi",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _loadLessons,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Thử lại", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                  shadowColor: Colors.purple.withOpacity(0.4),
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
            Icon(Icons.school_outlined, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              "Chưa có bài học nào",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF555555)),
            ),
            const SizedBox(height: 8),
            Text(
              "Nội dung sẽ sớm được cập nhật. Vui lòng quay lại sau!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final grouped = _groupLessons(lessons);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: grouped.entries.map((entry) {
            final groupColor = _getGroupColor(entry.key);
            final groupIcon = _getGroupIcon(entry.key);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: groupColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          groupIcon,
                          color: groupColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: groupColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${entry.value.length} bài',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: groupColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...entry.value.asMap().entries.map((lessonEntry) {
                  final index = lessonEntry.key;
                  final lesson = lessonEntry.value;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
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
                              builder: (_) => ConditionalsDetailScreen(
                                lessonId: lesson.id,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(15),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        groupColor.withOpacity(0.7),
                                        groupColor,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: groupColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(2, 2),
                                      )
                                    ]),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lesson.lessonTitleVi,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF333333),
                                        height: 1.4,
                                      ),
                                    ),
                                    if (lesson.lessonTitleEn != null &&
                                        lesson.lessonTitleEn!.isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        lesson.lessonTitleEn!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[500],
                                          fontStyle: FontStyle.italic,
                                          height: 1.3,
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey.shade300,
                                size: 16,
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
