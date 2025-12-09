import 'dart:async';
import 'package:flutter/material.dart';
import 'package:learning_english/core/utils/parse_feedbackAI.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart'; 
import '../../models/speaking_question.dart';
import '../../models/lesson_section.dart';
import '../../services/speaking_lesson_service.dart';
import '../../services/ai/ai_grading_service.dart';
import '../../services/audio_recorder_service.dart';
import '../../services/ai/groq_speech_service.dart';
import '../../services/speaking_submission_service.dart'; 
import '../../services/user_attempt_service.dart'; 
import '../../widgets/speaking/speaking_recorder_widget.dart';
import '../../widgets/speaking/speaking_result_dialog.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class SpeakingLessonScreen extends StatefulWidget {
  final String lessonId;

  const SpeakingLessonScreen({required this.lessonId, super.key});

  @override
  State<SpeakingLessonScreen> createState() => _SpeakingLessonScreenState();
}

class _SpeakingLessonScreenState extends State<SpeakingLessonScreen> {
  final _speakingService = SpeakingQuestionService();
  final _aiService = AiGradingService();
  final _audioRecorder = AudioRecorderService();
  final _groqSpeech = GroqSpeechService();
  final _submissionService = SpeakingSubmissionService(); 
  final _attemptService = UserAttemptService(); 
  final _parseFeedbackAI = ParseFeedbackAI();

  bool _isLoading = true;
  List<SectionWithQuestions> _sections = [];
  
  String? _activeQuestionId;
  String? _attemptId; 
  
  bool _recordingEnabled = false;
  String _currentTranscript = '';
  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentAudioPath;
  
  // ✅ Track completed questions
  Set<String> _completedQuestionIds = {};
  Map<String, Map<String, dynamic>> _questionResults = {};
  Map<String, int> _questionTimeSpent = {}; // ✅ Track time per question
  
  Timer? _recordingTimer;
  int _secondsRecorded = 0;

  bool _attemptFinished = false; 
  bool _progressInitialized = false; 

  bool _isReviewMode = false; 
  Map<String, Map<String, dynamic>> _previousAnswers = {}; 
  final Map<String, AudioPlayer> _audioPlayers = {}; 

  @override
  void initState() {
    super.initState();
    _initRecording();
    _loadSections();
  }

