import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lesson_course.dart';

class LessonCourseService {
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

  /// ✅ Lấy lessons với lock status (dùng RPC)
  Future<List<LessonCourse>> fetchLessonsByModule(String moduleId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        debugPrint('❌ No user logged in');
        return [];
      }

      debugPrint('📖 Fetching lessons for module: $moduleId, user: $userId');

      // ✅ Dùng RPC function
      final response = await _supabase.rpc(
        'get_lessons_with_lock_status',
        params: {
          'p_user_id': userId,
          'p_module_id': moduleId,
        },
      );

      debugPrint('📊 RPC Response count: ${(response as List).length}');

      final lessons = <LessonCourse>[];
      
      for (var i = 0; i < response.length; i++) {
        try {
          final data = response[i] as Map<String, dynamic>;
          
          // ✅ Add module_id vào data (RPC không return)
          data['module_id'] = moduleId;
          
          final lesson = LessonCourse.fromJson(data);
          lessons.add(lesson);
          
          debugPrint('✅ Lesson ${i + 1}: ${lesson.lessonName}, locked: ${lesson.isLocked}');
        } catch (e, stackTrace) {
          debugPrint('❌ Error parsing lesson $i: $e');
          debugPrint('Stack: $stackTrace');
        }
      }

      debugPrint('✅ Successfully loaded ${lessons.length}/${response.length} lessons');
      return lessons;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching lessons: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// ✅ Check lesson lock status
  Future<bool> checkLessonLock(String lessonId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return true;

      final result = await _supabase.rpc(
        'is_lesson_locked',
        params: {
          'p_user_id': userId,
          'p_lesson_id': lessonId,
        },
      );

      debugPrint('🔒 Lesson $lessonId lock status: $result');
      return result as bool? ?? true;
    } catch (e) {
      debugPrint('❌ Error checking lesson lock: $e');
      return true;
    }
  }

  /// ✅ Lấy chi tiết một lesson (với lock status)
  Future<LessonCourse?> fetchLessonById(String lessonId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return null;

      debugPrint('📋 Fetching lesson: $lessonId');

      // Query raw data
      final response = await _supabase
          .from('lessons_course')
          .select('*')
          .eq('id', lessonId)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ Lesson not found');
        return null;
      }

      // Check lock status
      final isLocked = await checkLessonLock(lessonId);

      // Merge data
      final lessonData = {
        ...response,
        'is_locked': isLocked,
      };

      final lesson = LessonCourse.fromJson(lessonData);
      debugPrint('✅ Lesson loaded: ${lesson.lessonName}, locked: $isLocked');
      
      return lesson;
    } catch (e) {
      debugPrint('❌ Error fetching lesson: $e');
      return null;
    }
  }

  /// ✅ Lấy số lượng lessons của module
  Future<int> getLessonCount(String moduleId) async {
    try {
      final response = await _supabase
          .from('lessons_course')
          .select('id')
          .eq('module_id', moduleId)
          .eq('is_active', true);

      return (response as List).length;
    } catch (e) {
      debugPrint('❌ Error getting lesson count: $e');
      return 0;
    }
  }

  /// Mở khóa bài học tiếp theo khi hoàn thành bài hiện tại
  Future<bool> unlockNextLesson(String lessonId) async {
    try {
      debugPrint('🔓 Unlocking next lesson after: $lessonId');

      // 1️⃣ Lấy thông tin bài học hiện tại
      final currentLesson = await fetchLessonById(lessonId);
      if (currentLesson == null) {
        throw Exception('Current lesson not found');
      }

      debugPrint('📖 Current lesson: ${currentLesson.lessonName}');
      debugPrint('   Module ID: ${currentLesson.moduleId}');
      debugPrint('   Order Index: ${currentLesson.orderIndex}');

      // 2️⃣ Lấy tất cả lessons trong module, sắp xếp theo order_index
      final allLessons = await fetchLessonsByModule(currentLesson.moduleId);
      if (allLessons.isEmpty) {
        throw Exception('No lessons found in module');
      }

      debugPrint('📊 Total lessons in module: ${allLessons.length}');

      // 3️⃣ Tìm bài học tiếp theo theo order_index
      final nextOrderIndex = currentLesson.orderIndex + 1;
      LessonCourse? nextLesson;
      
      for (var lesson in allLessons) {
        if (lesson.orderIndex == nextOrderIndex) {
          nextLesson = lesson;
          break;
        }
      }

      if (nextLesson == null) {
        debugPrint('⚠️ No next lesson found (order_index: $nextOrderIndex)');
        return true; // Đây là bài cuối cùng
      }

      debugPrint('🔓 Next lesson found: ${nextLesson.lessonName}');
      debugPrint('   Order Index: ${nextLesson.orderIndex}');
      debugPrint('   Is Locked: ${nextLesson.isLocked}');

      // 4️⃣ Mở khóa bài học tiếp theo
      await _supabase
          .from('lessons_course')
          .update({'is_locked': false})
          .eq('id', nextLesson.id);

      debugPrint('✅ Unlocked next lesson: ${nextLesson.lessonName}');
      return true;
    } catch (e) {
      debugPrint('❌ Error unlocking next lesson: $e');
      return false;
    }
  }

  /// ✅ Lấy icon theo loại lesson
  IconData getLessonIcon(String lessonType) {
    switch (lessonType) {
      case 'theory':
        return Icons.school;
      case 'practice':
        return Icons.edit;
      case 'mid_test':
        return Icons.quiz;
      case 'final_test':
        return Icons.assessment;
      case 'vocabulary':
        return Icons.abc;
      case 'toeic_part':
        return Icons.language;
      default:
        return Icons.book;
    }
  }

  /// ✅ Lấy tên loại lesson
  String getLessonTypeName(String lessonType) {
    switch (lessonType) {
      case 'theory':
        return 'Lý thuyết';
      case 'practice':
        return 'Bài tập';
      case 'mid_test':
        return 'Kiểm tra giữa kỳ';
      case 'final_test':
        return 'Kiểm tra cuối kỳ';
      case 'vocabulary':
        return 'Từ vựng';
      case 'toeic_part':
        return 'TOEIC Part';
      default:
        return 'Bài học';
    }
  }

  /// ✅ Lấy màu theo loại lesson
  Color getLessonTypeColor(String lessonType) {
    switch (lessonType) {
      case 'theory':
        return Colors.blue;
      case 'practice':
        return Colors.green;
      case 'mid_test':
        return Colors.orange;
      case 'final_test':
        return Colors.red;
      case 'vocabulary':
        return Colors.purple;
      case 'toeic_part':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  /// ✅ Lấy tất cả lessons của module với user progress
  Future<List<Map<String, dynamic>>> fetchLessonsWithProgress(
    String moduleId,
    String userId,
  ) async {
    try {
      debugPrint('📖 Fetching lessons with progress for module: $moduleId');

      final lessons = await fetchLessonsByModule(moduleId);
      final lessonsWithProgress = <Map<String, dynamic>>[];

      for (var lesson in lessons) {
        // Lấy user progress cho lesson này
        final progressData = await _supabase
            .from('user_progress_lessons_course')
            .select('status, score, is_passed, attempts')
            .eq('user_id', userId)
            .eq('lesson_id', lesson.id)
            .maybeSingle();

        lessonsWithProgress.add({
          'lesson': lesson,
          'progress': progressData,
        });
      }

      return lessonsWithProgress;
    } catch (e) {
      debugPrint('❌ Error fetching lessons with progress: $e');
      return [];
    }
  }

  /// ✅ Lấy progress lesson hiện tại
  Future<Map<String, dynamic>?> getLessonProgress(
    String userId,
    String lessonId,
  ) async {
    try {
      final response = await _supabase
          .from('user_progress_lessons_course')
          .select('*')
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ Error fetching lesson progress: $e');
      return null;
    }
  }
}