class UserLessonAttempt {
  final String id;
  final String userId;
  final String lessonId;
  final int attemptNumber;
  final double score;
  final bool isPassed;
  final DateTime startedAt;
  final DateTime? finishedAt;

  UserLessonAttempt({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.attemptNumber,
    required this.score,
    required this.isPassed,
    required this.startedAt,
    this.finishedAt,
  });

  factory UserLessonAttempt.fromJson(Map<String, dynamic> json) {
    return UserLessonAttempt(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      lessonId: json['lesson_id'] as String,
      attemptNumber: json['attempt_number'] as int? ?? 1,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      isPassed: json['is_passed'] as bool? ?? false,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : DateTime.now(),
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'lesson_id': lessonId,
    'attempt_number': attemptNumber,
    'score': score,
    'is_passed': isPassed,
    'started_at': startedAt.toIso8601String(),
    'finished_at': finishedAt?.toIso8601String(),
  };

  @override
  String toString() =>
      'UserLessonAttempt(id: $id, lessonId: $lessonId, attemptNumber: $attemptNumber, score: $score, isPassed: $isPassed)';
}
