class LessonSection {
  final String id;
  final String lessonId;
  final String sectionTitle;
  final String sectionType; // text, video, audio, quiz
  final int orderIndex;
  final String? content;
  final DateTime createdAt;

  LessonSection({
    required this.id,
    required this.lessonId,
    required this.sectionTitle,
    required this.sectionType,
    required this.orderIndex,
    this.content,
    required this.createdAt,
  });

  factory LessonSection.fromJson(Map<String, dynamic> json) {
    return LessonSection(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      sectionTitle: json['section_title'] as String,
      sectionType: json['section_type'] as String? ?? 'text',
      orderIndex: json['order_index'] as int? ?? 0,
      content: json['content'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lesson_id': lessonId,
    'section_title': sectionTitle,
    'section_type': sectionType,
    'order_index': orderIndex,
    'content': content,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() =>
      'LessonSection(id: $id, sectionType: $sectionType, sectionTitle: $sectionTitle)';
}