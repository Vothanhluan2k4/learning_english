class LessonContent {
  final String id;
  final String lessonId;
  final String type;
  final String? dataTitle;
  final String? dataBody;
  final String? exampleSentence;
  final String? exampleTranslation;
  final int orderInLesson;
  final DateTime createdAt;

  LessonContent({
    required this.id,
    required this.lessonId,
    required this.type,
    this.dataTitle,
    this.dataBody,
    this.exampleSentence,
    this.exampleTranslation,
    required this.orderInLesson,
    required this.createdAt,
  });

  factory LessonContent.fromJson(Map<String, dynamic> json) {
    return LessonContent(
      id: json['id'],
      lessonId: json['lesson_id'],
      type: json['type'],
      dataTitle: json['data_title'],
      dataBody: json['data_body'],
      exampleSentence: json['example_sentence'],
      exampleTranslation: json['example_translation'],
      orderInLesson: json['order_in_lesson'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}