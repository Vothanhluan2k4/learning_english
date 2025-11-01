import '../models/course.dart';

class CourseGroup {
  final String id;
  final String groupName;
  final String? description;
  final List<Course> courses;

  CourseGroup({
    required this.id,
    required this.groupName,
    this.description,
    required this.courses,
  });

  factory CourseGroup.fromJson(Map<String, dynamic> json) {
    return CourseGroup(
      id: json['id'],
      groupName: json['group_name'],
      description: json['description'],
      courses: (json['courses'] as List<dynamic>?)
          ?.map((c) => Course.fromJson(c))
          .toList() ??
          [],
    );
  }
}