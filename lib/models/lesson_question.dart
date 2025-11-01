class LessonQuestion {
  final String id;
  final String sectionId;
  final String questionText;
  final String questionType; // single_choice, multiple_choice, fill_blank, listening, reading
  final int orderIndex;
  final String? difficultyLevel;
  final String? explanation;
  final bool isActive;
  final DateTime createdAt;

  LessonQuestion({
    required this.id,
    required this.sectionId,
    required this.questionText,
    required this.questionType,
    required this.orderIndex,
    this.difficultyLevel,
    this.explanation,
    required this.isActive,
    required this.createdAt,
  });

  factory LessonQuestion.fromJson(Map<String, dynamic> json) {
    return LessonQuestion(
      id: json['id'] as String,
      sectionId: json['section_id'] as String,
      questionText: json['question_text'] as String,
      questionType: json['question_type'] as String? ?? 'single_choice',
      orderIndex: json['order_index'] as int? ?? 0,
      difficultyLevel: json['difficulty_level'] as String?,
      explanation: json['explanation'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'section_id': sectionId,
    'question_text': questionText,
    'question_type': questionType,
    'order_index': orderIndex,
    'difficulty_level': difficultyLevel,
    'explanation': explanation,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() =>
      'LessonQuestion(id: $id, questionType: $questionType)';
}