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

  Future<List<Lesson>> getLessonsByTopicName(String topicName) async {
    // Lấy ID của topic theo topic_name_en
    final topicResponse = await _supabase
        .from('topics')
        .select('id')
        .eq('topic_name_en', topicName)
        .maybeSingle();

    if (topicResponse == null) {
      throw Exception('Không tìm thấy chủ đề: $topicName');
    }

    final topicId = topicResponse['id'];

    final lessonsResponse = await _supabase
        .from('lessons')
        .select()
        .eq('topic_id', topicId)
        .order('order_in_topic', ascending: true);

    return lessonsResponse.map<Lesson>((json) => Lesson.fromJson(json)).toList();
  }

  //  Lấy chi tiết một bài học theo ID
  Future<Map<String, dynamic>?> getLessonById(String lessonId) async {
    final response = await _supabase
        .from('lessons')
        .select()
        .eq('id', lessonId)
        .maybeSingle();
    return response;
  }

  //  Lấy nội dung bài học (Lesson Content)

  Future<List<LessonContent>> getLessonContents(String lessonId) async {
    final response = await _supabase
        .from('lesson_contents')
        .select()
        .eq('lesson_id', lessonId)
        .order('order_in_lesson', ascending: true);

    return response.map<LessonContent>((json) => LessonContent.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getExercisesByLesson(String lessonId) async {
    final response = await _supabase
        .from('exercises')
        .select()
        .eq('lesson_id', lessonId)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }


}