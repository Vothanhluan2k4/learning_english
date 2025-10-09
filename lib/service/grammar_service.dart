import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topic.dart';
import '../models/lesson.dart';
import '../models/lesson_content.dart';
import '../models/exercise.dart';

class GrammarService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lấy tất cả topics
  Future<List<Topic>> getAllTopics() async {
    try {
      final response = await _supabase
          .from('topics')
          .select()
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => Topic.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi khi tải topics: $e');
    }
  }

  // Lấy số lượng lessons theo topic_id
  Future<int> getLessonCountByTopic(String topicId) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('id')
          .eq('topic_id', topicId);

      return (response as List).length;
    } catch (e) {
      throw Exception('Lỗi khi đếm lessons: $e');
    }
  }

  // Lấy tất cả lessons của một topic
  Future<List<Lesson>> getLessonsByTopic(String topicId) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select()
          .eq('topic_id', topicId)
          .order('order_in_topic', ascending: true);

      return (response as List)
          .map((json) => Lesson.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi khi tải lessons: $e');
    }
  }

  // Lấy topics với số lượng lessons
  Future<List<Map<String, dynamic>>> getTopicsWithLessonCount() async {
    try {
      final topics = await getAllTopics();

      List<Map<String, dynamic>> result = [];

      for (var topic in topics) {
        final lessonCount = await getLessonCountByTopic(topic.id);
        result.add({
          'topic': topic,
          'lessonCount': lessonCount,
        });
      }

      return result;
    } catch (e) {
      throw Exception('Lỗi khi tải dữ liệu: $e');
    }
  }

  //  Lấy danh sách bài tập của một bài học

  Future<List<Exercise>> getExercises(String lessonId) async {
    final response = await _supabase
        .from('exercises')
        .select()
        .eq('lesson_id', lessonId);

    return response.map<Exercise>((json) => Exercise.fromJson(json)).toList();
  }


}