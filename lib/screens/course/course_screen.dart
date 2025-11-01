import 'package:flutter/material.dart';
import 'package:learning_english/models/course.dart';
import 'package:learning_english/models/course_group.dart';
import 'package:learning_english/services/course_unlock_service.dart';
import 'package:learning_english/widgets/courses/course_card_widget.dart';
import 'package:learning_english/widgets/courses/placement_banner_widget.dart';
import 'package:learning_english/widgets/courses/recommended_course_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/course_service.dart';
import '../../services/placement_test_service.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final _courseService = CourseService();
  final _courseUnlockService = CourseUnlockService();
  final _placementService = PlacementTestService();
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _showPlacement = false;
  List<Course> _courses = [];
  Course? _recommendedCourse;
  String _groupName = 'Lộ trình học';
  String? _currentGroupId;

  // ✅ Maps để track unlock status
  Map<String, bool> _unlockedCourses = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      setState(() => _isLoading = true);
      final authUserId = _supabase.auth.currentUser!.id;

      final shouldShowTest =
          await _placementService.shouldShowPlacementTest(authUserId);

      if (shouldShowTest) {
        setState(() {
          _showPlacement = true;
          _isLoading = false;
        });
        return;
      }

      final groupId = await _courseService.getTestGroupId(authUserId);
      if (groupId == null) {
        debugPrint('❌ No group ID found');
        setState(() => _isLoading = false);
        setState(() => _showPlacement = true);
        return;
      }

      final results = await Future.wait([
        _courseService.fetchGroupDetails(groupId),
        _courseService.fetchRecommendedCourse(authUserId),
        _courseService.fetchCoursesByGroup(groupId),
      ]);

      final groupDetails = results[0] as CourseGroup?;
      final recommendedCourse = results[1] as Course?;
      final courses = results[2] as List<Course>;

      // ✅ Kiểm tra unlock status cho tất cả khóa học
      final unlockedStatus =
          await _courseUnlockService.checkAllCourseUnlockStatus(
        authUserId,
        courses,
      );

      setState(() {
        _currentGroupId = groupId;
        _groupName = groupDetails?.groupName ?? 'Lộ trình học';
        _recommendedCourse = recommendedCourse;
        _courses = courses;
        _unlockedCourses = unlockedStatus;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _groupName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          if (_showPlacement)
            PlacementBannerWidget(
              onTakePlacementTest: () {
                Navigator.pushNamed(context, '/chooseCourse');
              },
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (!_showPlacement) ...[
                    RecommendedCourseCard(
                      recommendedCourse: _recommendedCourse,
                      onTap: () {
                        // ✅ Sử dụng pushNamed với courseId
                        Navigator.pushNamed(
                          context,
                          '/courseModules',
                          arguments: {'courseId': _recommendedCourse!.id},
                        );
                      },
                    ),
                    _buildCourseList(),
                  ] else
                    const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        final isRecommended =
            _recommendedCourse != null && course.id == _recommendedCourse!.id;

        // ✅ Lấy unlock status
        final isUnlocked = _unlockedCourses[course.id] ?? false;

        return CourseCardWidget(
          course: course,
          isRecommended: isRecommended,
          isUnlocked: isUnlocked,
          // ✅ Lấy tên khóa học cần hoàn thành
          prerequisiteName:
              _courseUnlockService.getNextCourseToUnlock(
                course.id,
                _courses,
                _unlockedCourses,
              ),
          onTap: isUnlocked
              ? () {
                  // ✅ Sử dụng pushNamed với courseId
                  Navigator.pushNamed(
                    context,
                    '/courseModules',
                    arguments: {'courseId': course.id},
                  );
                }
              : () {
                  // ✅ Hiển thị snackbar
                  _showLockedSnackbar(context, course);
                },
        );
      },
    );
  }

  // ✅ Hiển thị snackbar khi khóa học bị khóa
  void _showLockedSnackbar(BuildContext context, Course course) {
    final nextCourse = _courseUnlockService.getNextCourseToUnlock(
      course.id,
      _courses,
      _unlockedCourses,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.lock, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hoàn thành "$nextCourse" để mở khóa',
                style: const TextStyle(color: Colors.white),
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
  }
}