import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
class StatisticsData {
  final int totalLearnedWords;
  final int totalGrammarLessons;
  final int totalExercisesCompleted;
  final int totalLessonsCourseCompleted;
  final Map<String, int> weeklyExercises;
  final double correctAnswerRate;

  StatisticsData({
    required this.totalLearnedWords,
    required this.totalGrammarLessons,
    required this.totalExercisesCompleted,
    required this.totalLessonsCourseCompleted,
    required this.weeklyExercises,
    required this.correctAnswerRate,
  });
}

class StatisticsService {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  Future<StatisticsData> loadStatistics() async {
    try {
      final authId = _supabase.auth.currentUser?.id;
      if (authId == null) throw Exception('User not authenticated');

      final userId = await _authService.getUserIdFromAuthId(authId);
      
      if (userId == null) throw Exception('User ID not found');
      // 1. Tổng số bài tập đã hoàn thành (exercise progress)
      final exerciseProgress = await _supabase
          .from('user_exercise_progress')
          .select('*')
          .eq('user_id', authId);

      final totalExercisesCompleted = exerciseProgress.length;

      // 2. Số bài ngữ pháp đã học (unique lesson_id)
      final uniqueLessons = exerciseProgress
          .map((e) => e['lesson_id'])
          .toSet();
      final totalGrammarLessons = uniqueLessons.length;

      // 3. Tính tỷ lệ đúng/sai
      final correctAnswers = exerciseProgress
          .where((e) => e['is_correct'] == true)
          .length;

      double correctAnswerRate = 0.0;
      if (totalExercisesCompleted > 0) {
        correctAnswerRate = (correctAnswers / totalExercisesCompleted) * 100;
      }

      
      if (userId == null) throw Exception('User ID not found');
      // 4. Thống kê khóa học - user_progress_lessons_course
      final lessonCourseProgress = await _supabase
          .from('user_progress_lessons_course')
          .select('*')
          .eq('user_id', userId);

      final totalLessonsCourseCompleted = lessonCourseProgress
          .where((e) => e['status'] == 'completed')
          .length;


      // 5. TODO: Số từ vựng đã học - cần tạo bảng flashcards
      const totalLearnedWords = 0;

      // 6. Thống kê bài tập theo tuần
      final weeklyExercises = await _loadWeeklyExercises(authId);


      return StatisticsData(
        totalLearnedWords: totalLearnedWords,
        totalGrammarLessons: totalGrammarLessons,
        totalExercisesCompleted: totalExercisesCompleted,
        totalLessonsCourseCompleted: totalLessonsCourseCompleted,
        weeklyExercises: weeklyExercises,
        correctAnswerRate: correctAnswerRate,
      );
    } catch (e) {
      print('❌ Error loading statistics: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> _loadWeeklyExercises(String authId) async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final data = await _supabase
          .from('user_exercise_progress')
          .select('completed_at')
          .eq('user_id', authId)
          .gte('completed_at', sevenDaysAgo.toIso8601String());

      final weeklyExercises = <String, int>{};

      // Initialize last 7 days with 0
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = '${date.month}/${date.day}';
        weeklyExercises[key] = 0;
      }

      // Count exercises per day
      for (var item in data) {
        if (item['completed_at'] != null) {
          final date = DateTime.parse(item['completed_at'] as String);
          final key = '${date.month}/${date.day}';
          weeklyExercises[key] = (weeklyExercises[key] ?? 0) + 1;
        }
      }

      return weeklyExercises;
    } catch (e) {
      print('❌ Error loading weekly exercises: $e');
      return {};
    }
  }


}