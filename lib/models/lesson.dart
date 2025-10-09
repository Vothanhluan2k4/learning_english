class Lesson {
  final String id;
  final String topicId;
  final String lessonTitleVi;
  final String lessonTitleEn;
  final int orderInTopic;
  final DateTime createdAt;

  Lesson({
    required this.id,
    required this.topicId,
    required this.lessonTitleVi,
    required this.lessonTitleEn,
    required this.orderInTopic,
    required this.createdAt,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      topicId: json['topic_id'],
      lessonTitleVi: json['lesson_title_vi'],
      lessonTitleEn: json['lesson_title_en'],
      orderInTopic: json['order_in_topic'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic_id': topicId,
      'lesson_title_vi': lessonTitleVi,
      'lesson_title_en': lessonTitleEn,
      'order_in_topic': orderInTopic,
      'created_at': createdAt.toIso8601String(),
    };
  }
}