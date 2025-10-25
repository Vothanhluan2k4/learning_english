import 'test_question.dart';

class QuestionGroup {
  final String id;
  final String testId;
  final String? title;
  final String? instruction;
  final String? mediaType;
  final String? mediaUrl;
  final String? content;
  final int? orderInTest;
  final List<TestQuestion> testQuestions;

  QuestionGroup({
    required this.id,
    required this.testId,
    this.title,
    this.instruction,
    this.mediaType,
    this.mediaUrl,
    this.content,
    this.orderInTest,
    required this.testQuestions,
  });

  factory QuestionGroup.fromJson(Map<String, dynamic> json) {
    return QuestionGroup(
      id: json['id'] as String,
      testId: json['test_id'] as String,
      title: json['title'] as String?,
      instruction: json['instruction'] as String?,
      mediaType: json['media_type'] as String?,
      mediaUrl: json['media_url'] as String?,
      content: json['content'] as String?,
      orderInTest: json['order_in_test'] as int?,
      testQuestions: (json['test_questions'] as List<dynamic>? ?? [])
          .map((q) => TestQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'test_id': testId,
      'title': title,
      'instruction': instruction,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'content': content,
      'order_in_test': orderInTest,
      'test_questions': testQuestions.map((q) => q.toJson()).toList(),
    };
  }
}
