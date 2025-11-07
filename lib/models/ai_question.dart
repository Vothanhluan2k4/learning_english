/// Model cho câu hỏi AI-generated
class AiQuestion {
  final String id;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  AiQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  /// Create from JSON
  factory AiQuestion.fromJson(Map<String, dynamic> json) {
    // Validate required fields
    if (json['question'] == null || json['question'].toString().trim().isEmpty) {
      throw ArgumentError('Question text is required');
    }

    if (json['options'] == null || json['options'] is! List) {
      throw ArgumentError('Options must be a list');
    }

    final options = List<String>.from(json['options']);
    
    if (options.length != 4) {
      throw ArgumentError('Must have exactly 4 options, got ${options.length}');
    }

    final correctAnswer = json['correct_answer']?.toString().trim() ?? '';
    
    if (correctAnswer.isEmpty) {
      throw ArgumentError('correct_answer is required');
    }

    if (!options.contains(correctAnswer)) {
      throw ArgumentError(
        'correct_answer "$correctAnswer" phải nằm trong options $options'
      );
    }

    return AiQuestion(
      id: json['id']?.toString() ?? 'q_${DateTime.now().millisecondsSinceEpoch}',
      question: json['question'].toString().trim(),
      options: options,
      correctAnswer: correctAnswer,
      explanation: json['explanation']?.toString().trim() ?? '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
    };
  }

  /// Convert to Supabase format
  Map<String, dynamic> toSupabaseJson({
    required String sessionId,
    required int orderIndex,
  }) {
    return {
      'session_id': sessionId,
      'question_text': question,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'order_index': orderIndex,
    };
  }

  /// Create from Supabase
  factory AiQuestion.fromSupabase(Map<String, dynamic> data) {
    return AiQuestion(
      id: data['id']?.toString() ?? '',
      question: data['question_text']?.toString() ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correct_answer']?.toString() ?? '',
      explanation: data['explanation']?.toString() ?? '',
    );
  }

  @override
  String toString() {
    return 'AiQuestion(id: $id, question: "${question.substring(0, 30)}...")';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is AiQuestion &&
        other.id == id &&
        other.question == question &&
        _listEquals(other.options, options) &&
        other.correctAnswer == correctAnswer;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        question.hashCode ^
        options.hashCode ^
        correctAnswer.hashCode;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Copy with modifications
  AiQuestion copyWith({
    String? id,
    String? question,
    List<String>? options,
    String? correctAnswer,
    String? explanation,
  }) {
    return AiQuestion(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
    );
  }

  /// Check if answer is correct
  bool isCorrect(String userAnswer) {
    return userAnswer.trim() == correctAnswer.trim();
  }

  /// Get option letter (A, B, C, D)
  String getOptionLetter(int index) {
    if (index < 0 || index >= options.length) return '';
    return String.fromCharCode(65 + index); // 65 = 'A'
  }

  /// Get correct answer letter
  String get correctAnswerLetter {
    final index = options.indexOf(correctAnswer);
    return index >= 0 ? getOptionLetter(index) : '';
  }
}