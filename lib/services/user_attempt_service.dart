import 'package:flutter/material.dart';
import 'package:learning_english/services/auth_service.dart';
import 'package:learning_english/services/lesson_course_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_lesson_attempt.dart';
import '../models/user_attempt_question.dart';

class UserAttemptService {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  /// ✅ Tạo attempt mới
  Future<UserLessonAttempt?> createAttempt({
    required String lessonId,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final authId = authUser.id;
      final userId = await _authService.getUserIdFromAuthId(authId); 
      if (userId == null) throw Exception('User not found');

      debugPrint('✅ Using user_id: $userId');

      // Lấy số attempt hiện tại
      final existingAttempts = await _supabase
          .from('user_lesson_attempts')
          .select('attempt_number')
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .order('attempt_number', ascending: false)
          .limit(1);

      final nextAttemptNumber = ((existingAttempts as List).isNotEmpty
              ? (existingAttempts[0]['attempt_number'] as int)
              : 0) +
          1;

      debugPrint('📊 Next attempt number: $nextAttemptNumber');

      final response = await _supabase
          .from('user_lesson_attempts')
          .insert({
            'user_id': userId,
            'lesson_id': lessonId,
            'attempt_number': nextAttemptNumber,
            'started_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final attempt = UserLessonAttempt.fromJson(response as Map<String, dynamic>);
      debugPrint('✅ Attempt created: ${attempt.id} (attempt #$nextAttemptNumber)');
      return attempt;
    } catch (e) {
      debugPrint('❌ Error creating attempt: $e');
      rethrow;
    }
  }

  /// ✅ Lưu câu trả lời
  Future<bool> saveQuestionAnswer({
    required String attemptId,
    required String questionId,
    required dynamic selectedAnswer, // ✅ Can be String or List<String>
    required bool isCorrect,
    required int timeSpent,
  }) async {
    try {
      // ✅ Prepare data based on answer type
      String? singleOptionId;
      List<String>? multipleOptionIds;

      if (selectedAnswer is List<String>) {
        // Multiple choice
        multipleOptionIds = selectedAnswer;
        singleOptionId = selectedAnswer.isNotEmpty ? selectedAnswer.first : null;
      } else if (selectedAnswer is String) {
        // Single choice
        singleOptionId = selectedAnswer;
        multipleOptionIds = [selectedAnswer];
      }

      debugPrint(
       '💾 Saving answer: questionId=$questionId, '
        'singleOption=$singleOptionId, '
        'multipleOptions=$multipleOptionIds, '
        'isCorrect=$isCorrect, '
        'timeSpent=${timeSpent}s',
      );

      await _supabase
          .from('user_attempt_questions')
          .upsert(
            {
              'attempt_id': attemptId,
              'question_id': questionId,
              'selected_option_id': singleOptionId, 
              'selected_option_ids': multipleOptionIds, 
              'is_correct': isCorrect,
              'time_spent': timeSpent,
              'created_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'attempt_id,question_id',
          );

      debugPrint('✅ Answer saved (${multipleOptionIds?.length ?? 1} options)');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving answer: $e');
      return false;
    }
  }

 /// ✅ Kết thúc attempt & cập nhật progress
Future<bool> finishAttempt({
  required String attemptId,
  required String lessonId,
  required double score,
  required bool isPassed,
}) async {
  try {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) throw Exception('User not authenticated');

    final authId = authUser.id;
    final userId = await _authService.getUserIdFromAuthId(authId);
    if (userId == null) throw Exception('User not found');

    debugPrint(
      '🏁 Finishing attempt: attemptId=$attemptId, score=$score, isPassed=$isPassed',
    );

    final now = DateTime.now().toIso8601String();

    // 1️⃣ Update user_lesson_attempts
    await _supabase
        .from('user_lesson_attempts')
        .update({
          'finished_at': now,
          'score': score,
          'is_passed': isPassed,
        })
        .eq('id', attemptId);

    debugPrint('✅ Attempt updated');

    // 2️⃣ Lấy TẤT CẢ finished attempts để tính stats
    final allAttempts = await _supabase
        .from('user_lesson_attempts')
        .select('score, is_passed')
        .eq('user_id', userId)
        .eq('lesson_id', lessonId)
        .not('finished_at', 'is', null); 

    final attempts = allAttempts as List;
    final attemptCount = attempts.length;

    double highestScore = 0;
    bool isAnyPassed = false;

    for (var attempt in attempts) {
      final attemptScore = (attempt['score'] as num?)?.toDouble() ?? 0;
      if (attemptScore > highestScore) {
        highestScore = attemptScore;
      }
      if (attempt['is_passed'] == true) {
        isAnyPassed = true;
      }
    }

    debugPrint(
      '📊 Stats: highestScore=$highestScore, isAnyPassed=$isAnyPassed, attempts=$attemptCount',
    );
    debugPrint('🔍 CRITICAL: is_passed will be set to $isAnyPassed in user_progress_lessons_course');

    // 3️⃣ ✅ CRITICAL: Update user_progress_lessons_course
    // This MUST trigger auto_unlock_next_lesson if isAnyPassed = TRUE
    await _supabase
        .from('user_progress_lessons_course')
        .upsert(
          {
            'user_id': userId,
            'lesson_id': lessonId,
            'status': isAnyPassed ? 'completed' : 'in_progress',
            'score': highestScore,
            'attempts': attemptCount,
            'is_passed': isAnyPassed, 
            'completed_at': isAnyPassed ? now : null,
            'updated_at': now,
          },
          onConflict: 'user_id,lesson_id',
        );

    debugPrint('✅ Progress upserted with is_passed=$isAnyPassed');
    debugPrint('✅ Trigger should fire if OLD.is_passed != TRUE and NEW.is_passed = TRUE');
    
    return true;
  } catch (e, stackTrace) {
    debugPrint('❌ Error finishing attempt: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
}

  /// ✅ Lấy chi tiết câu trả lời
  Future<List<UserAttemptQuestion>> getAttemptAnswers(String attemptId) async {
    try {
      final response = await _supabase
          .from('user_attempt_questions')
          .select('*')
          .eq('attempt_id', attemptId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((e) => UserAttemptQuestion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching answers: $e');
      return [];
    }
  }

  /// ✅ Lấy tất cả attempts của user cho 1 lesson
  Future<List<UserLessonAttempt>> getLessonAttempts({
    required String lessonId,
  }) async {
    try {
final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final authId = authUser.id;
      final userId = await _authService.getUserIdFromAuthId(authId); 
      if (userId == null) throw Exception('User not found');

      final response = await _supabase
          .from('user_lesson_attempts')
          .select('*')
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .order('attempt_number', ascending: false);

      return (response as List)
          .map((e) => UserLessonAttempt.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching attempts: $e');
      return [];
    }
  }

  /// ✅ Tính điểm
  double calculateScore(List<UserAttemptQuestion> answers) {
    if (answers.isEmpty) return 0;

    final correctCount = answers.where((a) => a.isCorrect ?? false).length;
    return (correctCount / answers.length) * 100;
  }

  /// ✅ Cập nhật status lesson
  Future<bool> updateLessonProgress({
    required String lessonId,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final authId = authUser.id;
      final userId = await _authService.getUserIdFromAuthId(authId); 
      if (userId == null) throw Exception('User not found');

      await _supabase
          .from('user_progress_lessons_course')
          .upsert(
            {
              'user_id': userId,
              'lesson_id': lessonId,
              'status': 'in_progress',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'user_id,lesson_id',
          );

      debugPrint('✅ Progress updated to in_progress');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating progress: $e');
      return false;
    }
  }

  /// ✅ Lấy attempt hiện tại (chưa kết thúc)
  Future<UserLessonAttempt?> getCurrentAttempt({
    required String lessonId,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final authId = authUser.id;
      final userId = await _authService.getUserIdFromAuthId(authId); 
      if (userId == null) throw Exception('User not found');

      final response = await _supabase
          .from('user_lesson_attempts')
          .select('*')
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .order('started_at', ascending: false)
          .limit(5);

      if ((response as List).isEmpty) return null;

      // ✅ Filter: lấy attempt chưa kết thúc
      final incomplete = (response as List)
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (attempt) => attempt['finished_at'] == null,
            orElse: () => {},
          );

      if (incomplete.isEmpty) return null;

      return UserLessonAttempt.fromJson(incomplete);
    } catch (e) {
      debugPrint('❌ Error getting current attempt: $e');
      return null;
    }
  }

  /// ✅ Lấy attempt đã hoàn thành (nộp bài rồi)
  Future<UserLessonAttempt?> getCompletedAttempt({
    required String lessonId,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final authId = authUser.id;
      final userId = await _authService.getUserIdFromAuthId(authId); 
      if (userId == null) throw Exception('User not found');

      final response = await _supabase
          .from('user_lesson_attempts')
          .select('*')
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .order('finished_at', ascending: false)
          .limit(5);

      if ((response as List).isEmpty) return null;

      // ✅ Filter: lấy attempt đã kết thúc
      final completed = (response as List)
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (attempt) => attempt['finished_at'] != null,
            orElse: () => {},
          );

      if (completed.isEmpty) return null;

      return UserLessonAttempt.fromJson(completed);
    } catch (e) {
      debugPrint('❌ Error getting completed attempt: $e');
      return null;
    }
  }

  /// ✅ Lấy các câu trả lời đã lưu của attempt
  Future<Map<String, Map<String, dynamic>>> getSavedAnswers(
    String attemptId,
  ) async {
    try {
      final response = await _supabase
          .from('user_attempt_questions')
          .select('*')
          .eq('attempt_id', attemptId);

      final map = <String, Map<String, dynamic>>{};
      for (var item in response as List) {
        final data = item as Map<String, dynamic>;
        
        // ✅ Parse selected_option_ids
        List<String>? selectedIds;
        if (data['selected_option_ids'] != null) {
          final idsJson = data['selected_option_ids'];
          if (idsJson is List) {
            selectedIds = idsJson.map((e) => e.toString()).toList();
          }
        }

        // ✅ Add to map with parsed IDs
        map[data['question_id'] as String] = {
          ...data,
          'selected_option_ids_parsed': selectedIds, 
        };
      }

      debugPrint('✅ Loaded ${map.length} saved answers');
      return map;
    } catch (e) {
      debugPrint('❌ Error getting saved answers: $e');
      return {};
    }
  }

  /// ✅ Xoá attempt (reset lại) - xoá cascade
  Future<bool> deleteAttempt(String attemptId) async {
    try {
      debugPrint('🗑️ Deleting attempt: $attemptId');

      // ✅ Step 1: Xoá tất cả câu trả lời trước
      await _supabase
          .from('user_attempt_questions')
          .delete()
          .eq('attempt_id', attemptId);

      debugPrint('✅ Deleted all answers for attempt: $attemptId');

      // ✅ Step 2: Xoá attempt
      await _supabase
          .from('user_lesson_attempts')
          .delete()
          .eq('id', attemptId);

      debugPrint('✅ Attempt deleted: $attemptId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting attempt: $e');
      return false;
    }
  }

  Future<bool> initializeLessonProgress({
    required String lessonId,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('User not authenticated');

      final authId = authUser.id;
      final userId = await _authService.getUserIdFromAuthId(authId);
      if (userId == null) throw Exception('User not found');

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🎬 INITIALIZING LESSON PROGRESS');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('👤 User ID: $userId');
      debugPrint('📚 Lesson ID: $lessonId');

      // ✅ Check if progress already exists
      final existing = await _supabase
          .from('user_progress_lessons_course')
          .select('is_passed, status')
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('ℹ️ Progress already exists:');
        debugPrint('   - is_passed: ${existing['is_passed']}');
        debugPrint('   - status: ${existing['status']}');
        
        // If already passed, don't reset
        if (existing['is_passed'] == true) {
          debugPrint('✅ Already passed, keeping existing state');
          return true;
        }
      }

      final now = DateTime.now().toIso8601String();

      // ✅ Create or update progress with is_passed = false
      await _supabase
          .from('user_progress_lessons_course')
          .upsert(
            {
              'user_id': userId,
              'lesson_id': lessonId,
              'status': 'in_progress',
              'score': 0.0,
              'is_passed': false, 
              'attempts': 0,
              'completed_at': null,
              'created_at': existing == null ? now : null, 
              'updated_at': now,
            },
            onConflict: 'user_id,lesson_id',
          );

      debugPrint('✅ Progress initialized/updated:');
      debugPrint('   - status: in_progress');
      debugPrint('   - is_passed: false ← IMPORTANT for trigger');
      debugPrint('   - score: 0.0');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing progress: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }
}