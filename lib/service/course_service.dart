import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course_group.dart';

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

    if (userRecord == null) return null; // Không tìm thấy user → coi như chưa test

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

  // Fetch courses by group ID
  Future<List<Map<String, dynamic>>> fetchCoursesByGroup(String groupId) async {
    try {
      final response = await supabase
          .from('courses')
          .select('''
            id,
            course_name,
            course_order,
            required_course_id,
            required_course:required_course_id (
              id,
              course_name
            )
          ''')
          .eq('group_id', groupId)
          .order('course_order');
      
      return List<Map<String, dynamic>>.from(response);
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

  Future<Map<String, dynamic>?> fetchRecommendedCourse(String authUserId) async {
    try {

      final userRecord = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', authUserId)
      .maybeSingle();

    if (userRecord == null) return null; // Không tìm thấy user → coi như chưa test

    final userId = userRecord['id'];
      final placementData = await supabase
          .from('user_placement_summary')
          .select('''
            score,
            courses:recommended_course_id (
              id,
              course_name,
              course_order,
              course_groups:group_id (
                id,
                group_name
              )
            )
          ''')
          .eq('user_id', userId)
          .maybeSingle();
      
      return placementData?['courses'];
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

    if (userRecord == null) return true; // Không tìm thấy user → coi như chưa test

    final userId = userRecord['id'];
      final result = await supabase
          .from('user_test_results')
          .select('status, score')
          .eq('user_id', userId)
          .eq('test_id', (
            supabase
              .from('tests')
              .select('id')
              .eq('course_id', courseId)
              .eq('test_type', 'final')
              .single()
          ))
          .single();
      
      return result['status'] == 'completed' && (result['score'] ?? 0) >= 70;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchGroupDetails(String groupId) async {
    try {
      final response = await supabase
          .from('course_groups')
          .select('id, group_name, description')
          .eq('id', groupId)
          .single();
      
      return response;
    } catch (e) {
      debugPrint('Error fetching group details: $e');
      return null;
    }
  }
}