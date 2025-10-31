class ExerciseProgress {
  final String? id;
  final String userId;
  final String lessonId;
  final String exerciseId;
  final String userAnswer;
  final bool isCorrect;
  final String explanation;
  final DateTime completedAt;

  ExerciseProgress({
    this.id,
    required this.userId,
    required this.lessonId,
    required this.exerciseId,
    required this.userAnswer,
    required this.isCorrect,
    required this.explanation,
    required this.completedAt,
  });

  factory ExerciseProgress.fromJson(Map<String, dynamic> json) {
    return ExerciseProgress(
      id: json['id'],
      userId: json['user_id'],
      lessonId: json['lesson_id'],
      exerciseId: json['exercise_id'],
      userAnswer: json['user_answer'] ?? '',
      isCorrect: json['is_correct'] ?? false,
      explanation: json['explanation'] ?? '',
      completedAt: DateTime.parse(json['completed_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'lesson_id': lessonId,
      'exercise_id': exerciseId,
      'user_answer': userAnswer,
      'is_correct': isCorrect,
      'explanation': explanation,
      'completed_at': completedAt.toIso8601String(),
    };
  }
}