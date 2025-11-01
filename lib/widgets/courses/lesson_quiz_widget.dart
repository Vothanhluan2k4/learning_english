import 'package:flutter/material.dart';
import 'package:learning_english/models/lesson_course.dart';
import 'package:learning_english/widgets/courses/section_content_widget.dart';
import '../../models/lesson_question.dart';
import '../../models/question_option.dart';
import '../../services/lesson_section_service.dart';

class LessonQuizWidget extends StatefulWidget {
  final List<Map<String, dynamic>> questions;

  const LessonQuizWidget({
    required this.questions,
    super.key,
  });

  @override
  State<LessonQuizWidget> createState() => _LessonQuizWidgetState();
}

class _LessonQuizWidgetState extends State<LessonQuizWidget> {
  final _sectionService = LessonSectionService();

  // ✅ Track selected answer cho mỗi question
  late Map<String, String?> _selectedAnswers;
  // ✅ Track submitted questions
  late Map<String, bool> _submittedQuestions;

  @override
  void initState() {
    super.initState();
    _selectedAnswers = {};
    _submittedQuestions = {};

    // Initialize
    for (var q in widget.questions) {
      final question = q['question'] as LessonQuestion;
      _selectedAnswers[question.id] = null;
      _submittedQuestions[question.id] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.questions.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final question = data['question'] as LessonQuestion;
          final options = data['options'] as List<QuestionOption>;
          final isSubmitted = _submittedQuestions[question.id] ?? false;
          final selectedAnswer = _selectedAnswers[question.id];

          return _buildQuestionCard(
            index + 1,
            question,
            options,
            isSubmitted,
            selectedAnswer,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildQuestionCard(
    int number,
    LessonQuestion question,
    List<QuestionOption> options,
    bool isSubmitted,
    String? selectedAnswer,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Question header
            Row(
              children: [
                Icon(
                  _sectionService.getQuestionIcon(question.questionType),
                  size: 18,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Câu $number: ${question.questionText}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ Options
            ...options.map((option) {
              final isSelected = selectedAnswer == option.id;
              final isCorrect = option.isCorrect;
              final isAnswered = isSubmitted;

              // ✅ Color logic
              Color? backgroundColor;
              Color? borderColor;
              Color? textColor;

              if (isAnswered) {
                if (isCorrect) {
                  backgroundColor = Colors.green.shade50;
                  borderColor = Colors.green.shade400;
                  textColor = Colors.green.shade700;
                } else if (isSelected && !isCorrect) {
                  backgroundColor = Colors.red.shade50;
                  borderColor = Colors.red.shade400;
                  textColor = Colors.red.shade700;
                } else {
                  backgroundColor = Colors.grey.shade50;
                  borderColor = Colors.grey.shade300;
                  textColor = Colors.grey.shade600;
                }
              } else {
                if (isSelected) {
                  backgroundColor = Colors.blue.shade50;
                  borderColor = Colors.blue.shade400;
                  textColor = Colors.blue.shade700;
                } else {
                  backgroundColor = Colors.grey.shade50;
                  borderColor = Colors.grey.shade300;
                  textColor = Colors.grey.shade700;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: isAnswered ? null : () {
                    setState(() {
                      _selectedAnswers[question.id] = option.id;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor ?? Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // ✅ Radio button
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: borderColor ?? Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected ? borderColor : Colors.transparent,
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),

                        // ✅ Option text
                        Expanded(
                          child: Text(
                            option.optionText,
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor,
                              fontWeight: isAnswered && isCorrect
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),

                        // ✅ Result icon
                        if (isAnswered) ...[
                          const SizedBox(width: 8),
                          if (isCorrect)
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 20,
                            )
                          else if (isSelected && !isCorrect)
                            Icon(
                              Icons.cancel,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            // ✅ Submit button
            if (!isSubmitted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedAnswer == null
                      ? null
                      : () {
                          setState(() {
                            _submittedQuestions[question.id] = true;
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Kiểm tra đáp án',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            // ✅ Explanation (sau khi submit)
            if (isSubmitted) ...[
              const SizedBox(height: 16),
              // Show correct answer info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Đáp án đúng',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      options
                          .firstWhere((o) => o.isCorrect)
                          .optionText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ Explanation
              if (question.explanation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.explanation!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ✅ Retry button
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedAnswers[question.id] = null;
                      _submittedQuestions[question.id] = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue.shade700),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    'Làm lại',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ✅ Tab 1: Ôn tập
  Widget _buildReviewTab(
    LessonCourse? lesson,
    List sections,
    Map<String, dynamic> content,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ...existing lesson info...

          // ✅ Sections content
          if (sections.isEmpty)
            Center(
              child: Text(
                'Không có nội dung ôn tập',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            )
          else
            ...sections.asMap().entries.map((entry) {
              final section = entry.value;
              final sectionContent = content[section.id] as Map?;
              final medias = sectionContent?['medias'] as List? ?? [];

              if (section.sectionType == 'quiz') {
                return const SizedBox.shrink();
              }

              return SectionContentWidget(
                section: section,
                medias: medias.cast(),
                questionsWithOptions: [],
                allowReplay: true, // ✅ ÔN TẬP: cho phép phát lại
              );
            }).toList(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}