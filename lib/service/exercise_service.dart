import 'package:supabase_flutter/supabase_flutter.dart';

class ExerciseService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getExercisesByLesson(String lessonId) async {
    final response = await _supabase
        .from('exercises')
        .select()
        .eq('lesson_id', lessonId)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }
}
