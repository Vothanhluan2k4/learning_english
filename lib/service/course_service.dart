import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course_group.dart';

class CourseService {
  final supabase = Supabase.instance.client;

  Future<List<CourseGroup>> fetchCourseGroups() async {
    final response = await supabase
        .from('course_groups')
        .select('id, group_name, description, courses: courses(id, course_name, course_order, required_course_id, group_id)')
        .order('created_at', ascending: true);

    return (response as List)
        .map((item) => CourseGroup.fromJson(item))
        .toList();
  }
}
