import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../service/course_service.dart';
import '../../../service/placement_test_service.dart';
import '../../../models/course_group.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final _courseService = CourseService();
  final _placementService = PlacementTestService();
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  bool _showPlacement = false;
  List<Map<String, dynamic>> _courses = [];
  Map<String, dynamic>? _recommendedCourse;
  String _groupName = 'Lộ trình học';
  String? _currentGroupId;
  Map<String, bool> _completedCourses = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      setState(() => _isLoading = true);
      final authUserId = _supabase.auth.currentUser!.id;
      
      final shouldShowTest = await _placementService.shouldShowPlacementTest(authUserId);
      
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

      final groupDetails = results[0] as Map<String, dynamic>?;
      final recommendedCourse = results[1] as Map<String, dynamic>?;
      final courses = List<Map<String, dynamic>>.from(results[2] as List);

      for (var course in courses) {
        if (course['required_course_id'] != null) {
          _completedCourses[course['required_course_id']] = 
              await _courseService.hasCompletedCourse(authUserId, course['required_course_id']);
        }
      }

      setState(() {
        _currentGroupId = groupId;
        _groupName = groupDetails?['group_name'] ?? 'Lộ trình học';
        _recommendedCourse = recommendedCourse;
        _courses = courses;
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
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_groupName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            )),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Hiển thị notification banner thay vì dialog
          if (_showPlacement)
            _buildPlacementNotificationBanner(),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (!_showPlacement) ...[
                    _buildRecommendedCourseCard(),
                    _buildCourseList(),
                  ] else
                    SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacementNotificationBanner() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange.shade700,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bạn cần làm bài kiểm tra đầu vào',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Bạn cần hoàn thành bài kiểm tra đầu vào để xác định trình độ và lộ trình học phù hợp nhất.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange.shade800,
              height: 1.5,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/chooseCourse');
              },
              icon: Icon(Icons.arrow_forward),
              label: Text('Làm bài kiểm tra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedCourseCard() {
    if (_recommendedCourse == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[100]!, Colors.blue[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.recommend, color: Colors.blue[700]),
              SizedBox(width: 8),
              Text(
                'Khóa học phù hợp với bạn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            _recommendedCourse!['course_name'],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/courseDetail',
                arguments: {'courseId': _recommendedCourse!['id']},
              );
            },
            icon: Icon(Icons.arrow_forward),
            label: Text('Xem chi tiết'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        final isRecommended = _recommendedCourse != null && 
            course['id'] == _recommendedCourse!['id'];

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isRecommended
                ? BorderSide(color: Colors.blue, width: 2)
                : BorderSide.none,
          ),
          elevation: isRecommended ? 4 : 2,
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/courseDetail',
                arguments: {'courseId': course['id']},
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          course['course_name'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isRecommended)
                        Chip(
                          label: Text('Đề xuất'),
                          backgroundColor: Colors.blue[50],
                          labelStyle: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}