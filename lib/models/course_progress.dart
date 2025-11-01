class CourseProgressModel {
  final String courseId;
  final int total;
  final int completed;
  final int percent;
  final String status;

  CourseProgressModel({
    required this.courseId,
    required this.total,
    required this.completed,
    required this.percent,
    required this.status,
  });

  factory CourseProgressModel.fromJson(Map<String, dynamic> json) {
    return CourseProgressModel(
      courseId: json['courseId'] as String,
      total: json['total'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      percent: json['percent'] as int? ?? 0,
      status: json['status'] as String? ?? 'not_started',
    );
  }

  @override
  String toString() => 'CourseProgressModel(courseId: $courseId, percent: $percent%, status: $status)';
}