import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course_module.dart';

class CourseModuleService {
  final _supabase = Supabase.instance.client;

  /// ✅ Helper: Get user_id từ auth.uid()
  Future<String?> _getUserId() async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) return null;

      final response = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', authUserId)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e) {
      debugPrint('❌ Error getting user_id: $e');
      return null;
    }
  }

  /// ✅ Unlock course manually
  Future<void> unlockCourseForUser(String courseId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        debugPrint('❌ Cannot unlock course: user not found');
        return;
      }

      debugPrint('🔓 Unlocking course $courseId for user $userId');

      await _supabase.rpc(
        'unlock_course_for_user',
        params: {
          'p_user_id': userId,
          'p_course_id': courseId,
        },
      );

      debugPrint('✅ Course unlocked successfully');
    } catch (e) {
      debugPrint('❌ Error unlocking course: $e');
    }
  }

  /// ✅ Lấy modules với lock status (dùng RPC)
  Future<List<CourseModule>> fetchModulesByCourse(String courseId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        debugPrint('❌ No user logged in');
        return [];
      }

      debugPrint('📚 Fetching modules for course: $courseId, user: $userId');

      // ✅ Check course lock status
      final isCourseLocked = await _supabase.rpc(
        'is_course_locked',
        params: {
          'p_user_id': userId,
          'p_course_id': courseId,
        },
      ) as bool? ?? true;

      debugPrint('🔒 Course locked: $isCourseLocked');

      // ✅ Auto unlock nếu course bị khóa
      if (isCourseLocked) {
        debugPrint('⚠️ Course is locked! Auto unlocking...');
        await unlockCourseForUser(courseId);
        
        // Wait a bit for unlock to complete
        await Future.delayed(Duration(milliseconds: 500));
      }

      final response = await _supabase.rpc(
        'get_modules_with_lock_status',
        params: {
          'p_user_id': userId,
          'p_course_id': courseId,
        },
      );

      debugPrint('📊 RPC Response count: ${(response as List).length}');

      final modules = <CourseModule>[];
      
      for (var i = 0; i < response.length; i++) {
        try {
          final data = response[i] as Map<String, dynamic>;
          data['course_id'] = courseId;
          
          final module = CourseModule.fromJson(data);
          modules.add(module);
          
          debugPrint('✅ Module ${i + 1}: ${module.moduleName}, locked: ${module.isLocked}');
        } catch (e, stackTrace) {
          debugPrint('❌ Error parsing module $i: $e');
          debugPrint('Stack: $stackTrace');
        }
      }

      debugPrint('✅ Successfully loaded ${modules.length}/${response.length} modules');
      return modules;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching modules: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// ✅ Check module lock status
  Future<bool> checkModuleLock(String moduleId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return true; // Default locked

      final result = await _supabase.rpc(
        'is_module_locked',
        params: {
          'p_user_id': userId,
          'p_module_id': moduleId,
        },
      );

      debugPrint('🔒 Module $moduleId lock status: $result');
      return result as bool? ?? true;
    } catch (e) {
      debugPrint('❌ Error checking module lock: $e');
      return true;
    }
  }

  /// ✅ Unlock first module trong course (thủ công - nếu cần)
  Future<void> unlockFirstModule(String courseId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        debugPrint('❌ Cannot unlock module: user not found');
        return;
      }

      await _supabase.rpc(
        'unlock_first_module_in_course',
        params: {
          'p_user_id': userId,
          'p_course_id': courseId,
        },
      );

      debugPrint('✅ Unlocked first module in course $courseId');
    } catch (e) {
      debugPrint('❌ Error unlocking first module: $e');
    }
  }

  /// ✅ Lấy chi tiết một module (với lock status)
  Future<CourseModule?> fetchModuleById(String moduleId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return null;

      debugPrint('📋 Fetching module: $moduleId');

      // Query raw data
      final response = await _supabase
          .from('course_modules')
          .select('*')
          .eq('id', moduleId)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ Module not found');
        return null;
      }

      // Check lock status
      final isLocked = await checkModuleLock(moduleId);

      // Merge data
      final moduleData = {
        ...response,
        'is_locked': isLocked,
      };

      final module = CourseModule.fromJson(moduleData);
      debugPrint('✅ Module loaded: ${module.moduleName}, locked: $isLocked');
      
      return module;
    } catch (e) {
      debugPrint('❌ Error fetching module: $e');
      return null;
    }
  }

  /// ✅ Lấy số lượng modules của course
  Future<int> getModuleCount(String courseId) async {
    try {
      final response = await _supabase
          .from('course_modules')
          .select('id')
          .eq('course_id', courseId)
          .eq('is_active', true);

      return (response as List).length;
    } catch (e) {
      debugPrint('❌ Error getting module count: $e');
      return 0;
    }
  }

  /// ✅ Lấy tất cả modules (dùng để debug)
  Future<List<CourseModule>> fetchAllModules() async {
    try {
      debugPrint('📚 Fetching ALL modules');

      final response = await _supabase
          .from('course_modules')
          .select('*')
          .order('order_index', ascending: true);

      final modules = (response as List)
          .map((e) => CourseModule.fromJson({
            ...e,
            'is_locked': true, // Default locked khi không có user context
          }))
          .toList();

      debugPrint('✅ Loaded ${modules.length} total modules');
      return modules;
    } catch (e) {
      debugPrint('❌ Error fetching all modules: $e');
      return [];
    }
  }
}