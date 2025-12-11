import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/course.dart';

class CourseUnlockService {
  final _supabase = Supabase.instance.client;

  Future<bool> canUnlockCourse(
    String authUserId,
    String courseId,
    List<Course> allCourses,
  ) async {
    try {
      final userRecord = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', authUserId)
          .maybeSingle();

      if (userRecord == null) return false;

      final dbUserId = userRecord['id'] as String;

      // ✅ Check user_course_locks (trigger đã tự động update)
      final lockData = await _supabase
          .from('user_course_locks')
          .select('is_locked')
          .eq('user_id', dbUserId)
          .eq('course_id', courseId)
          .maybeSingle();

      if (lockData != null) {
        final isLocked = lockData['is_locked'] as bool;
        debugPrint(isLocked 
            ? '🔒 Course locked' 
            : '✅ Course unlocked');
        return !isLocked;
      }

      // ✅ Nếu chưa có record, check recommended course
      final recommendedCourse = await _getRecommendedCourse(dbUserId);
      if (recommendedCourse != null) {
        final currentCourse = allCourses.firstWhere(
          (c) => c.id == courseId,
          orElse: () => Course(id: '', courseName: '', courseOrder: 0),
        );

        final recommendedCourseData = allCourses.firstWhere(
          (c) => c.id == recommendedCourse,
          orElse: () => Course(id: '', courseName: '', courseOrder: 0),
        );

        final canUnlock = courseId == recommendedCourse ||
            currentCourse.courseOrder <= recommendedCourseData.courseOrder;

        if (canUnlock) {
          // Tạo lock record
          await _supabase.from('user_course_locks').insert({
            'user_id': dbUserId,
            'course_id': courseId,
            'is_locked': false,
            'unlocked_at': DateTime.now().toIso8601String(),
          });
        }

        return canUnlock;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking unlock: $e');
      return false;
    }
  }

  /// ✅ Lấy recommended course ID từ placement test
  Future<String?> _getRecommendedCourse(String dbUserId) async {
    try {
      debugPrint('🔍 Getting recommended course for user: $dbUserId');

      final placementData = await _supabase
          .from('user_placement_summary')
          .select('recommended_course_id')
          .eq('user_id', dbUserId)
          .maybeSingle();

      if (placementData == null) {
        debugPrint('❌ No placement data found');
        return null;
      }

      final recommendedId = placementData['recommended_course_id'] as String?;
      debugPrint('✅ Recommended course: $recommendedId');
      return recommendedId;
    } catch (e) {
      debugPrint('❌ Error getting recommended course: $e');
      return null;
    }
  }

  /// ✅ Lấy khóa học trước đó (theo course_order)
  Course? _getPreviousCourse(String courseId, List<Course> allCourses) {
    final currentCourse = allCourses.firstWhere(
      (c) => c.id == courseId,
      orElse: () => Course(id: '', courseName: '', courseOrder: 0),
    );

    if (currentCourse.id.isEmpty || currentCourse.courseOrder <= 1) {
      return null;
    }

    return allCourses.firstWhere(
      (c) => c.courseOrder == currentCourse.courseOrder - 1,
      orElse: () => Course(id: '', courseName: '', courseOrder: 0),
    );
  }

  /// Kiểm tra tất cả course để lấy unlock status
  Future<Map<String, bool>> checkAllCourseUnlockStatus(
    String authUserId,
    List<Course> courses,
  ) async {
    final unlockedStatus = <String, bool>{};

    debugPrint('📋 Checking unlock status for ${courses.length} courses');

    for (var course in courses) {
      final isUnlocked = await canUnlockCourse(
        authUserId,
        course.id,
        courses,
      );
      unlockedStatus[course.id] = isUnlocked;
      debugPrint(
        '  ${course.courseName}: ${isUnlocked ? '✅ UNLOCK' : '🔒 LOCK'}',
      );
    }

    return unlockedStatus;
  }

  /// ✅ Lấy khóa học gần nhất cần unlock (cho snackbar)
  String getNextCourseToUnlock(
    String courseId,
    List<Course> allCourses,
    Map<String, bool> unlockedStatus,
  ) {
    final currentCourse = allCourses.firstWhere(
      (c) => c.id == courseId,
      orElse: () => Course(id: '', courseName: '', courseOrder: 0),
    );

    // Tìm khóa học có order thấp nhất và chưa unlock
    final nextCourse = allCourses
        .where((c) => c.courseOrder < currentCourse.courseOrder)
        .where((c) => unlockedStatus[c.id] == false)
        .fold<Course?>(
          null,
          (prev, curr) =>
              prev == null || curr.courseOrder > prev.courseOrder ? curr : prev,
        );

    if (nextCourse != null) {
      return nextCourse.courseName;
    }

    // Nếu không có khóa học thấp hơn, return khóa học được recommend
    return 'Khóa học được đề xuất';
  }
}