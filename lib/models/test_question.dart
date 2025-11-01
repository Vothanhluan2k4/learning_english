import 'dart:convert';

class TestQuestion {
  final String id;
  final String testId;
  final String? groupId;
  final String? questionText;
  final String questionType; // multiple_choice, true_false, fill_blank...
  final String mediaType; // image, audio, text, none
  final String? mediaUrl;
  final dynamic options; // Có thể là List, Map hoặc null
  final String correctAnswer; // Dạng text hoặc JSON (cho fill_blank)
  final String? explanation;
  final int? orderInTest;
  final String? instruction;
  final String difficulty;

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
    };
  }

  /// ✅ Chuẩn hóa đáp án hiển thị cho UI
  List<String> getDisplayOptions() {
    if (questionType == 'fill_blank') {
      // Câu điền khuyết không có danh sách lựa chọn
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
