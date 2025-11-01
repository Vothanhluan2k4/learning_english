import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course.dart';

class CourseUnlockService {
  final _supabase = Supabase.instance.client;

  /// ✅ Kiểm tra khóa học có thể mở được không
  /// Logic:
  /// - Khóa học được đạt từ test → UNLOCK
  /// - Khóa học có order < recommended course → UNLOCK
  /// - Khóa học đã hoàn thành trong user_progress_course → UNLOCK
  /// - Khóa khác → LOCK
  Future<bool> canUnlockCourse(
    String authUserId,
    String courseId,
    List<Course> allCourses,
  ) async {
    try {
      // Lấy user DB ID
      final userRecord = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', authUserId)
          .maybeSingle();

      if (userRecord == null) {
        debugPrint('❌ User not found');
        return false;
      }

      final dbUserId = userRecord['id'] as String;

      // ✅ 1. Kiểm tra khóa học được recommend từ placement test
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

        // ✅ Unlock nếu:
        // - Là khóa học được đề xuất
        // - Hoặc có courseOrder < khóa học được đề xuất
        if (courseId == recommendedCourse ||
            currentCourse.courseOrder <= recommendedCourseData.courseOrder) {
          debugPrint(
            '✅ Course $courseId unlocked (recommended or lower order)',
          );
          return true;
        }
      }

      // ✅ 2. Kiểm tra xem khóa học đã hoàn thành trong user_progress_course
      final progressData = await _supabase
          .from('user_progress_course')
          .select('is_completed')
          .eq('user_id', dbUserId)
          .eq('course_id', courseId)
          .maybeSingle();

      if (progressData != null && progressData['is_completed'] == true) {
        debugPrint('✅ Course $courseId unlocked (already completed)');
        return true;
      }

      debugPrint('🔒 Course $courseId locked');
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

  /// ✅ Kiểm tra tất cả course để lấy unlock status
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