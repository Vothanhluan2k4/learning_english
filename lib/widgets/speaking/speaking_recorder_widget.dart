import 'package:flutter/material.dart';

class SpeakingRecorderWidget extends StatelessWidget {
  final bool speechEnabled;
  final bool isListening;
  final bool isPaused;
  final String transcript;
  final int timeLimit;
  final int secondsRecorded;
  final VoidCallback onStartListening;
  final VoidCallback onPauseListening;
  final VoidCallback onResumeListening;
  final VoidCallback onStopListening;
  final VoidCallback onSubmit;
  final VoidCallback? onReset; 

  const SpeakingRecorderWidget({
    required this.speechEnabled,
    required this.isListening,
    required this.isPaused,
    required this.transcript,
    required this.timeLimit,
    required this.secondsRecorded,
    required this.onStartListening,
    required this.onPauseListening,
    required this.onResumeListening,
    required this.onStopListening,
    required this.onSubmit,
    this.onReset,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final secondsRemaining = timeLimit - secondsRecorded;
    final isConverting = transcript.contains('Đang chuyển đổi');

    return Column(
      children: [
        // Transcript display
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isListening 
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
                    isListening ? (isPaused ? Icons.pause : Icons.mic) : Icons.mic_none,
                    color: isListening ? (isPaused ? Colors.orange : Colors.red) : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isListening
                          ? (isPaused ? 'Đã tạm dừng' : 'Đang ghi âm...')
                          : (isConverting ? 'Đang xử lý...' : 'Nội dung bạn nói:'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isListening
                            ? (isPaused ? Colors.orange : Colors.red)
                            : (isConverting ? Colors.blue.shade700 : Colors.black87),
                      ),
                    ),
                  ),
                  if (isListening && !isPaused || isConverting) ...[
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
        if (isListening) ...[
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

        // ✅ UPDATED: Control buttons during recording
        if (isListening) ...[
          // ✅ NEW: 3 buttons during recording
          Column(
            children: [
              // Row 1: Pause/Resume and Stop buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isPaused ? onResumeListening : onPauseListening,
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
                      onPressed: onStopListening,
                      icon: const Icon(Icons.check, size: 22),
                      label: const Text('Hoàn thành'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
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
              
              // ✅ Row 2: Reset button (full width)
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
          // ✅ Start recording button (when not recording)
          ElevatedButton.icon(
            onPressed: speechEnabled ? onStartListening : null,
            icon: const Icon(Icons.mic, size: 24),
            label: const Text('Bắt đầu ghi âm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: speechEnabled ? Colors.red : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
        
        const SizedBox(height: 16),

        // Submit button (after recording finished)
        if (transcript.isNotEmpty && !isListening && !isConverting) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send, size: 20),
              label: const Text('Nộp bài'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}