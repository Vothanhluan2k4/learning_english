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
      id: json['id'] as String,
      courseName: json['course_name'] as String,
      courseOrder: json['course_order'] as int? ?? 0,
      groupId: json['group_id'] as String?,
      requiredCourseId: json['required_course_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'course_name': courseName,
    'course_order': courseOrder,
    'group_id': groupId,
    'required_course_id': requiredCourseId,
  };

  @override
  String toString() => 'Course(id: $id, courseName: $courseName)';
}