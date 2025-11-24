class SpeakingQuestion {
  final String id;
  final String sectionId;
  final String questionText;
  final String speakingMode; // 'read_aloud', 'answer_prompt', 'free_speaking'
  final int orderIndex;
  final String? difficultyLevel;
  
  // Speaking-specific fields
  final String? referenceText; // For read_aloud mode
  final String? expectedAnswer; // Expected content for comparison
  final String? guideline; // Speaking guidelines/hints
  final int timeLimit; // Speaking time in seconds
  final Map<String, dynamic>? gradingCriteria;
  
  final bool isActive;
  final DateTime createdAt;

  SpeakingQuestion({
    required this.id,
    required this.sectionId,
    required this.questionText,
    required this.speakingMode,
    this.orderIndex = 0,
    this.difficultyLevel,
    this.referenceText,
    this.expectedAnswer,
    this.guideline,
    this.timeLimit = 60, // Default 60 seconds
    this.gradingCriteria,
    this.isActive = true,
    required this.createdAt,
  });

  factory SpeakingQuestion.fromJson(Map<String, dynamic> json) {
    return SpeakingQuestion(
      id: json['id'] as String,
      sectionId: json['section_id'] as String,
      questionText: json['question_text'] as String,
      speakingMode: json['speaking_mode'] as String? ?? 'read_aloud',
      orderIndex: json['order_index'] as int? ?? 0,
      difficultyLevel: json['difficulty_level'] as String?,
      referenceText: json['reference_text'] as String?,
      expectedAnswer: json['expected_answer'] as String?,
      guideline: json['guideline'] as String?,
      timeLimit: json['time_limit'] as int? ?? 60,
      gradingCriteria: json['grading_criteria'] as Map<String, dynamic>?,
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
    'speaking_mode': speakingMode,
    'order_index': orderIndex,
    'difficulty_level': difficultyLevel,
    'reference_text': referenceText,
    'expected_answer': expectedAnswer,
    'guideline': guideline,
    'time_limit': timeLimit,
    'grading_criteria': gradingCriteria,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };

  // Validation helpers
  bool get isReadAloud => speakingMode == 'read_aloud';
  bool get isAnswerPrompt => speakingMode == 'answer_prompt';
  bool get isFreeSpeaking => speakingMode == 'free_speaking';

  bool get hasReferenceText => referenceText != null && referenceText!.isNotEmpty;
  bool get hasGuideline => guideline != null && guideline!.isNotEmpty;

  @override
  String toString() => 'SpeakingQuestion(id: $id, mode: $speakingMode)';
}