  Future<void> _initRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      
      if (!hasPermission) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          debugPrint('❌ Microphone permission denied');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cần cấp quyền microphone để sử dụng tính năng này'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _recordingEnabled = false);
          return;
        }
      }

      setState(() => _recordingEnabled = true);
      debugPrint('✅ Recording enabled');
    } catch (e) {
      debugPrint('❌ Error initializing recording: $e');
      setState(() => _recordingEnabled = false);
    }
  }

  Future<void> _loadSections() async {
    try {
      final sections = await _speakingService.fetchLessonSectionsWithQuestions(widget.lessonId);
      
      final completedAttempt = await _submissionService.getLatestCompletedAttempt(
        lessonId: widget.lessonId,
      );

      if (completedAttempt != null) {
        debugPrint('📖 Found completed attempt: ${completedAttempt['id']}');
        debugPrint('   Score: ${completedAttempt['score']}, Passed: ${completedAttempt['is_passed']}');
        
        final answers = await _submissionService.getAttemptAnswers(
          attemptId: completedAttempt['id'],
        );

        final shouldReview = await _showReviewDialog(completedAttempt);
        
        if (shouldReview == true) {
          setState(() {
            _isReviewMode = true;
            _previousAnswers = answers;
            _attemptId = completedAttempt['id'];
            _attemptFinished = true;
            _sections = sections;
            _isLoading = false;
          });

          // ✅ UPDATED: Parse ai_feedback properly
          for (var section in sections) {
            if (section.isSpeakingSection) {
              for (var question in section.questions) {
                if (answers.containsKey(question.id)) {
                  _completedQuestionIds.add(question.id);
                  
                  final answer = answers[question.id]!;
                  Map<String, dynamic> feedbackData = {};
                  
                  try {
                    final aiFeedback = answer['ai_feedback'];
                                       
                    if (aiFeedback is Map) {
                      feedbackData = Map<String, dynamic>.from(aiFeedback);
                      debugPrint('✅ Feedback is Map with keys: ${feedbackData.keys.join(', ')}');
                    } else if (aiFeedback is String) {
                      // ✅ Parse string to Map
                      feedbackData =  _parseFeedbackAI.parseAiFeedbackString(aiFeedback);
                      debugPrint('✅ Parsed feedback keys: ${feedbackData.keys.join(', ')}');
                    }
                  } catch (e, stack) {
                    debugPrint('❌ Error parsing ai_feedback: $e');
                    debugPrint('Stack: $stack');
                  }
                  
                  // ✅ Build complete result with all fields
                  _questionResults[question.id] = {
                    'total_score': answer['ai_score'] ?? feedbackData['total_score'] ?? 0,
                    'transcript': answer['user_answer'] ?? '',
                    'audio_url': answer['audio_url'],
                    'content_score': feedbackData['content_score'],
                    'grammar_score': feedbackData['grammar_score'],
                    'vocabulary_score': feedbackData['vocabulary_score'],
                    'organization_score': feedbackData['organization_score'],
                    // 'pronunciation_score': feedbackData['pronunciation_score'],
                    // 'fluency_score': feedbackData['fluency_score'],
                    'detailed_feedback': feedbackData['detailed_feedback'],
                    'mistakes': feedbackData['mistakes'] ?? [],
                    'strengths': feedbackData['strengths'] ?? [],
                    'speaking_mode': feedbackData['speaking_mode'],
                    'provider': feedbackData['provider'],
                  };
                }
              }
            }
          }

          debugPrint('✅ Review mode: ${_completedQuestionIds.length} questions loaded');
          return;
        } else {
          _isReviewMode = false;
          _attemptFinished = false;
        }
      }

      // ✅ Normal mode: Create or continue attempt
      final attempt = await _attemptService.getCurrentAttempt(lessonId: widget.lessonId);
      
      if (attempt != null) {
        _attemptId = attempt.id;
        _attemptFinished = attempt.finishedAt != null;
        debugPrint('📝 Continuing attempt: ${attempt.id} (finished: $_attemptFinished)');
      } else {
        final newAttempt = await _attemptService.createAttempt(lessonId: widget.lessonId);
        _attemptId = newAttempt?.id;
        _attemptFinished = false;
        debugPrint('🆕 Created new attempt: $_attemptId');
      }

      setState(() {
        _sections = sections;
        _isLoading = false;
      });
      
      debugPrint('📊 Loaded ${_sections.length} sections');
    } catch (e) {
      debugPrint('❌ Error loading sections: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải bài học: $e')),
        );
      }
    }
  }

  /// ✅ NEW: Show review dialog
  Future<bool?> _showReviewDialog(Map<String, dynamic> attempt) async {
    final score = (attempt['score'] as num?)?.toDouble() ?? 0;
    final isPassed = attempt['is_passed'] as bool? ?? false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isPassed ? Icons.check_circle : Icons.info,
              color: isPassed ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 10),
            const Text('Đã hoàn thành'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn đã hoàn thành bài này với điểm:',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPassed ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPassed ? Colors.green.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${score.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isPassed ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  Text(
                    '/100',
                    style: TextStyle(
                      fontSize: 20,
                      color: isPassed ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPassed ? ' Đạt yêu cầu' : ' Chưa đạt yêu cầu',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPassed ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.refresh),
            label: const Text('Làm lại'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade700,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.visibility),
            label: const Text('Xem lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    // ✅ Dispose audio players
    for (var player in _audioPlayers.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Speaking Practice')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Speaking Practice')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.library_books_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('Không có nội dung bài học', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speaking Practice'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          // ✅ Show completion progress
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_completedQuestionIds.length}/${_getTotalQuestions()} ✓',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length + 1, 
        itemBuilder: (context, index) {
          if (index == _sections.length) {
            // ✅ Submit all button at the end
            return _buildSubmitAllButton();
          }

          final section = _sections[index];
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              _buildSectionHeader(section.section, index + 1),
              const SizedBox(height: 16),
              
              // Section content
              if (section.isTextSection) ...[
                _buildTextContent(section.section),
              ] else if (section.isSpeakingSection) ...[
                if (section.hasSpeakingQuestions)
                  ...section.questions.map((question) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildSpeakingQuestion(question, section),
                  ))
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('Chưa có câu hỏi Speaking cho phần này'),
                    ),
                  ),
              ] else ...[
                _buildGenericContent(section.section),
              ],
              
              if (index < _sections.length - 1) ...[
                const SizedBox(height: 25),
                const Divider(thickness: 2),
                const SizedBox(height: 25),
              ],
            ],
          );
        },
      ),
    );
  }

  // ✅ Get total number of questions
  int _getTotalQuestions() {
    return _sections
        .where((s) => s.isSpeakingSection)
        .fold(0, (sum, s) => sum + s.questions.length);
  }

  // ✅ Section header with index
  Widget _buildSectionHeader(LessonSection section, int sectionNumber) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (section.sectionType) {
      case 'text':
        bgColor = Colors.grey.shade50;
        textColor = Colors.blue;
        icon = Icons.description;
        break;
      case 'speaking':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        icon = Icons.mic;
        break;
      case 'quiz':
        bgColor = Colors.purple.shade50;
        textColor = Colors.purple.shade700;
        icon = Icons.quiz;
        break;
      case 'video':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        icon = Icons.video_library;
        break;
      case 'audio':
        bgColor = Colors.teal.shade50;
        textColor = Colors.teal.shade700;
        icon = Icons.headphones;
        break;
      default:
        bgColor = Colors.grey.shade50;
        textColor = Colors.grey.shade700;
        icon = Icons.article;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$sectionNumber',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.sectionTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  section.sectionType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Text section content
  Widget _buildTextContent(LessonSection section) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Hướng dẫn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: section.content ?? 'Không có nội dung',
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.black87,
              ),
              listBullet: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Generic content
  Widget _buildGenericContent(LessonSection section) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.blue.shade700),
          const SizedBox(height: 12),
          Text(
            section.content ?? 'Nội dung đang được cập nhật',
            style: const TextStyle(fontSize: 15, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ✅ Speaking question card
  Widget _buildSpeakingQuestion(SpeakingQuestion question, SectionWithQuestions section) {
    final isActive = _activeQuestionId == question.id;
    final isCompleted = _completedQuestionIds.contains(question.id);
    final result = _questionResults[question.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? Colors.red.shade300
              : (isCompleted ? Colors.green.shade300 : Colors.grey.shade300),
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionHeader(question, isCompleted),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuestionContent(question),
                
                if (isCompleted) ...[
                  const SizedBox(height: 16),
                  _buildQuestionResultWithAudio(question, result!),
                ] else if (!_isReviewMode) ...[
                  const SizedBox(height: 20),
                  
                  if (isActive) ...[
                    SpeakingRecorderWidget(
                      speechEnabled: _recordingEnabled,
                      isListening: _isRecording,
                      isPaused: _isPaused,
                      transcript: _currentTranscript,
                      timeLimit: question.timeLimit,
                      secondsRecorded: _secondsRecorded,
                      onStartListening: () => _startRecording(question),
                      onPauseListening: _pauseRecording,
                      onResumeListening: _resumeRecording,
                      onStopListening: _stopRecording,
                      onSubmit: () => _submitAnswer(question),
                      onReset: () => _resetRecordingDuringSession(question), // ✅ NEW: Reset during recording
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _activeQuestionId = question.id;
                            _currentTranscript = '';
                            _currentAudioPath = null;
                            _secondsRecorded = 0;
                          });
                        },
                        icon: const Icon(Icons.mic),
                        label: const Text('Bắt đầu trả lời'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuestionHeader(SpeakingQuestion question, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.shade100 : Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          _buildModeBadge(question),
        ],
      ),
    );
  }

  Widget _buildModeBadge(SpeakingQuestion question) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    if (question.isReadAloud) {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      icon = Icons.book;
      label = 'Đọc theo đoạn văn';
    } else if (question.isAnswerPrompt) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      icon = Icons.question_answer;
      label = 'Trả lời câu hỏi';
    } else {
      bgColor = Colors.purple.shade50;
      textColor = Colors.purple.shade700;
      icon = Icons.record_voice_over;
      label = 'Nói tự do';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildQuestionContent(SpeakingQuestion question) {
    if (question.isReadAloud) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Đọc to đoạn văn sau:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(question.referenceText ?? '', style: const TextStyle(fontSize: 15, height: 1.6)),
          ),
        ],
      );
    } else if (question.isAnswerPrompt) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Text(question.questionText, style: const TextStyle(fontSize: 15, height: 1.5)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Text(question.questionText, style: const TextStyle(fontSize: 15, height: 1.5)),
      );
    }
  }

  /// ✅ NEW: Question result with audio playback
  Widget _buildQuestionResultWithAudio(SpeakingQuestion question, Map<String, dynamic> result) {
    // Initialize audio player for this question if not exists
    if (!_audioPlayers.containsKey(question.id)) {
      _audioPlayers[question.id] = AudioPlayer();
    }

    final totalScore = (result['total_score'] as num).toInt();
    final player = _audioPlayers[question.id]!;

    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Đã hoàn thành',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$totalScore/100',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // ✅ Transcript
          _buildResultRow(
            Icons.text_fields,
            'Transcript:',
            result['transcript'] ?? 'Không có transcript',
          ),

          const SizedBox(height: 12),

          // ✅ Audio playback (if in review mode and audio exists)
          if (_isReviewMode && _previousAnswers[question.id]?['audio_url'] != null) ...[
            _buildAudioPlayer(player, _previousAnswers[question.id]!['audio_url']),
            const SizedBox(height: 12),
          ],

          const Divider(height: 24),
          _buildFeedbackSection(result),
        ],
      ),
    );
  }

  /// ✅ NEW: Audio player widget
  Widget _buildAudioPlayer(AudioPlayer player, String audioUrl) {
    return StreamBuilder<PlayerState>(
      stream: player.onPlayerStateChanged,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data == PlayerState.playing;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () async {
                  if (isPlaying) {
                    await player.pause();
                  } else {
                    await player.play(UrlSource(audioUrl));
                  }
                },
                icon: Icon(
                  isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 40,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPlaying ? 'Đang phát...' : 'Nghe lại bài nói',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    StreamBuilder<Duration>(
                      stream: player.onPositionChanged,
                      builder: (context, posSnapshot) {
                        final position = posSnapshot.data ?? Duration.zero;
                        return StreamBuilder<Duration?>(
                          stream: player.onDurationChanged,
                          builder: (context, durSnapshot) {
                            final duration = durSnapshot.data ?? Duration.zero;
                            return Text(
                              '${_formatDuration(position)} / ${_formatDuration(duration)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ✅ NEW: Format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// ✅ NEW: Result row helper
  Widget _buildResultRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
Widget _buildFeedbackSection(Map<String, dynamic> result) {
  // ✅ Helper to safely get numeric value
  num? getScore(String key) {
    final value = result[key];
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  // ✅ Helper to safely get string
  String? getString(String key) {
    final value = result[key];
    if (value == null) return null;
    return value.toString();
  }

  // ✅ Helper to safely get list
  List<String> getList(String key) {
    final value = result[key];
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  // ✅ Define max scores for each category
  const Map<String, int> maxScores = {
    'content_score': 30,
    'grammar_score': 30,
    'vocabulary_score': 20,
    'organization_score': 20,
    'pronunciation_score': 20,
    'fluency_score': 20,
  };

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ✅ Header
      Row(
        children: [
          Icon(Icons.analytics, color: Colors.blue.shade700, size: 18),
          const SizedBox(width: 8),
          Text(
            'Đánh giá chi tiết',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      
      // ✅ Display scores with dynamic max values
      if (getScore('content_score') != null)
        _buildScoreRow('Nội dung', getScore('content_score')!, maxScore: maxScores['content_score']!),
      
      if (getScore('grammar_score') != null)
        _buildScoreRow('Ngữ pháp', getScore('grammar_score')!, maxScore: maxScores['grammar_score']!),
      
      if (getScore('vocabulary_score') != null)
        _buildScoreRow('Từ vựng', getScore('vocabulary_score')!, maxScore: maxScores['vocabulary_score']!),
      
      if (getScore('organization_score') != null)
        _buildScoreRow('Tổ chức ý', getScore('organization_score')!, maxScore: maxScores['organization_score']!),
      
      if (getScore('pronunciation_score') != null)
        _buildScoreRow('Phát âm', getScore('pronunciation_score')!, maxScore: maxScores['pronunciation_score']!),
      
      if (getScore('fluency_score') != null)
        _buildScoreRow('Lưu loát', getScore('fluency_score')!, maxScore: maxScores['fluency_score']!),
      
      // ✅ Strengths
      if (getList('strengths').isNotEmpty) ...[
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.star, color: Colors.yellow.shade700, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Điểm mạnh:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...getList('strengths').map((strength) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.green.shade700)),
                        Expanded(
                          child: Text(
                            strength,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ],

      // ✅ Detailed feedback text
      if (getString('detailed_feedback')?.isNotEmpty == true) ...[
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.feedback, color: Colors.blue.shade700, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhận xét:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    getString('detailed_feedback')!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.grey.shade800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      
      
      
      // ✅ Mistakes
      if (getList('mistakes').isNotEmpty) ...[
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.orange.shade700, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cần cải thiện:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...getList('mistakes').map((mistake) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.orange.shade700)),
                        Expanded(
                          child: Text(
                            mistake,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ],
    ],
  );
}

  /// ✅ NEW: Score row
  Widget _buildScoreRow(String label, dynamic score, {required int maxScore}) {
    final scoreValue = (score as num).toDouble();
    final color = scoreValue >= 80
        ? Colors.green
        : scoreValue >= 60
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.shade200),
            ),
            child: Text(
              '${scoreValue.toStringAsFixed(0)}/$maxScore',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitAllButton() {
    if (_isReviewMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _retryLesson,
                icon: const Icon(Icons.refresh),
                label: const Text('Làm lại bài học', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// ✅ NEW: Calculate average score
  double _calculateAverageScore() {
    if (_questionResults.isEmpty) return 0.0;
    
    final totalScore = _questionResults.values.fold<double>(
      0,
      (sum, r) => sum + (r['total_score'] as num).toDouble(),
    );
    
    return totalScore / _questionResults.length;
  }

  /// ✅ NEW: Retry lesson
  Future<void> _retryLesson() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Làm lại bài học?'),
        content: const Text(
          'Bạn sẽ tạo một lần làm bài mới. Kết quả cũ sẽ được lưu lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Làm lại', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
        _isReviewMode = false;
        _completedQuestionIds.clear();
        _questionResults.clear();
        _questionTimeSpent.clear();
        _previousAnswers.clear();
        _activeQuestionId = null;
        _attemptFinished = false;
        _progressInitialized = false;
      });

      // Dispose audio players
      for (var player in _audioPlayers.values) {
        player.dispose();
      }
      _audioPlayers.clear();

      await _loadSections();
    }
  }

  // Recording methods
  void _startRecording(SpeakingQuestion question) async {
    if (!_recordingEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording không khả dụng')),
      );
      return;
    }

    try {
      // ✅ IMPORTANT: Initialize progress with is_passed = false on first recording
      if (!_progressInitialized && _attemptId != null) {      
        try {
          await _attemptService.initializeLessonProgress(
            lessonId: widget.lessonId,
          );
          
          setState(() {
            _progressInitialized = true;
          });
          
        } catch (e) {
          debugPrint('⚠️ Failed to initialize progress: $e');
          // Continue anyway - will be created on finish
        }
      }

      await _audioRecorder.startRecording();
      
      // ✅ Start tracking time for this question
      _questionTimeSpent[question.id] = 0;
      
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _secondsRecorded = 0;
        _currentTranscript = '';
        _currentAudioPath = null;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _secondsRecorded++;
          _questionTimeSpent[question.id] = (_questionTimeSpent[question.id] ?? 0) + 1;
        });
        
        if (_secondsRecorded >= question.timeLimit) {
          _stopRecording();
        }
      });

      debugPrint('🎤 Recording started');
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi bắt đầu ghi âm: $e')),
      );
    }
  }

  void _pauseRecording() async {
    try {
      await _audioRecorder.pauseRecording();
      _recordingTimer?.cancel();
      setState(() => _isPaused = true);
      debugPrint('⏸️ Recording paused');
    } catch (e) {
      debugPrint('❌ Error pausing: $e');
    }
  }

  void _resumeRecording() async {
    try {
      await _audioRecorder.resumeRecording();
      setState(() => _isPaused = false);
      
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _secondsRecorded++;
          // Update time for active question
          if (_activeQuestionId != null) {
            _questionTimeSpent[_activeQuestionId!] = 
                (_questionTimeSpent[_activeQuestionId!] ?? 0) + 1;
          }
        });
      });
      
      debugPrint('▶️ Recording resumed');
    } catch (e) {
      debugPrint('❌ Error resuming: $e');
    }
  }

  void _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final audioPath = await _audioRecorder.stopRecording();
      
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      if (audioPath == null) {
        throw Exception('No audio recorded');
      }

      setState(() {
        _currentAudioPath = audioPath;
        _currentTranscript = 'Đang chuyển đổi âm thanh sang text...';
      });

      debugPrint('⏹️ Recording stopped: $audioPath');

      try {
        final transcript = await _groqSpeech.transcribeAudio(audioPath);
        
        setState(() => _currentTranscript = transcript);
        debugPrint('✅ Transcript: $transcript');
        
        if (transcript.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không nhận diện được giọng nói. Vui lòng thử lại.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Error converting audio: $e');
        setState(() => _currentTranscript = '');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chuyển đổi âm thanh: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi dừng ghi âm: $e')),
      );
    }
  }

  // ✅ UPDATE: Submit answer - auto-finish when all completed
  Future<void> _submitAnswer(SpeakingQuestion question) async {
    if (_currentTranscript.trim().isEmpty || _currentTranscript.contains('Đang chuyển đổi')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đợi chuyển đổi âm thanh hoàn tất')),
      );
      return;
    }

    if (_attemptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi: Không tìm thấy attempt ID')),
      );
      return;
    }

    _showLoadingDialog('Đang xử lý...');

    try {
      // ✅ 1. Grade with AI
      debugPrint('🤖 Grading with AI...');
      final result = await _aiService.gradeSpeaking(
        questionText: question.questionText,
        userAnswer: _currentTranscript,
        referenceText: question.referenceText,
        speakingMode: question.speakingMode,
        expectedAnswer: question.expectedAnswer,
        guideline: question.guideline,
      );

      debugPrint('✅ AI grading completed: ${result['total_score']}/100');

      String? audioUrl;

      // ✅ 2. Upload audio to Supabase Storage
      if (_currentAudioPath != null) {
        try {
          debugPrint('📤 Uploading audio to storage...');
          audioUrl = await _submissionService.uploadAudioFile(
            audioPath: _currentAudioPath!,
            questionId: question.id,
          );
          debugPrint('✅ Audio uploaded: $audioUrl');
        } catch (e) {
          debugPrint('⚠️ Audio upload failed: $e');
        }
      }

      // ✅ 3. Save to speaking_submissions table
      if (audioUrl != null) {
        try {
          await _submissionService.saveSpeakingSubmission(
            questionId: question.id,
            audioUrl: audioUrl,
            transcript: _currentTranscript,
            score: (result['total_score'] as num).toDouble(),
            feedback: result,
          );
          debugPrint('✅ Submission saved to speaking_submissions');
        } catch (e) {
          debugPrint('⚠️ Failed to save submission: $e');
        }
      }

      // ✅ 4. Save to user_attempt_questions
      final timeSpent = _questionTimeSpent[question.id] ?? 0;
      
      await _submissionService.saveSpeakingAnswer(
        attemptId: _attemptId!,
        questionId: question.id,
        transcript: _currentTranscript,
        aiResult: result,
        timeSpent: timeSpent,
      );

      debugPrint('✅ Answer saved to user_attempt_questions');

      // Update local state
      setState(() {
        _completedQuestionIds.add(question.id);
        _questionResults[question.id] = {
          ...result,
          'transcript': _currentTranscript,
          'audio_url': audioUrl,
          'time_spent': timeSpent,
        };
        _activeQuestionId = null;
        _currentTranscript = '';
        _currentAudioPath = null;
        _secondsRecorded = 0;
      });

      if (_currentAudioPath != null) {
        await _audioRecorder.deleteRecording(_currentAudioPath!);
      }

      if (mounted) Navigator.pop(context);

      await showDialog(
        context: context,
        builder: (context) => SpeakingResultDialog(result: result),
      );

      // ✅ CHECK: All completed AND not yet finished
      final totalQuestions = _getTotalQuestions();
      final allCompleted = _completedQuestionIds.length == totalQuestions;

      // ✅ GUARD: Only finish if all completed AND not already finished
      if (allCompleted && !_attemptFinished) {        
        final totalScore = _questionResults.values.fold<double>(
          0,
          (sum, r) => sum + (r['total_score'] as num).toDouble(),
        );
        final avgScore = totalScore / _questionResults.length;
        final isPassed = avgScore >= 60;

        _showLoadingDialog('Đang lưu kết quả cuối cùng...');

        try {
          debugPrint('🔄 Calling finishAttempt...');
          
          final success = await _attemptService.finishAttempt(
            attemptId: _attemptId!,
            lessonId: widget.lessonId,
            score: avgScore,
            isPassed: isPassed,
          );

          debugPrint('✅ finishAttempt result: $success');

          if (!success) {
            throw Exception('Failed to finish attempt');
          }

          // ✅ IMPORTANT: Mark as finished to prevent re-calling
          setState(() {
            _attemptFinished = true;
          });

          if (mounted) Navigator.pop(context);

          _showCompletionDialog(avgScore, isPassed);
          
        } catch (e, stackTrace) {
          debugPrint('Error: $e');
          
          if (mounted) Navigator.pop(context);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi lưu kết quả: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Xem kết quả',
                textColor: Colors.white,
                onPressed: () => _showCompletionDialog(avgScore, isPassed),
              ),
            ),
          );
        }
      } else if (_attemptFinished) {
        debugPrint('ℹ️ Attempt already finished, skipping finishAttempt()');
      }
      
    } catch (e, stackTrace) {
      if (mounted) Navigator.pop(context);
      debugPrint('❌ Error submitting answer: $e');
      debugPrint('Stack trace: $stackTrace');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ Finish attempt and calculate final score
  void _showFinalResults() async {
    if (_attemptId == null) {
      debugPrint('❌ ERROR: Attempt ID is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi: Không tìm thấy attempt')),
      );
      return;
    }

    final totalScore = _questionResults.values.fold<double>(
      0,
      (sum, r) => sum + (r['total_score'] as num).toDouble(),
    );
    final avgScore = _questionResults.isEmpty ? 0.0 : totalScore / _questionResults.length;
    final isPassed = avgScore >= 60;

    _showLoadingDialog('Đang lưu kết quả...');

    try {
      debugPrint('🔄 Starting finishAttempt...');
      
      // ✅ Finish attempt and update progress
      final success = await _attemptService.finishAttempt(
        attemptId: _attemptId!,
        lessonId: widget.lessonId,
        score: avgScore,
        isPassed: isPassed,
      );

      debugPrint('✅ finishAttempt completed: $success');

      if (!success) {
        throw Exception('Failed to finish attempt');
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      // ✅ Show completion dialog
      _showCompletionDialog(avgScore, isPassed);
      
    } catch (e, stackTrace) {
      debugPrint('Error: $e');
      
      if (mounted) Navigator.pop(context); 
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi hoàn thành bài học: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Thử lại',
            textColor: Colors.white,
            onPressed: _showFinalResults,
          ),
        ),
      );
    }
  }

  // ✅ Extract completion dialog to separate method
  void _showCompletionDialog(double avgScore, bool isPassed) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isPassed ? Icons.emoji_events : Icons.refresh,
              color: isPassed ? Colors.amber : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 10),
            const Text('Hoàn thành bài học'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isPassed
                      ? [Colors.green.shade400, Colors.green.shade700]
                      : [Colors.orange.shade400, Colors.orange.shade700],
                ),
              ),
              child: Center(
                child: Text(
                  '${avgScore.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPassed ? '🎉 Xuất sắc!' : '💪 Cố gắng lên!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Đã hoàn thành ${_completedQuestionIds.length} bài Speaking',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          if (!isPassed) ...[
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Về trang chủ'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                setState(() {
                  _isLoading = true;
                  _completedQuestionIds.clear();
                  _questionResults.clear();
                  _questionTimeSpent.clear();
                  _activeQuestionId = null;
                  _attemptFinished = false;
                  _progressInitialized = false; 
                });
                await _loadSections();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Làm lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Đóng'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Bài tiếp theo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              // Dùng RichText thay vì Text
              RichText(
                text: TextSpan(
                  text: message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ UPDATED: Reset recording method with immediate restart
  void _resetRecordingDuringSession(SpeakingQuestion question) async {
    // Show quick confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.refresh, color: Colors.red),
            SizedBox(width: 10),
            Text('Bắt đầu lại?'),
          ],
        ),
        content: const Text(
          'Bạn sẽ xóa bản ghi hiện tại và bắt đầu ghi âm lại từ đầu.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.refresh),
            label: const Text('Bắt đầu lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Stop current recording
      if (_isRecording) {
        await _audioRecorder.stopRecording();
        _recordingTimer?.cancel();
        debugPrint('⏹️ Stopped current recording for reset');
      }

      // 2. Delete current audio file if exists
      if (_currentAudioPath != null) {
        try {
          await _audioRecorder.deleteRecording(_currentAudioPath!);
          debugPrint('🗑️ Deleted recording: $_currentAudioPath');
        } catch (e) {
          debugPrint('⚠️ Failed to delete recording: $e');
        }
      }

      // 3. Reset all state
      setState(() {
        _currentTranscript = '';
        _currentAudioPath = null;
        _secondsRecorded = 0;
        _isRecording = false;
        _isPaused = false;
        _questionTimeSpent[question.id] = 0;
      });

      debugPrint('🔄 Recording reset complete');

      // 4. Show brief feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Đã reset. Bắt đầu ghi âm lại.'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // 5. Auto-start recording again after a brief delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        _startRecording(question);
      }

    } catch (e) {
      debugPrint('❌ Error resetting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi reset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
