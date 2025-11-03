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

  Future<StatisticsData> loadStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final authId = _supabase.auth.currentUser?.id;
      if (authId == null) throw Exception('User not authenticated');

      final userId = await _authService.getUserIdFromAuthId(authId);
      if (userId == null) throw Exception('User ID not found');

      // Set default date range if not provided
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // 1. Tổng số bài tập đã hoàn thành (exercise progress) với filter ngày
      var exerciseQuery = _supabase
          .from('user_exercise_progress')
          .select('*')
          .eq('user_id', authId);

      // Apply date filter
      exerciseQuery = exerciseQuery
          .gte('completed_at', start.toIso8601String())
          .lte('completed_at', end.toIso8601String());

      final exerciseProgress = await exerciseQuery;
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

      // 4. Thống kê khóa học với filter ngày
      var courseQuery = _supabase
          .from('user_progress_lessons_course')
          .select('*')
          .eq('user_id', userId);

      // Filter by completed_at or created_at
      courseQuery = courseQuery
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      final lessonCourseProgress = await courseQuery;
      final totalLessonsCourseCompleted = lessonCourseProgress
          .where((e) => e['status'] == 'completed')
          .length;

      // 5. Số từ vựng đã học với filter ngày
      final totalLearnedWords = await _loadTotalLearnedWords(authId, start, end);

      // 6. Thống kê bài tập theo tuần
      final weeklyExercises = await _loadWeeklyExercises(authId, start, end);

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

  /// Load tổng số từ vựng đã học từ review_history với filter ngày
  Future<int> _loadTotalLearnedWords(String authId, DateTime startDate, DateTime endDate) async {
    try {
      final result = await _supabase
          .from('review_history')
          .select('words_remembered')
          .eq('user_id', authId)
          .gte('review_date', startDate.toIso8601String())
          .lte('review_date', endDate.toIso8601String());

      if (result.isEmpty) {
        return 0;
      }

      int total = 0;
      for (var item in result) {
        final wordsRemembered = item['words_remembered'];
        if (wordsRemembered != null) {
          total += (wordsRemembered as int);
        }
      }

      return total;
    } catch (e) {
      print('❌ Error loading total learned words: $e');
      return 0;
    }
  }

  /// Load exercises completed in date range
  Future<Map<String, int>> _loadWeeklyExercises(String authId, DateTime startDate, DateTime endDate) async {
    try {
      final data = await _supabase
          .from('user_exercise_progress')
          .select('completed_at')
          .eq('user_id', authId)
          .gte('completed_at', startDate.toIso8601String())
          .lte('completed_at', endDate.toIso8601String());

      final weeklyExercises = <String, int>{};
      final daysDiff = endDate.difference(startDate).inDays;
      final groupByWeek = daysDiff > 30;

      for (var item in data) {
        if (item['completed_at'] != null) {
          final date = DateTime.parse(item['completed_at'] as String);
          
          String key;
          if (groupByWeek) {
            // Group theo tuần
            final daysSinceStart = date.difference(startDate).inDays;
            final weekIndex = (daysSinceStart / 7).floor();
            final weekStart = startDate.add(Duration(days: weekIndex * 7));
            final weekEnd = startDate.add(Duration(days: weekIndex * 7 + 6));
            final actualEnd = weekEnd.isAfter(endDate) ? endDate : weekEnd;
            key = '${weekStart.day}/${weekStart.month}-${actualEnd.day}/${actualEnd.month}';
          } else {
            // Hiển thị từng ngày
            key = '${date.day}/${date.month}';
          }
          
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