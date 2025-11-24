import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/test_question.dart';
import 'test_speaking_recorder.dart';

class TestSpeakingQuestionCard extends StatelessWidget {
  final TestQuestion question;
  final int questionNumber;
  final int totalQuestions;
  final bool recordingEnabled;
  final bool isRecording;
  final bool isPaused;
  final int secondsRecorded;
  final String transcript;
  final VoidCallback onStartRecording;
  final VoidCallback onPauseRecording;
  final VoidCallback onResumeRecording;
  final VoidCallback onStopRecording;
  final VoidCallback? onReset;

  const TestSpeakingQuestionCard({
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.recordingEnabled,
    required this.isRecording,
    required this.isPaused,
    required this.secondsRecorded,
    required this.transcript,
    required this.onStartRecording,
    required this.onPauseRecording,
    required this.onResumeRecording,
    required this.onStopRecording,
    this.onReset,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Câu $questionNumber/$totalQuestions',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 4),
                  Text(
                    question.speakingModeDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Instruction
        if (question.instruction != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.instruction!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Question text
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: MarkdownBody(
            data: question.questionText ?? '',
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Reference text (for read_aloud mode)
        if (question.speakingMode == 'read_aloud' && question.referenceText != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đọc đoạn văn sau:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  question.referenceText!,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Expected answer (for reference - collapsible)
        if (question.expectedAnswer != null) ...[
          ExpansionTile(
            leading: Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
            title: Text(
              'Xem ví dụ trả lời',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade900,
              ),
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.amber.shade50,
                child: Text(
                  question.expectedAnswer!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.amber.shade900,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Guideline
        if (question.guideline != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Hướng dẫn:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  question.guideline!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade900,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Recorder widget
        TestSpeakingRecorder(
          speakingMode: question.speakingMode ?? 'free_speaking',
          timeLimit: question.timeLimit ?? 60,
          isRecording: isRecording,
          isPaused: isPaused,
          secondsRecorded: secondsRecorded,
          transcript: transcript,
          recordingEnabled: recordingEnabled,
          onStartRecording: onStartRecording,
          onPauseRecording: onPauseRecording,
          onResumeRecording: onResumeRecording,
          onStopRecording: onStopRecording,
          onReset: onReset,
        ),
      ],
    );
  }
}