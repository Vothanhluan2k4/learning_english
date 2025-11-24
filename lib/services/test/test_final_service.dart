import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/question_group.dart';
import 'package:learning_english/models/test_question.dart';

class TestFinalService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Lấy thông tin test
  Future<Map<String, dynamic>?> fetchTestInfo(String testId) async {
    try {
      final response = await _supabase
          .from('tests')
          .select('id, test_name, time_limit, test_type, total_questions, recommended_course_id')
          .eq('id', testId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching test info: $e');
      return null;
    }
  }

  /// Lấy danh sách câu hỏi + nhóm câu hỏi
  Future<List<dynamic>> fetchTestItems(String testId) async {
    final List<dynamic> allItems = [];

    try {
      // Câu hỏi trực tiếp
      final directRes = await _supabase
          .from('test_questions')
          .select()
          .eq('test_id', testId)
          .isFilter('group_id', null)
          .order('order_in_test', ascending: true);

      final directQuestions =
          (directRes as List).map((q) => TestQuestion.fromJson(q)).toList();
      allItems.addAll(directQuestions);

      // Nhóm câu hỏi
      final groupRes = await _supabase
          .from('question_groups')
          .select('''
            id, test_id, title, instruction, media_type, media_url, content, order_in_test,
            test_questions!inner(*)
          ''')
          .eq('test_id', testId)
          .order('order_in_test', ascending: true);

      for (final g in groupRes) {
        final group = QuestionGroup.fromJson(g);
        group.testQuestions.sort((a, b) =>
            (a.orderInTest ?? 0).compareTo(b.orderInTest ?? 0));
        allItems.add(group);
      }

      // Sắp xếp theo order_in_test
      allItems.sort((a, b) {
        final orderA = a is TestQuestion ? a.orderInTest : (a as QuestionGroup).orderInTest;
        final orderB = b is TestQuestion ? b.orderInTest : (b as QuestionGroup).orderInTest;
        return (orderA ?? 0).compareTo(orderB ?? 0);
      });

      return allItems;
    } catch (e) {
      debugPrint('Error fetching test items: $e');
      return [];
    }
  }

  /// Tạo hoặc lấy kết quả test của user
  Future<String?> createOrGetUserTestResult({
    required String userId,
    required String testId,
  }) async {
    try {
      final existing = await _supabase
          .from('user_test_results')
          .select('id, status, time_remaining')
          .eq('user_id', userId)
          .eq('test_id', testId)
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      } else {
        final newResult = await _supabase
            .from('user_test_results')
            .insert({
              'user_id': userId,
              'test_id': testId,
              'status': 'in_progress',
              'started_at': DateTime.now().toIso8601String(),
              'last_activity': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();
        return newResult['id'] as String;
      }
    } catch (e) {
      debugPrint('Error creating user test result: $e');
      return null;
    }
  }

  /// Cập nhật tiến độ
  Future<void> updateTestProgress({
    required String resultId,
    required int timeRemaining,
  }) async {
    try {
      await _supabase.from('user_test_results').update({
        'status': 'in_progress',
        'time_remaining': timeRemaining ~/ 60,
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('id', resultId);
    } catch (e) {
      debugPrint('Error updating progress: $e');
    }
  }

  /// Xử lý timeout
  Future<void> handleTimeout(String resultId) async {
    try {
      await _supabase.from('user_test_results').update({
        'status': 'timeout',
        'completed_at': DateTime.now().toIso8601String(),
        'time_remaining': 0,
      }).eq('id', resultId);
    } catch (e) {
      debugPrint('Error handling timeout: $e');
    }
  }

  /// Nộp bài
  Future<void> submitTest({
    required String resultId,
    required double score,
    required int totalQuestions,
    required int correctAnswers,
    required bool isTimeout,
  }) async {
    try {
      await _supabase.from('user_test_results').update({
        'score': score,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'status': isTimeout ? 'timeout' : 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'time_remaining': 0,
      }).eq('id', resultId);
    } catch (e) {
      debugPrint('Error submitting test: $e');
    }
  }

  /// Cập nhật placement summary
  Future<void> updatePlacementSummary({
    required String userId,
    required String testId,
    required String resultId,
    required double score,
    required String recommendedCourseId,
  }) async {
    try {
      await _supabase.from('user_placement_summary').upsert({
        'user_id': userId,
        'placement_test_id': testId,
        'latest_result_id': resultId,
        'score': score,
        'recommended_course_id': recommendedCourseId,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error updating placement summary: $e');
    }
  }

  /// Cập nhật lesson attempt + progress
  Future<void> updateLessonProgress({
    required String userId,
    required String lessonId,
    required double score,
    required bool isPassed,
    required int attemptNumber,
    required String resultId,
  }) async {
    try {
      // 1. Tạo attempt
      await _supabase.from('user_lesson_attempts').insert({
        'user_id': userId,
        'lesson_id': lessonId,
        'attempt_number': attemptNumber,
        'score': score,
        'is_passed': isPassed,
        'finished_at': DateTime.now().toIso8601String(),
      });

      // 2. Kiểm tra progress
      final existing = await _supabase
          .from('user_progress_lessons_course')
          .select()
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('user_progress_lessons_course').insert({
          'user_id': userId,
          'lesson_id': lessonId,
          'status': 'in_progress',
          'score': 0,
          'is_passed': false,
          'attempts': 0,
        });
      }

      // 3. Cập nhật completed
      await _supabase
          .from('user_progress_lessons_course')
          .update({
            'status': 'completed',
            'score': score,
            'is_passed': isPassed,
            'attempts': attemptNumber,
            'completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('lesson_id', lessonId);

      // 4. Unlock next lesson nếu passed
      if (isPassed) {
        await _unlockNextLesson(lessonId);
      }
    } catch (e) {
      debugPrint('Error updating lesson progress: $e');
    }
  }

  /// Mở khóa bài học tiếp theo
  Future<void> _unlockNextLesson(String currentLessonId) async {
    try {
      final current = await _supabase
          .from('lessons_course')
          .select('module_id, order_index')
          .eq('id', currentLessonId)
          .single();

      final next = await _supabase
          .from('lessons_course')
          .select('id')
          .eq('module_id', current['module_id'])
          .gt('order_index', current['order_index'])
          .order('order_index', ascending: true)
          .limit(1)
          .maybeSingle();

      if (next != null) {
        await _supabase
            .from('lessons_course')
            .update({'is_locked': false})
            .eq('id', next['id']);
      }
    } catch (e) {
      debugPrint('Error unlocking next lesson: $e');
    }
  }

  /// Lấy tên module tiếp theo
  Future<String?> getNextModuleName(String currentLessonId) async {
    try {
      final current = await _supabase
          .from('lessons_course')
          .select('module_id, order_index')
          .eq('id', currentLessonId)
          .single();

      final currentModule = await _supabase
          .from('course_modules')
          .select('course_id, order_index')
          .eq('id', current['module_id'])
          .single();

      final nextModule = await _supabase
          .from('course_modules')
          .select('module_name')
          .eq('course_id', currentModule['course_id'])
          .gt('order_index', currentModule['order_index'])
          .order('order_index', ascending: true)
          .limit(1)
          .maybeSingle();

      return nextModule?['module_name'] as String? ?? 'Hoàn thành toàn bộ khóa học';
    } catch (e) {
      debugPrint('Error getting next module: $e');
      return null;
    }
  }

  /// Lấy attempt number tiếp theo
  Future<int> getNextAttemptNumber(String userId, String lessonId) async {
    try {
      final result = await _supabase
          .from('user_lesson_attempts')
          .select('attempt_number')
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .order('attempt_number', ascending: false)
          .limit(1)
          .maybeSingle();
      return (result?['attempt_number'] as int? ?? 0) + 1;
    } catch (e) {
      return 1;
    }
  }
  
  /// ✅ FIXED: Check and unlock next course if current course completed
Future<void> checkAndUnlockNextCourse(String userId, String lessonId) async {
  try {
    debugPrint('🔍 Checking if course completed...');

    // Get current course info WITH group_id
    final lessonInfo = await _supabase
        .from('lessons_course')
        .select('''
          id,
          module_id,
          course_modules!inner(
            id,
            course_id,
            courses!inner(
              id,
              course_order,
              group_id
            )
          )
        ''')
        .eq('id', lessonId)
        .single();

    final courseId = lessonInfo['course_modules']['courses']['id'] as String;
    final courseOrder = lessonInfo['course_modules']['courses']['course_order'] as int;
    final groupId = lessonInfo['course_modules']['courses']['group_id'] as String?;

    debugPrint('   Course: $courseId, Order: $courseOrder, Group: $groupId');

    // Check if all lessons in course are completed
    final incompleteLessons = await _supabase.rpc(
      'check_course_completion',
      params: {
        'p_user_id': userId,
        'p_course_id': courseId,
      },
    );

    debugPrint('   Incomplete lessons: $incompleteLessons');

    if (incompleteLessons == 0) {
      debugPrint('🎉 Course $courseId completed!');

      // ✅ FIX: Build query conditionally BEFORE executing
      PostgrestFilterBuilder query = _supabase
          .from('courses')
          .select('id, course_name, course_order')
          .gt('course_order', courseOrder);
      
      // ✅ Add group_id filter if exists
      if (groupId != null) {
        query = query.eq('group_id', groupId);
      }
      
      // ✅ Execute query ONCE
      final nextCourse = await query
          .order('course_order', ascending: true)
          .limit(1)
          .maybeSingle();

      if (nextCourse != null) {
        final nextCourseId = nextCourse['id'] as String;
        final nextCourseName = nextCourse['course_name'] as String;
        final nextCourseOrder = nextCourse['course_order'] as int;
        
        debugPrint('🔓 Unlocking next course: $nextCourseName (order: $nextCourseOrder)');

        // Call unlock function
        await _supabase.rpc(
          'unlock_course_for_user',
          params: {
            'p_user_id': userId,
            'p_course_id': nextCourseId,
          },
        );

        debugPrint('✅ Next course unlocked: $nextCourseName');
      } else {
        if (groupId != null) {
          debugPrint('🏆 All courses in group $groupId completed!');
        } else {
          debugPrint('🏆 All courses completed!');
        }
      }
    } else {
      debugPrint('⏳ Course not completed yet ($incompleteLessons lessons remaining)');
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Error checking course completion: $e');
    debugPrint('   Stack trace: $stackTrace');
    // Don't throw - this is background check
  }
}
  
}