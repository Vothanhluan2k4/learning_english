class CourseModule {
  final String id;
  final String courseId;
  final String moduleName;
  final String? description;
  final int orderIndex;
  final bool isActive;
  final bool isLocked;
  final int lessonCount;
  final int completedLessonCount;
  final DateTime createdAt;

  CourseModule({
    required this.id,
    required this.courseId,
    required this.moduleName,
    this.description,
    required this.orderIndex,
    required this.isActive,
    required this.isLocked,
    this.lessonCount = 0,
    this.completedLessonCount = 0,
    required this.createdAt,
  });

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    return CourseModule(
      // ✅ Fix: Support both id and module_id
      id: (json['id'] ?? json['module_id']) as String,
      
      // ✅ Fix: course_id không có trong RPC response, phải truyền từ ngoài
      courseId: json['course_id'] as String? ?? '', // 
      
      moduleName: json['module_name'] as String,
      description: json['description'] as String?,
      
      // ✅ Fix: Cast num to int
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      
      isActive: json['is_active'] as bool? ?? true,
      isLocked: json['is_locked'] as bool? ?? true,
      
      // ✅ Fix: BIGINT từ SQL -> num trong Dart
      lessonCount: (json['lesson_count'] as num?)?.toInt() ?? 0,
      completedLessonCount: (json['completed_lesson_count'] as num?)?.toInt() ?? 0,
      
      // ✅ Fix: created_at không có trong RPC
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'course_id': courseId,
    'module_name': moduleName,
    'description': description,
    'order_index': orderIndex,
    'is_active': isActive,
    'is_locked': isLocked,
    'lesson_count': lessonCount,
    'completed_lesson_count': completedLessonCount,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() =>
      'CourseModule(id: $id, moduleName: $moduleName, isLocked: $isLocked)';
}