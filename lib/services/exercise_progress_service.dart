import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise_progress.dart';

class ExerciseProgressService {
  final _supabase = Supabase.instance.client;

  Future<void> saveProgress(ExerciseProgress progress) async {
    await _supabase.from('user_exercise_progress').upsert(progress.toJson(),
      onConflict: 'user_id,exercise_id',
    );
  }

  // Submit 1 câu
  Future<void> deleteSingleProgress(String userId, String exerciseId) async {
    try {
      await _supabase
          .from('user_exercise_progress')
          .delete()
          .eq('user_id', userId)
          .eq('exercise_id', exerciseId);

      print(' Progress deleted for exercise: $exerciseId');
    } catch (e) {
      print(' Error deleting progress: $e');
      rethrow;
    }
  }


  Future<List<ExerciseProgress>> getProgressByLesson(
      String userId, String lessonId) async {
    final response = await _supabase
        .from('user_exercise_progress')
        .select()
        .eq('user_id', userId)
        .eq('lesson_id', lessonId);

    return (response as List)
        .map((json) => ExerciseProgress.fromJson(json))
        .toList();
  }

  Future<void> resetProgress(String userId, String lessonId) async {
    await _supabase
        .from('user_exercise_progress')
        .delete()
        .eq('user_id', userId)
        .eq('lesson_id', lessonId);
  }

  // Lấy tổng số bài tập đã hoàn thành của user
  Future<int> getTotalCompletedExercises(String userId) async {
    try {
      // Cách 1: Đếm bằng length của list
      final response = await _supabase
          .from('user_exercise_progress')
          .select('id')
          .eq('user_id', userId);

      return (response as List).length;
    } catch (e) {
      print(' Error getting total completed: $e');
      return 0;
    }
  }

  // Lấy tỷ lệ đúng của user
  Future<double> getAccuracyRate(String userId) async {
    try {
      final response = await _supabase
          .from('user_exercise_progress')
          .select('is_correct')
          .eq('user_id', userId);

      if (response == null || (response as List).isEmpty) return 0.0;

      final total = (response as List).length;
      final correct = (response as List)
          .where((item) => item['is_correct'] == true)
          .length;

      return (correct / total) * 100;
    } catch (e) {
      print(' Error calculating accuracy: $e');
      return 0.0;
    }
  }

  // Lấy lessons đã hoàn thành
  Future<List<String>> getCompletedLessons(String userId) async {
    try {
      final response = await _supabase
          .from('user_exercise_progress')
          .select('lesson_id')
          .eq('user_id', userId);

      final lessons = (response as List)
          .map((item) => item['lesson_id'] as String)
          .toSet() // Remove duplicates
          .toList();

      return lessons;
    } catch (e) {
      print(' Error getting completed lessons: $e');
      return [];
    }
  }

  // Kiểm tra lesson đã hoàn thành chưa
  Future<bool> isLessonCompleted(String userId, String lessonId) async {
    try {
      final response = await _supabase
          .from('user_exercise_progress')
          .select('id')
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      print(' Error checking lesson completion: $e');
      return false;
    }
  }

  // Lấy số câu đúng của một lesson
  Future<int> getCorrectAnswersCount(String userId, String lessonId) async {
    try {
      final response = await _supabase
          .from('user_exercise_progress')
          .select('is_correct')
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .eq('is_correct', true);

      return (response as List).length;
    } catch (e) {
      print(' Error getting correct count: $e');
      return 0;
    }
  }

}

