class Exercise {
  final String id;
  final String lessonId;
  final String questionText;
  final String questionType;
  final List<String> options;
  final String correctAnswer;
  final String? explanation;
  final DateTime createdAt;

  Exercise({
    required this.id,
    required this.lessonId,
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    required this.createdAt,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      lessonId: json['lesson_id'],
      questionText: json['question_text'],
      questionType: json['question_type'],
      options: List<String>.from(json['options']),
      correctAnswer: json['correct_answer'],
      explanation: json['explanation'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}