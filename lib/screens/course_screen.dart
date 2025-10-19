import 'package:flutter/material.dart';

// Models
class CourseGroup {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final List<Course> courses;

  CourseGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.courses,
  });
}

class Course {
  final String id;
  final String name;
  final String description;
  final int level;
  final bool isUnlocked;
  final int progress; // 0-100
  final List<Lesson> lessons;

  Course({
    required this.id,
    required this.name,
    required this.description,
    required this.level,
    required this.isUnlocked,
    this.progress = 0,
    required this.lessons,
  });
}

class Lesson {
  final String id;
  final String title;
  final LessonType type;
  final bool isCompleted;
  final int duration; // minutes

  Lesson({
    required this.id,
    required this.title,
    required this.type,
    this.isCompleted = false,
    required this.duration,
  });
}

enum LessonType { theory, exercise }

// Mock Data
class MockData {
  static List<CourseGroup> getCourseGroups() {
    return [
      CourseGroup(
        id: 'basic',
        name: 'Học Cơ Bản',
        description: 'Nền tảng tiếng Anh từ A2 đến C1',
        icon: Icons.school,
        gradientColors: [Color(0xFF4E54C8), Color(0xFF8F94FB)],
        courses: [
          Course(
            id: 'a2',
            name: 'A2 Elementary',
            description: 'Trình độ sơ cấp',
            level: 1,
            isUnlocked: true,
            progress: 80,
            lessons: [
              Lesson(id: '1', title: 'Present Simple', type: LessonType.theory, isCompleted: true, duration: 30),
              Lesson(id: '2', title: 'Bài tập Present Simple', type: LessonType.exercise, isCompleted: true, duration: 20),
              Lesson(id: '3', title: 'Present Continuous', type: LessonType.theory, isCompleted: false, duration: 30),
              Lesson(id: '4', title: 'Bài tập Present Continuous', type: LessonType.exercise, isCompleted: false, duration: 20),
            ],
          ),
          Course(
            id: 'b1',
            name: 'B1 Intermediate',
            description: 'Trình độ trung cấp',
            level: 2,
            isUnlocked: true,
            progress: 30,
            lessons: [
              Lesson(id: '1', title: 'Past Simple', type: LessonType.theory, isCompleted: true, duration: 30),
              Lesson(id: '2', title: 'Bài tập Past Simple', type: LessonType.exercise, isCompleted: false, duration: 20),
            ],
          ),
          Course(
            id: 'b2',
            name: 'B2 Upper Intermediate',
            description: 'Trình độ trung cấp cao',
            level: 3,
            isUnlocked: false,
            lessons: [
              Lesson(id: '1', title: 'Present Perfect', type: LessonType.theory, duration: 30),
              Lesson(id: '2', title: 'Bài tập Present Perfect', type: LessonType.exercise, duration: 20),
            ],
          ),
          Course(
            id: 'c1',
            name: 'C1 Advanced',
            description: 'Trình độ nâng cao',
            level: 4,
            isUnlocked: false,
            lessons: [
              Lesson(id: '1', title: 'Conditional Sentences', type: LessonType.theory, duration: 40),
              Lesson(id: '2', title: 'Bài tập Conditional', type: LessonType.exercise, duration: 30),
            ],
          ),
        ],
      ),
      CourseGroup(
        id: 'toeic',
        name: 'Luyện Đề',
        description: 'Luyện thi TOEIC chuyên sâu',
        icon: Icons.quiz,
        gradientColors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
        courses: [
          Course(
            id: 'toeic_foundation',
            name: 'TOEIC Foundation',
            description: 'Nền tảng TOEIC 400-600',
            level: 1,
            isUnlocked: true,
            progress: 50,
            lessons: [
              Lesson(id: '1', title: 'Listening Part 1', type: LessonType.theory, isCompleted: true, duration: 40),
              Lesson(id: '2', title: 'Bài tập Part 1', type: LessonType.exercise, isCompleted: true, duration: 30),
              Lesson(id: '3', title: 'Reading Part 5', type: LessonType.theory, isCompleted: false, duration: 40),
            ],
          ),
          Course(
            id: 'toeic_intensive',
            name: 'TOEIC Intensive',
            description: 'Luyện thi TOEIC 600-850',
            level: 2,
            isUnlocked: false,
            lessons: [
              Lesson(id: '1', title: 'Full Test 1', type: LessonType.exercise, duration: 120),
              Lesson(id: '2', title: 'Full Test 2', type: LessonType.exercise, duration: 120),
            ],
          ),
        ],
      ),
    ];
  }
}

