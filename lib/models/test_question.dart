import 'dart:convert';

class TestQuestion {
  final String id;
  final String testId;
  final String? groupId;
  final String? questionText;
  final String questionType; // multiple_choice, true_false, fill_blank, essay, speaking ✅ ADD
  final String mediaType; // image, audio, text, none
  final String? mediaUrl;
  final dynamic options;
  final String correctAnswer;
  final String? explanation;
  final int? orderInTest;
  final String? instruction;
  final String difficulty;
  final int? minWords;
  final int? maxWords;
  final String? guideline;
  
  // ✅ NEW: Speaking-specific fields
  final String? speakingMode; // read_aloud, answer_prompt, free_speaking
  final String? referenceText; // For read_aloud mode
  final String? expectedAnswer; // For answer_prompt/free_speaking
  final int? timeLimit; // Time limit in seconds
  final Map<String, dynamic>? rubric; // Grading rubric

  TestQuestion({
    required this.id,
    required this.testId,
    this.groupId,
    this.questionText,
    this.questionType = 'multiple_choice',
    this.mediaType = 'none',
    this.mediaUrl,
    this.options,
    required this.correctAnswer,
    this.explanation,
    this.orderInTest,
    this.instruction,
    this.difficulty = 'medium',
    this.minWords,
    this.maxWords,
    this.guideline,
    this.speakingMode,
    this.referenceText,
    this.expectedAnswer,
    this.timeLimit,
    this.rubric,
  });

  factory TestQuestion.fromJson(Map<String, dynamic> json) {
    dynamic parsedOptions;
    final raw = json['options'];

    if (raw is String && raw.isNotEmpty) {
      try {
        parsedOptions = jsonDecode(raw);
      } catch (_) {
        parsedOptions = raw;
      }
    } else {
      parsedOptions = raw;
    }

    // ✅ Parse rubric
    Map<String, dynamic>? parsedRubric;
    if (json['rubric'] != null) {
      if (json['rubric'] is Map) {
        parsedRubric = Map<String, dynamic>.from(json['rubric']);
      } else if (json['rubric'] is String) {
        try {
          parsedRubric = jsonDecode(json['rubric']);
        } catch (_) {}
      }
    }

    return TestQuestion(
      id: json['id'] ?? '',
      testId: json['test_id'] ?? '',
      groupId: json['group_id'],
      questionText: json['question_text'],
      questionType: json['question_type'] ?? 'multiple_choice',
      mediaType: json['media_type'] ?? 'none',
      mediaUrl: json['media_url'],
      options: parsedOptions,
      correctAnswer: json['correct_answer'] ?? '',
      explanation: json['explanation'],
      orderInTest: json['order_in_test'],
      instruction: json['instruction'],
      difficulty: json['difficulty'] ?? 'medium',
      minWords: json['min_words'] as int?,
      maxWords: json['max_words'] as int?,
      guideline: json['guideline'] as String?,
      speakingMode: json['speaking_mode'] as String?,
      referenceText: json['reference_text'] as String?,
      expectedAnswer: json['expected_answer'] as String?,
      timeLimit: json['time_limit'] as int?,
      rubric: parsedRubric,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'test_id': testId,
      'group_id': groupId,
      'question_text': questionText,
      'question_type': questionType,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'order_in_test': orderInTest,
      'instruction': instruction,
      'difficulty': difficulty,
      'min_words': minWords,
      'max_words': maxWords,
      'guideline': guideline,
      'speaking_mode': speakingMode,
      'reference_text': referenceText,
      'expected_answer': expectedAnswer,
      'time_limit': timeLimit,
      'rubric': rubric,
    };
  }

  // ✅ Helper: Check if this is a speaking question
  bool get isSpeaking => questionType == 'speaking';

  // ✅ Helper: Get speaking mode display text
  String get speakingModeDisplay {
    switch (speakingMode) {
      case 'read_aloud':
        return 'Đọc đoạn văn';
      case 'answer_prompt':
        return 'Trả lời câu hỏi';
      case 'free_speaking':
        return 'Nói tự do';
      default:
        return 'Speaking';
    }
  }

  /// ✅ Chuẩn hóa đáp án hiển thị cho UI
  List<String> getDisplayOptions() {
    if (questionType == 'fill_blank' || questionType == 'speaking') {
      // Câu điền khuyết và câu hỏi nói không có danh sách lựa chọn
      return [];
    }

    if (options == null) return [];

    if (options is List) {
      return options.cast<String>();
    } else if (options is Map) {
      return (options as Map).entries
          .map((e) => "${e.key}. ${e.value}")
          .toList()
          .cast<String>();
    }

    return [];
  }

  /// ✅ Với câu điền khuyết — tách text thành phần hiển thị
  List<String> getFillBlankParts() {
    if (questionType != 'fill_blank' || questionText == null) return [];
    // Giả định chỗ trống ký hiệu là ___
    return questionText!.split("___");
  }

  /// ✅ Đáp án đúng (dạng list cho fill_blank nhiều chỗ)
  List<String> getCorrectAnswers() {
    try {
      final decoded = jsonDecode(correctAnswer);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return [correctAnswer];
  }
}
