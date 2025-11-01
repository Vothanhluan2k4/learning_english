class Test {
  final String id;
  final String testName;
  final String? description;
  final String testType;
  final String? courseId;
  final String? courseGroupId;
  final String? recommendedCourseId;
  final int totalQuestions;
  final double totalScore;
  final DateTime createdAt;

  Test({
    required this.id,
    required this.testName,
    this.description,
    required this.testType,
    this.courseId,
    this.courseGroupId,
    this.recommendedCourseId,
    this.totalQuestions = 0,
    this.totalScore = 0,
    required this.createdAt,
  });

  factory Test.fromJson(Map<String, dynamic> json) {
    return Test(
      id: json['id'] ?? '',
      testName: json['test_name'] ?? '',
      description: json['description'],
      testType: json['test_type'] ?? 'lesson',
      courseId: json['course_id'],
      courseGroupId: json['course_group_id'],
      recommendedCourseId: json['recommended_course_id'],
      totalQuestions: json['total_questions'] ?? 0,
      totalScore: (json['total_score'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'test_name': testName,
      'description': description,
      'test_type': testType,
      'course_id': courseId,
      'course_group_id': courseGroupId,
      'recommended_course_id': recommendedCourseId,
      'total_questions': totalQuestions,
      'total_score': totalScore,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
