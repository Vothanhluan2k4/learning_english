import 'package:flutter/material.dart';
import 'package:learning_english/models/course.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/course_group.dart';

class CourseService {
  final supabase = Supabase.instance.client;

  // Get group ID from placement test
  Future<String?> getTestGroupId(String authUserId) async {
    try {
      final userRecord = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', authUserId)
          .maybeSingle();

      if (userRecord == null) return null;

      final userId = userRecord['id'];
      final data = await supabase
          .from('user_placement_summary')
          .select('''
            placement_test_id,
            tests:placement_test_id (
              course_group_id
            )
          ''')
          .eq('user_id', userId)
          .single();

      return data['tests']?['course_group_id'];
    } catch (e) {
      debugPrint('Error getting test group: $e');
      return null;
    }
  }

  // ✅ SỬA: Trả về List<Course> thay vì List<Map>
  Future<List<Course>> fetchCoursesByGroup(String groupId) async {
    try {
      final response = await supabase
          .from('courses')
          .select('''
            id,
            course_name,
            course_order,
            group_id,
            required_course_id
          ''')
          .eq('group_id', groupId)
          .order('course_order');

      return (response as List)
          .map((e) => Course.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching courses by group: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchCourses() async {
    try {
      final response = await supabase
          .from('courses')
          .select('''
            id,
            course_name,
            course_order,
            required_course_id,
            course_groups:group_id (
              id,
              group_name
            )
          ''')
          .order('course_order');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching courses: $e');
      return [];
    }
  }

  // ✅ SỬA: Trả về Course thay vì Map
  Future<Course?> fetchRecommendedCourse(String authUserId) async {
    try {
      final userRecord = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', authUserId)
          .maybeSingle();

      if (userRecord == null) return null;

      final userId = userRecord['id'];
      final placementData = await supabase
          .from('user_placement_summary')
          .select('''
            score,
            courses:recommended_course_id (
              id,
              course_name,
              course_order,
              group_id,
              required_course_id
            )
          ''')
          .eq('user_id', userId)
          .maybeSingle();

      if (placementData == null || placementData['courses'] == null) {
        return null;
      }

      return Course.fromJson(placementData['courses'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error fetching recommended course: $e');
      return null;
    }
  }

  Future<String?> getRecommendedGroupId(String userId) async {
    try {
      final placementData = await supabase
          .from('user_placement_summary')
          .select('''
            courses:recommended_course_id (
              group_id
            )
          ''')
          .eq('user_id', userId)
          .single();

      return placementData['courses']?['group_id'];
    } catch (e) {
      debugPrint('Error fetching recommended group: $e');
      return null;
    }
  }

  Future<bool> hasCompletedCourse(String authUserId, String courseId) async {
    try {
      final userRecord = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', authUserId)
          .maybeSingle();

      if (userRecord == null) return false;

      final userId = userRecord['id'];

      // ✅ SỬA: Lấy test_id của khóa học trước
      final testData = await supabase
          .from('tests')
          .select('id')
          .eq('course_id', courseId)
          .eq('test_type', 'final_test')
          .maybeSingle();

      if (testData == null) return false;

      final testId = testData['id'];

      final result = await supabase
          .from('user_test_results')
          .select('status, score')
          .eq('user_id', userId)
          .eq('test_id', testId)
          .maybeSingle();

      if (result == null) return false;

      return result['status'] == 'completed' &&
          (result['score'] as num? ?? 0) >= 70;
    } catch (e) {
      debugPrint('Error checking completed course: $e');
      return false;
    }
  }

  // ✅ SỬA: Trả về CourseGroup thay vì Map
  Future<CourseGroup?> fetchGroupDetails(String groupId) async {
    try {
      final response = await supabase
          .from('course_groups')
          .select('id, group_name, description')
          .eq('id', groupId)
          .single();

      return CourseGroup(
        id: response['id'],
        groupName: response['group_name'],
        description: response['description'],
        courses: [],
      );
    } catch (e) {
      debugPrint('Error fetching group details: $e');
      return null;
    }
  }

  // Lấy thông tin course theo ID
  Future<Course?> getCourseById(String courseId) async {
    try {
      debugPrint('📋 Fetching course: $courseId');

      final data = await supabase
          .from('courses')
          .select('*')
          .eq('id', courseId)
          .maybeSingle();

      if (data == null) {
        debugPrint('❌ Course not found');
        return null;
      }

      final course = Course.fromJson(data as Map<String, dynamic>);
      debugPrint('✅ Course loaded: ${course.courseName}');
      return course;
    } catch (e) {
      debugPrint('❌ Error fetching course: $e');
      return null;
    }
  }

  Future<Course?> getPrerequisiteCourse(String courseId) async {
    try {
      final course = await getCourseById(courseId);
      return course;
    } catch (e) {
      debugPrint('❌ Error getting prerequisite: $e');
      return null;
    }
  }
}