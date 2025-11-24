import 'package:flutter/material.dart';

class SpeakingResultDialog extends StatelessWidget {
  final Map<String, dynamic> result;

  const SpeakingResultDialog({required this.result, super.key});

  @override
  Widget build(BuildContext context) {
    final score = result['total_score'] as num? ?? 0;
    final feedback = result['detailed_feedback'] as String? ?? '';
    final strengths = result['strengths'] as List? ?? [];
    final mistakes = result['mistakes'] as List? ?? [];

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            score >= 70 ? Icons.check_circle : Icons.cancel,
            color: score >= 70 ? Colors.green : Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'Kết quả: ${score.toStringAsFixed(0)}/100',
            style: const TextStyle(fontSize: 20),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Detailed scores
            if (result['content_score'] != null) ...[
              _buildScoreRow('Nội dung', result['content_score'], 30),
              _buildScoreRow('Ngữ pháp', result['grammar_score'], 30),
              _buildScoreRow('Từ vựng', result['vocabulary_score'], 20),
              _buildScoreRow('Tổ chức', result['organization_score'], 20),
              const Divider(height: 24),
            ],

            // Feedback
            if (feedback.isNotEmpty) ...[
              const Text(
                'Nhận xét:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(feedback, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 16),
            ],

            // Strengths
            if (strengths.isNotEmpty) ...[
              const Text(
                '✅ Điểm mạnh:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
              ...strengths.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.green)),
                    Expanded(child: Text(s.toString())),
                  ],
                ),
              )),
              const SizedBox(height: 12),
            ],

            // Mistakes
            if (mistakes.isNotEmpty) ...[
              const Text(
                '❌ Lỗi cần sửa:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              ...mistakes.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.red)),
                    Expanded(child: Text(m.toString())),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Widget _buildScoreRow(String label, dynamic score, int maxScore) {
    final percentage = (score / maxScore * 100).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: score / maxScore,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                percentage >= 70 ? Colors.green : Colors.orange,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$score/$maxScore',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}