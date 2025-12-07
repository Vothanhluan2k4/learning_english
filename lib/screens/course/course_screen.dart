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
        setState(() {
          _isLoading = false;
          _showPlacement = true;
        });
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

      final unlockedStatus = await _courseUnlockService.checkAllCourseUnlockStatus(
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

  // ✅ NEW: Refresh handler
  Future<void> _handleRefresh() async {
    debugPrint('🔄 Refreshing courses...');
    await _initData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Đã cập nhật dữ liệu'),
            ],
          ),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF2196F3),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Đang tải khóa học...',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF757575),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ WRAP CustomScrollView with RefreshIndicator
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Color(0xFF2196F3),
        backgroundColor: Colors.white,
        strokeWidth: 3,
        displacement: 40,
        child: CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(), // ✅ Enable pull-to-refresh even when content is short
          slivers: [
            // 🔥 MODERN APP BAR with gradient
            SliverAppBar(
              pinned: true,
              floating: false,
              elevation: 0,
              backgroundColor: Colors.white,
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: Text(
                _groupName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 26, color: Colors.blue),
                  onPressed: () {
                    _showCourseInfo(context);
                  },
                  tooltip: 'Thông tin',
                ),
              ],
            ),

            // 🔥 PLACEMENT BANNER (if needed)
            if (_showPlacement)
              SliverToBoxAdapter(
                child: PlacementBannerWidget(
                  onTakePlacementTest: () {
                    Navigator.pushNamed(context, '/chooseCourse');
                  },
                ),
              ),

            // 🔥 RECOMMENDED COURSE SECTION
            if (!_showPlacement && _recommendedCourse != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: Color(0xFFFF9800), size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Khóa học phù hợp với bạn',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _buildRecommendedCard(_recommendedCourse!),
                    ],
                  ),
                ),
              ),

            // 🔥 ALL COURSES SECTION
            if (!_showPlacement)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.school_outlined, color: Color(0xFF2196F3), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Tất cả khóa học',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 🔥 COURSES LIST
            if (!_showPlacement)
              SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final course = _courses[index];
                      final isRecommended = _recommendedCourse != null && 
                                           course.id == _recommendedCourse!.id;
                      final isUnlocked = _unlockedCourses[course.id] ?? false;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: _buildCourseCard(course, isRecommended, isUnlocked),
                      );
                    },
                    childCount: _courses.length,
                  ),
                ),
              ),

            // 🔥 BOTTOM SPACING
            SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 RECOMMENDED COURSE CARD (Enhanced)
  Widget _buildRecommendedCard(Course course) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/courseModules',
          arguments: {'courseId': course.id},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFBBDEFB),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Color(0xFF2196F3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF2196F3).withOpacity(0.25),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with badge
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF2196F3).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF1976D2),
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'ĐỀ XUẤT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          course.courseName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFF2196F3),
                    size: 20,
                  ),
                ],
              ),
            ),

            // Divider
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0xFF2196F3).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Description
            Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, 
                       color: Color(0xFF4CAF50), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bắt đầu học ngay để nâng cao kỹ năng của bạn!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF424242),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 COURSE CARD (Enhanced)
  Widget _buildCourseCard(Course course, bool isRecommended, bool isUnlocked) {
    return GestureDetector(
      onTap: isUnlocked
          ? () {
              Navigator.pushNamed(
                context,
                '/courseModules',
                arguments: {'courseId': course.id},
              );
            }
          : () {
              _showLockedSnackbar(context, course);
            },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isRecommended
              ? Border.all(color: Color(0xFF2196F3), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // Course icon/avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: isUnlocked
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                            )
                          : LinearGradient(
                              colors: [Color(0xFFBDBDBD), Color(0xFF9E9E9E)],
                            ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isUnlocked 
                              ? Color(0xFF2196F3) 
                              : Color(0xFF9E9E9E)).withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        course.courseName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Course info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Course name
                        Text(
                          course.courseName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked 
                                ? Color(0xFF1A1A1A) 
                                : Color(0xFF9E9E9E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),

                        // Lock status or info
                        if (!isUnlocked)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 14, color: Color(0xFFEF5350)),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Hoàn thành bên dưới để mở khóa',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFD32F2F),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            children: [
                              Icon(Icons.play_circle_outline, 
                                   size: 16, color: Color(0xFF4CAF50)),
                              SizedBox(width: 6),
                              Text(
                                'Sẵn sàng học',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Arrow icon
                  Icon(
                    Icons.arrow_forward_ios,
                    color: isUnlocked ? Color(0xFF2196F3) : Color(0xFFBDBDBD),
                    size: 18,
                  ),
                ],
              ),
            ),

            // Lock overlay
            if (!isUnlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.lock,
                      color: Color(0xFFEF5350),
                      size: 32,
                    ),
                  ),
                ),
              ),

            // Recommended badge
            if (isRecommended && isUnlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF4CAF50).withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'ĐỀ XUẤT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🔥 MODERN SNACKBAR
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
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.lock, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Khóa học bị khóa',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Hoàn thành bên dưới để mở khóa',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFFEF5350),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
      ),
    );
  }

  // 🔥 COURSE INFO DIALOG
  void _showCourseInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF2196F3)),
              SizedBox(width: 12),
              Text(
                'Về lộ trình học',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(
            color: Colors.grey,
            thickness: 1,
          ), // 👈 Gạch ngang ngăn cách title và content
        ],
      ),
        
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.school, 'Học theo trình tự từ dễ đến khó'),
            SizedBox(height: 12),
            _buildInfoRow(Icons.lock_open, 'Hoàn thành khóa trước để mở khóa sau'),
            SizedBox(height: 12),
            _buildInfoRow(Icons.star, 'Khóa đề xuất phù hợp với trình độ của bạn'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Color(0xFF2196F3)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}