// Main Screen
class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> with SingleTickerProviderStateMixin {
  final List<CourseGroup> courseGroups = MockData.getCourseGroups();
  CourseGroup? selectedGroup;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectGroup(CourseGroup group) {
    setState(() {
      selectedGroup = group;
    });
    _animationController.forward(from: 0.0);
  }

  void _goBack() {
    setState(() {
      selectedGroup = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(

        backgroundColor: Colors.white,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: selectedGroup != null
            ? IconButton(
          icon: Icon(Icons.arrow_back , color: Colors.black,),
          onPressed: _goBack,
        )
            : null,
      ),
      body: selectedGroup == null
          ? _buildGroupSelection()
          : _buildCourseList(),
    );
  }

  Widget _buildGroupSelection() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: courseGroups.length,
      itemBuilder: (context, index) {
        final group = courseGroups[index];
        return _buildGroupCard(group, index);
      },
    );
  }

  Widget _buildGroupCard(CourseGroup group, int index) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: group.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: group.gradientColors[0].withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _selectGroup(group),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(group.icon, size: 40, color: Colors.white),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          group.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${group.courses.length} khóa học',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: selectedGroup!.courses.length,
        itemBuilder: (context, index) {
          final course = selectedGroup!.courses[index];
          return _buildCourseCard(course, index);
        },
      ),
    );
  }

  Widget _buildCourseCard(Course course, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: course.isUnlocked
              ? () => _navigateToCourseDetail(course)
              : () => _showLockedDialog(),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Level Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: course.isUnlocked
                              ? selectedGroup!.gradientColors
                              : [Colors.grey[400]!, Colors.grey[500]!],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Level ${course.level}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Spacer(),
                    // Lock Icon
                    if (!course.isUnlocked)
                      Icon(Icons.lock, color: Colors.grey[400], size: 20),
                  ],
                ),
                SizedBox(height: 12),

                Text(
                  course.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: course.isUnlocked ? Colors.black87 : Colors.grey[400],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  course.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),

                if (course.isUnlocked) ...[
                  SizedBox(height: 16),
                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tiến độ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${course.progress}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: selectedGroup!.gradientColors[0],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: course.progress / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            selectedGroup!.gradientColors[0],
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),
                  // Lesson Count
                  Row(
                    children: [
                      Icon(Icons.book_outlined, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        '${course.lessons.length} bài học',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(width: 16),
                      Icon(Icons.check_circle_outline, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        '${course.lessons.where((l) => l.isCompleted).length}/${course.lessons.length} hoàn thành',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToCourseDetail(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseDetailScreen(
          course: course,
          gradientColors: selectedGroup!.gradientColors,
        ),
      ),
    );
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Khóa học bị khóa'),
          ],
        ),
        content: Text('Bạn cần hoàn thành khóa học trước đó để mở khóa này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

// Course Detail Screen
class CourseDetailScreen extends StatelessWidget {
  final Course course;
  final List<Color> gradientColors;

  const CourseDetailScreen({
    Key? key,
    required this.course,
    required this.gradientColors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                course.name,
                style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white.withOpacity(0.9)),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(Icons.school, size: 80, color: Colors.white.withOpacity(0.8)),
                ),
              ),
            ),
            backgroundColor: gradientColors[0],
            foregroundColor: Colors.white,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Danh sách bài học',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final lesson = course.lessons[index];
                return _buildLessonCard(context, lesson, index);
              },
              childCount: course.lessons.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(BuildContext context, Lesson lesson, int index) {
    final isTheory = lesson.type == LessonType.theory;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isTheory
                ? Colors.blue.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isTheory ? Icons.menu_book : Icons.quiz,
            color: isTheory ? Colors.blue : Colors.orange,
          ),
        ),
        title: Text(
          lesson.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
            SizedBox(width: 4),
            Text('${lesson.duration} phút'),
          ],
        ),
        trailing: lesson.isCompleted
            ? Icon(Icons.check_circle, color: Colors.green)
            : Icon(Icons.play_circle_outline, color: gradientColors[0]),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bắt đầu bài: ${lesson.title}')),
          );
        },
      ),
    );
  }
}