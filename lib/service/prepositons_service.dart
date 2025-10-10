import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topic.dart';
import '../models/lesson.dart';
import '../models/lesson_content.dart';
import '../models/exercise.dart';

class PrepositonsService {
  final SupabaseClient _supabase = Supabase.instance.client;

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