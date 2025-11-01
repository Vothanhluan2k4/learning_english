class LessonCourse {
  final String id;
  final String moduleId;
  final String? testId;
  final String lessonName;
  final String? description; // ✅ Add this
  final String lessonType;
  final int orderIndex;
  final bool isActive;
  final bool isLocked;
  final double targetScore;
  final double? userScore;
  final bool? isPassed;
  final int? attempts;
  final DateTime createdAt;

  LessonCourse({
    required this.id,
    required this.moduleId,
    this.testId,
    required this.lessonName,
    this.description, // ✅ Add this
    required this.lessonType,
    required this.orderIndex,
    required this.isActive,
    required this.isLocked,
    this.targetScore = 70.0,
    this.userScore,
    this.isPassed,
    this.attempts,
    required this.createdAt,
  });

  factory LessonCourse.fromJson(Map<String, dynamic> json) {
    return LessonCourse(
      id: (json['id'] ?? json['lesson_id']) as String,
      moduleId: json['module_id'] as String,
      testId: json['test_id'] as String?,
      lessonName: (json['lesson_name'] ?? json['name']) as String,
      description: json['description'] as String?, // ✅ Add this
      lessonType: json['lesson_type'] as String? ?? 'theory',
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isLocked: json['is_locked'] as bool? ?? true,
      targetScore: (json['target_score'] as num?)?.toDouble() ?? 70.0,
      userScore: (json['user_score'] as num?)?.toDouble(),
      isPassed: json['is_passed'] as bool?,
      attempts: (json['attempts'] as num?)?.toInt(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'module_id': moduleId,
    'test_id': testId,
    'lesson_name': lessonName,
    'description': description, // ✅ Add this
    'lesson_type': lessonType,
    'order_index': orderIndex,
    'is_active': isActive,
    'is_locked': isLocked,
    'target_score': targetScore,
    'user_score': userScore,
    'is_passed': isPassed,
    'attempts': attempts,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() =>
      'LessonCourse(id: $id, lessonName: $lessonName, isLocked: $isLocked, '
      'score: $userScore, passed: $isPassed)';
}