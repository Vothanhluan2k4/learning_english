class WritingQuestion {
  final String id;
  final String sectionId;
  final String questionText;
  final String questionType;
  final int orderIndex;
  final String difficultyLevel;
  final int? minWords;
  final int? maxWords;
  final String? guideline;
  final String? exampleAnswer;
  final DateTime createdAt;

  WritingQuestion({
    required this.id,
    required this.sectionId,
    required this.questionText,
    required this.questionType,
    required this.orderIndex,
    required this.difficultyLevel,
    this.minWords,
    this.maxWords,
    this.guideline,
    this.exampleAnswer,
    required this.createdAt,
  });

  factory WritingQuestion.fromJson(Map<String, dynamic> json) {
    return WritingQuestion(
      id: json['id'] as String,
      sectionId: json['section_id'] as String,
      questionText: json['question_text'] as String? ?? '',
      questionType: json['question_type'] as String? ?? 'writing',
      orderIndex: json['order_index'] as int? ?? 0,
      difficultyLevel: json['difficulty_level'] as String? ?? 'medium',
      minWords: json['min_words'] as int?,
      maxWords: json['max_words'] as int?,
      guideline: json['guideline'] as String?,
      exampleAnswer: json['example_answer'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}