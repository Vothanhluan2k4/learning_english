import 'package:learning_english/models/user_lesson_attempt.dart';

class UserAttemptQuestion {
  final String id;
  final String attemptId;
  final String questionId;
  final String? selectedOptionId;
  final List<String>? selectedOptionIds;
  final bool? isCorrect;
  final int timeSpent;
  final DateTime createdAt;

  UserAttemptQuestion({
    required this.id,
    required this.attemptId,
    required this.questionId,
    this.selectedOptionId,
    this.selectedOptionIds,
    this.isCorrect,
    this.timeSpent = 0,
    required this.createdAt,
  });

  factory UserAttemptQuestion.fromJson(Map<String, dynamic> json) {
    List<String>? selectedIds;
    if (json['selected_option_ids'] != null) {
      final idsJson = json['selected_option_ids'];
      if (idsJson is List) {
        selectedIds = idsJson.map((e) => e.toString()).toList();
      }
    }

    return UserAttemptQuestion(
      id: json['id'] as String,
      attemptId: json['attempt_id'] as String,
      questionId: json['question_id'] as String,
      selectedOptionId: json['selected_option_id'] as String?,
      selectedOptionIds: selectedIds,
      isCorrect: json['is_correct'] as bool?,
      timeSpent: json['time_spent'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'attempt_id': attemptId,
    'question_id': questionId,
    'selected_option_id': selectedOptionId,
    'selected_option_ids': selectedOptionIds, 
    'is_correct': isCorrect,
    'time_spent': timeSpent,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() =>
      'UserAttemptQuestion(questionId: $questionId, isCorrect: $isCorrect, timeSpent: ${timeSpent}s)';
}

class AttemptResult {
  final UserLessonAttempt attempt;
  final List<UserAttemptQuestion> answers;
  final double score;
  final bool isPassed;
  final int correctCount;
  final int totalCount;

  AttemptResult({
    required this.attempt,
    required this.answers,
    required this.score,
    required this.isPassed,
    required this.correctCount,
    required this.totalCount,
  });

  @override
  String toString() =>
      'AttemptResult(score: $score, isPassed: $isPassed, correctCount: $correctCount/$totalCount)';
}