class Course {
  final String id;
  final String courseName;
  final int courseOrder;
  final String? groupId;
  final String? requiredCourseId;

  Course({
    required this.id,
    required this.courseName,
    required this.courseOrder,
    this.groupId,
    this.requiredCourseId,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      courseName: json['course_name'],
      courseOrder: json['course_order'],
      groupId: json['group_id'],
      requiredCourseId: json['required_course_id'],
    );
  }
}