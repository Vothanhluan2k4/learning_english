import 'package:flutter/material.dart';

class TestSpeakingRecorder extends StatelessWidget {
  final String speakingMode;
  final int timeLimit;
  final bool isRecording;
  final bool isPaused;
  final int secondsRecorded;
  final String transcript;
  final bool recordingEnabled;
  final VoidCallback onStartRecording;
  final VoidCallback onPauseRecording;
  final VoidCallback onResumeRecording;
  final VoidCallback onStopRecording;
  final VoidCallback? onReset;

  const TestSpeakingRecorder({
    required this.speakingMode,
    required this.timeLimit,
    required this.isRecording,
    required this.isPaused,
    required this.secondsRecorded,
    required this.transcript,
    required this.recordingEnabled,
    required this.onStartRecording,
    required this.onPauseRecording,
    required this.onResumeRecording,
    required this.onStopRecording,
    this.onReset,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final secondsRemaining = timeLimit - secondsRecorded;
    final isConverting = transcript.contains('Đang chuyển đổi');
    final isSaving = transcript.contains('Đang lưu'); // ✅ ADD
    final isGrading = transcript.contains('Đang chấm'); // ✅ ADD

    return Column(
      children: [
        // Speaking mode badge
        _buildModeBadge(),
        const SizedBox(height: 16),

        // Transcript display
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRecording 
                  ? (isPaused ? Colors.orange : Colors.red)
                  : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isRecording ? (isPaused ? Icons.pause : Icons.mic) : Icons.mic_none,
                    color: isRecording ? (isPaused ? Colors.orange : Colors.red) : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isRecording
                          ? (isPaused ? 'Đã tạm dừng' : 'Đang ghi âm...')
                          : (isConverting ? 'Đang xử lý...' : 'Nội dung bạn nói:'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isRecording
                            ? (isPaused ? Colors.orange : Colors.red)
                            : (isConverting ? Colors.blue.shade700 : Colors.black87),
                      ),
                    ),
                  ),
                  if (isRecording && !isPaused || isConverting) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          isConverting ? Colors.blue : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                transcript.isEmpty ? 'Nhấn nút mic để bắt đầu...' : transcript,
                style: TextStyle(
                  fontSize: 15,
                  color: transcript.isEmpty ? Colors.grey.shade500 : Colors.black87,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Timer
        if (isRecording) ...[
          Text(
            '${secondsRemaining}s',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: secondsRemaining <= 10 ? Colors.red : Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Control buttons
        if (isRecording) ...[
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isPaused ? onResumeRecording : onPauseRecording,
                      icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 22),
                      label: Text(isPaused ? 'Tiếp tục' : 'Tạm dừng'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPaused ? Colors.green : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onStopRecording,
                      icon: const Icon(Icons.check, size: 22),
                      label: const Text('Hoàn thành'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (onReset != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Bắt đầu lại'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ] else if (!isConverting) ...[
          ElevatedButton.icon(
            onPressed: recordingEnabled ? onStartRecording : null,
            icon: const Icon(Icons.mic, size: 24),
            label: const Text('Bắt đầu ghi âm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: recordingEnabled ? Colors.red : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],

        // ✅ ADD: Status indicator
        if (isConverting || isSaving || isGrading) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isConverting
                      ? 'Đang nhận diện giọng nói...'
                      : isSaving
                          ? 'Đang lưu bài làm...'
                          : 'Đang chấm điểm bằng AI...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModeBadge() {
    Color bgColor;
    String label;
    IconData icon;

    switch (speakingMode) {
      case 'read_aloud':
        bgColor = Colors.blue.shade50;
        label = 'Đọc đoạn văn';
        icon = Icons.book;
        break;
      case 'answer_prompt':
        bgColor = Colors.green.shade50;
        label = 'Trả lời câu hỏi';
        icon = Icons.question_answer;
        break;
      case 'free_speaking':
        bgColor = Colors.purple.shade50;
        label = 'Nói tự do';
        icon = Icons.record_voice_over;
        break;
      default:
        bgColor = Colors.grey.shade50;
        label = 'Speaking';
        icon = Icons.mic;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bgColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${timeLimit}s',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}