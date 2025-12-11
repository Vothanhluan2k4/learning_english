import 'package:flutter/material.dart';
import 'package:learning_english/services/test/final_test_speaking_service.dart';
import 'package:learning_english/screens/drawer_screen.dart';
import 'package:learning_english/services/ai/ai_grading_service.dart';
import 'package:learning_english/services/auth/auth_service.dart';
import 'package:learning_english/services/test/test_final_service.dart';
import 'package:learning_english/widgets/markdown_content_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../models/question_group.dart';
import '../../models/test_question.dart';
import '../../widgets/audio_player.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; 
import 'package:highlight/highlight.dart' as highlight; 
import '../../widgets/test/test_speaking_question_card.dart';
import 'package:provider/provider.dart'; 


class FinalTestScreen extends StatefulWidget {
  final String testId;
  final String? lessonId; 
  final bool isPlacementTest; 
  final double? targetScore; 

  const FinalTestScreen({
    required this.testId,
    this.lessonId,
    this.isPlacementTest = false,
    this.targetScore,
    super.key,
  });

  @override
  State<FinalTestScreen> createState() => _FinalTestScreenState();
}
class _FinalTestScreenState extends State<FinalTestScreen>
    with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  final _testService = TestFinalService();
  final _authService = AuthService();
  late FinalTestSpeakingService _speakingService;

  String? _resultId;
  String? _userId;
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  List<dynamic> _items = [];
  Map<String, String> _userAnswers = {};
  bool _isPanelOpen = false;
  Timer? _timer;
  int _timeRemaining = 0;
  bool _isTimeUp = false;

  final Map<String, int> _audioPlayCounts = {}; 
  final Map<String, bool> _isAudioPlaying = {}; 
  final Map<String, TextEditingController> _essayControllers = {};


  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _speakingService = FinalTestSpeakingService();
    _speakingService.initializeRecording();
    _initializeTest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _speakingService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _resultId != null) {
      _testService.updateTestProgress(
        resultId: _resultId!,
        timeRemaining: _timeRemaining,
      );
    }
  }

  Future<void> _initializeTest() async {
    setState(() => _isLoading = true);

    if (widget.testId.isEmpty || widget.testId == 'null') {
      setState(() => _isLoading = false);
      return;
    }

    final testInfo = await _testService.fetchTestInfo(widget.testId);
    if (testInfo == null) {
      setState(() => _isLoading = false);
      return;
    }

    final items = await _testService.fetchTestItems(widget.testId);

    final authUser = supabase.auth.currentUser;
    if (authUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    _userId = await _authService.getUserIdFromAuthId(authUser.id);
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    _resultId = await _testService.createOrGetUserTestResult(
      userId: _userId!,
      testId: widget.testId,
    );

    if (testInfo['time_limit'] != null) {
      _startTimer(testInfo['time_limit']);
    }

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _startTimer(int minutes) {
    _timeRemaining = minutes * 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
          if (_timeRemaining % 60 == 0 && _resultId != null) {
            _testService.updateTestProgress(
              resultId: _resultId!,
              timeRemaining: _timeRemaining,
            );
          }
        } else {
          _isTimeUp = true;
          timer.cancel();
          _handleTimeout();
        }
      });
    });
  }

  Future<void> _handleTimeout() async {
    if (_resultId != null) {
      await _testService.handleTimeout(_resultId!);
      _showTimeoutDialog();
    }
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Hết thời gian'),
          ],
        ),
        content: const Text('Thời gian làm bài đã hết. Hệ thống sẽ tự động nộp bài.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitTest();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Đồng ý', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // MARK: - Navigation
  void _nextQuestion() {
    // Track audio play when leaving current question
    final currentItem = _items[_currentQuestionIndex];
    if (currentItem is QuestionGroup && currentItem.mediaType == 'audio') {
      final isPlaying = _isAudioPlaying[currentItem.id] ?? false;
      if (isPlaying) {
        setState(() {
          final currentCount = _audioPlayCounts[currentItem.id] ?? 0;
          if (currentCount == 0) {
            // First time playing but interrupted = count as 1
            _audioPlayCounts[currentItem.id] = 1;
            debugPrint('⚠️ Audio interrupted: ${currentItem.id}, counted as 1 play');
          }
          _isAudioPlaying[currentItem.id] = false;
        });
      }
    }

    _resetSpeakingStateForNewQuestion();

    // Original navigation logic
    if (_currentQuestionIndex < _items.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _isPanelOpen = false;
      });
    } else {
      _submitTest();
    }
  }

  void _previousQuestion() {
    // Track audio play when leaving current question
    final currentItem = _items[_currentQuestionIndex];
    if (currentItem is QuestionGroup && currentItem.mediaType == 'audio') {
      final isPlaying = _isAudioPlaying[currentItem.id] ?? false;
      if (isPlaying) {
        setState(() {
          final currentCount = _audioPlayCounts[currentItem.id] ?? 0;
          if (currentCount == 0) {
            _audioPlayCounts[currentItem.id] = 1;
            debugPrint('⚠️ Audio interrupted (back): ${currentItem.id}, counted as 1 play');
          }
          _isAudioPlaying[currentItem.id] = false;
        });
      }
    }

    _resetSpeakingStateForNewQuestion();

    // Original navigation logic
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _isPanelOpen = false;
      });
    }
  }

bool _canMoveNext() {
  final item = _items[_currentQuestionIndex];
  
  if (item is TestQuestion) {
    final answer = _userAnswers[item.id] ?? '';
    
    // ✅ ADD: Speaking validation
    if (item.isSpeaking) {
      return answer.trim().isNotEmpty && !_speakingService.isRecording;
    }
    
    // Essay validation
    if (item.questionType == 'essay') {
      final wordCount = answer.trim().isEmpty
          ? 0
          : answer.trim().split(RegExp(r'\s+')).length;
      
      return wordCount >= (item.minWords ?? 0) && wordCount <= (item.maxWords ?? 9999);
    }
    
    return answer.trim().isNotEmpty;
  } else if (item is QuestionGroup) {
    return item.testQuestions.every((q) {
      final answer = _userAnswers[q.id] ?? '';
      
      // ✅ ADD: Speaking validation
      if (q.isSpeaking) {
        return answer.trim().isNotEmpty && !_speakingService.isRecording;
      }
      
      if (q.questionType == 'essay') {
        final wordCount = answer.trim().isEmpty
            ? 0
            : answer.trim().split(RegExp(r'\s+')).length;
        
        return wordCount >= (q.minWords ?? 0) && wordCount <= (q.maxWords ?? 9999);
      }
      
      return answer.trim().isNotEmpty;
    });
  }
  
  return false;
}

Future<void> _submitTest() async {
  _timer?.cancel();

  // Collect essay and speaking questions
  List<Map<String, dynamic>> essayQuestions = [];
  List<Map<String, dynamic>> speakingQuestions = [];
  
  int total = 0, correct = 0;
  
  for (final item in _items) {
    if (item is TestQuestion) {
      total++;
      
      if (item.questionType == 'essay') {
        final userAnswer = _userAnswers[item.id] ?? '';
        if (userAnswer.trim().isNotEmpty) {
          essayQuestions.add({
            'question_id': item.id,
            'question_text': item.questionText,
            'user_answer': userAnswer,
            'min_words': item.minWords,
            'max_words': item.maxWords,
            'guideline': item.guideline,
          });
        }
      } else if (item.isSpeaking) {
        final userAnswer = _userAnswers[item.id] ?? '';
        if (userAnswer.trim().isNotEmpty) {
          speakingQuestions.add({
            'question_id': item.id,
            'question': item,
            'transcript': userAnswer,
          });
        }
      } else {
        // ✅ FIX: Normalize comparison for fill_blank and multiple_choice
        final userAnswer = (_userAnswers[item.id] ?? '').trim().toLowerCase();
        final correctAnswer = (item.correctAnswer ?? '').trim().toLowerCase();
        
        if (userAnswer == correctAnswer) {
          correct++;
          debugPrint('   ✅ Question ${item.id.substring(0, 8)}: CORRECT');
        } else {
          debugPrint('   ❌ Question ${item.id.substring(0, 8)}: user="$userAnswer" vs correct="$correctAnswer"');
        }
      }
    } else if (item is QuestionGroup) {
      for (final q in item.testQuestions) {
        total++;
        
        if (q.questionType == 'essay') {
          final userAnswer = _userAnswers[q.id] ?? '';
          if (userAnswer.trim().isNotEmpty) {
            essayQuestions.add({
              'question_id': q.id,
              'question_text': q.questionText,
              'user_answer': userAnswer,
              'min_words': q.minWords,
              'max_words': q.maxWords,
              'guideline': q.guideline,
            });
          }
        } else if (q.isSpeaking) {
          final userAnswer = _userAnswers[q.id] ?? '';
          if (userAnswer.trim().isNotEmpty) {
            speakingQuestions.add({
              'question_id': q.id,
              'question': q,
              'transcript': userAnswer,
            });
          }
        } else {
          final userAnswer = (_userAnswers[q.id] ?? '').trim().toLowerCase();
          final correctAnswer = (q.correctAnswer ?? '').trim().toLowerCase();
          
          if (userAnswer == correctAnswer) {
            correct++;
            debugPrint('   ✅ Group question ${q.id.substring(0, 8)}: CORRECT');
          } else {
            debugPrint('   ❌ Group question ${q.id.substring(0, 8)}: user="$userAnswer" vs correct="$correctAnswer"');
          }
        }
      }
    }
  }

  // ✅ Grade essays first
  if (essayQuestions.isNotEmpty) {
    await _gradeEssaysWithAI(essayQuestions);
  }

  // ✅ Grade speaking next
  if (speakingQuestions.isNotEmpty) {
    await _gradeSpeakingWithAI(speakingQuestions);
  }

  // ✅ NEW: Calculate weighted score
  double totalScore = 0.0;
  int regularQuestions = 0;
  
  regularQuestions = total - essayQuestions.length - speakingQuestions.length;
  totalScore += correct * 100.0; 
  
  debugPrint('📊 Score Calculation:');
  debugPrint('   Regular questions: $regularQuestions');
  debugPrint('   Regular correct: $correct');
  debugPrint('   Regular score: ${correct * 100.0}');

  // 2. Essay questions - use AI score (0-100)
  int essayCount = 0;
  double essayTotalScore = 0.0;
  
  for (final essay in essayQuestions) {
    try {
      final answer = await supabase
          .from('user_test_answers')
          .select('ai_score, is_correct')
          .eq('result_id', _resultId!)
          .eq('question_id', essay['question_id'])
          .maybeSingle();
    
      if (answer != null && answer['ai_score'] != null) {
        final aiScore = (answer['ai_score'] as num).toDouble();
        essayTotalScore += aiScore;
        essayCount++;
        debugPrint('   Essay ${essay['question_id']}: $aiScore points');
      }
    } catch (e) {
      debugPrint('❌ Error fetching essay AI score: $e');
    }
  }
  
  totalScore += essayTotalScore;
  debugPrint('   Essay count: $essayCount');
  debugPrint('   Essay total score: $essayTotalScore');

  // 3. Speaking questions - use AI score (0-100)
  int speakingCount = 0;
  double speakingTotalScore = 0.0;
  
  for (final speaking in speakingQuestions) {
    try {
      final answer = await supabase
          .from('user_test_answers')
          .select('ai_score, is_correct')
          .eq('result_id', _resultId!)
          .eq('question_id', speaking['question_id'])
          .maybeSingle();
    
      if (answer != null && answer['ai_score'] != null) {
        final aiScore = (answer['ai_score'] as num).toDouble();
        speakingTotalScore += aiScore;
        speakingCount++;
        debugPrint('   Speaking ${speaking['question_id']}: $aiScore points');
      }
    } catch (e) {
      debugPrint('❌ Error fetching speaking AI score: $e');
    }
  }
  
  totalScore += speakingTotalScore;
  debugPrint('   Speaking count: $speakingCount');
  debugPrint('   Speaking total score: $speakingTotalScore');

  // ✅ Calculate average score (0-100 scale)
  final finalScore = total > 0 ? (totalScore / total) : 0.0;
  
  // ✅ Calculate correct_answers (questions with score >= 60)
  int totalCorrect = correct; // Regular correct answers
  
  // Add essay correct (score >= 60)
  for (final essay in essayQuestions) {
    try {
      final answer = await supabase
          .from('user_test_answers')
          .select('is_correct')
          .eq('result_id', _resultId!)
          .eq('question_id', essay['question_id'])
          .maybeSingle();
    
      if (answer != null && answer['is_correct'] == true) {
        totalCorrect++;
      }
    } catch (e) {
      debugPrint('❌ Error fetching essay result: $e');
    }
  }
  
  // Add speaking correct (score >= 60)
  for (final speaking in speakingQuestions) {
    try {
      final answer = await supabase
          .from('user_test_answers')
          .select('is_correct')
          .eq('result_id', _resultId!)
          .eq('question_id', speaking['question_id'])
          .maybeSingle();
    
      if (answer != null && answer['is_correct'] == true) {
        totalCorrect++;
      }
    } catch (e) {
      debugPrint('❌ Error fetching speaking result: $e');
    }
  }

  // ✅ Submit with averaged score
  if (_resultId != null) {
    await _testService.submitTest(
      resultId: _resultId!,
      score: finalScore, 
      totalQuestions: total,
      correctAnswers: totalCorrect, 
      isTimeout: _isTimeUp,
    );

    // Update placement or lesson progress
    if (widget.isPlacementTest) {
      final testInfo = await _testService.fetchTestInfo(widget.testId);
      await _testService.updatePlacementSummary(
        userId: _userId!,
        testId: widget.testId,
        resultId: _resultId!,
        score: finalScore,
        recommendedCourseId: testInfo!['recommended_course_id'],
      );
    } else if (widget.lessonId != null) {
      final targetScore = widget.targetScore ?? 50.0;
      final isPassed = finalScore >= targetScore; 
      final attemptNum = await _testService.getNextAttemptNumber(_userId!, widget.lessonId!);

      await _testService.updateLessonProgress(
        userId: _userId!,
        lessonId: widget.lessonId!,
        score: finalScore,
        isPassed: isPassed,
        attemptNumber: attemptNum,
        resultId: _resultId!,
      );

      if (isPassed) {
        await _testService.checkAndUnlockNextCourse(_userId!, widget.lessonId!);
      }
    }
  }

  _showResultDialog(finalScore, totalCorrect, total);
}


  Future<void> _showResultDialog(double score, int correct, int total) async {
    try {
      String title, message, courseInfo;
      String? nextModuleName;

      if (widget.isPlacementTest) {
        // Placement test result
        final placementData = await supabase
            .from('user_placement_summary')
            .select('''
              score,
              courses:recommended_course_id (
                course_name
              )
            ''')
            .eq('user_id', _userId!)
            .eq('placement_test_id', widget.testId)
            .single();

        title = 'Kết quả bài kiểm tra đầu vào';
        courseInfo =
            placementData['courses']['course_name'] ?? 'Chưa xác định';
        message = 'Khóa học phù hợp: $courseInfo';
      } else {
        // Lesson test result
        final targetScore = widget.targetScore ?? 50.0;
        final isPassed = score >= targetScore;

        title = isPassed ? 'Bạn đã vượt qua!' : 'Cần cố gắng hơn';

        if (isPassed) {
          // ✅ Lấy course module tiếp theo
          debugPrint('🔍 Fetching next course module...');
          nextModuleName = await _getNextModuleInfo();
          courseInfo = nextModuleName ?? 'Khóa học tiếp theo đã được mở khóa';
        } else {
          courseInfo = 'Vui lòng làm lại bài kiểm tra';
        }

        message = 'Điểm cần: $targetScore%, Điểm của bạn: ${score.toStringAsFixed(1)}%';
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon & Trophy
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Icon(Icons.emoji_events, color: Colors.amber, size: 60),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),

                  // Score Circle
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade700],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${score.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Details Container
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row 1: Số câu đúng
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      color: Colors.green, size: 24),
                                  SizedBox(width: 12),
                                  Text(
                                    'Số câu đúng',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blueGrey[800],
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$correct/$total',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 12),

                        // Row 2: Yêu cầu/Khóa học tiếp theo
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✅ FIX: Wrap icon + label trong Flexible
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.isPlacementTest
                                          ? Icons.school
                                          : Icons.trending_up,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        widget.isPlacementTest ? 'Khóa học' : 'Bước tiếp',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blueGrey[800],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              // ✅ FIX: Value container với better sizing
                              Flexible(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    courseInfo,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            if (widget.isPlacementTest) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DrawerScreen(initialIndex: 1),
                                ),
                                (route) => false,
                              );
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          child: Text(
                            widget.isPlacementTest
                                ? 'Xem khóa học'
                                : 'Quay lại',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushReplacementNamed(
                              context,
                              '/homedrawer',
                            );
                          },
                          child: Text(
                            'Trang chủ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Lỗi show result dialog: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Kết quả'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Điểm: ${score.toStringAsFixed(1)}%'),
                SizedBox(height: 8),
                Text('Đúng: $correct/$total'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/homedrawer');
              },
              child: Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }
  
    /// ✅ Lấy thông tin course module tiếp theo
  Future<String?> _getNextModuleInfo() async {
    try {
      if (widget.lessonId == null) return null;

      debugPrint('🔍 Getting next module info...');

      // ✅ Step 1: Lấy lesson hiện tại + module của nó
      final currentLesson = await supabase
          .from('lessons_course')
          .select('module_id, order_index')
          .eq('id', widget.lessonId!)
          .single();

      final currentModuleId = currentLesson['module_id'] as String;
      final currentLessonOrder = currentLesson['order_index'] as int;

      debugPrint('   Current module: $currentModuleId, order: $currentLessonOrder');

      // ✅ Step 2: Lấy module tiếp theo trong cùng course
      final currentModule = await supabase
          .from('course_modules')
          .select('course_id, order_index')
          .eq('id', currentModuleId)
          .single();

      final courseId = currentModule['course_id'] as String;
      final currentModuleOrder = currentModule['order_index'] as int;

      debugPrint('   Course: $courseId, module order: $currentModuleOrder');

      // ✅ Step 3: Lấy module tiếp theo
      final nextModule = await supabase
          .from('course_modules')
          .select('id, module_name')
          .eq('course_id', courseId)
          .gt('order_index', currentModuleOrder)
          .order('order_index', ascending: true)
          .limit(1)
          .maybeSingle();

      if (nextModule != null) {
        final nextModuleName = nextModule['module_name'] as String;
        debugPrint('✅ Next module: $nextModuleName');
        return nextModuleName;
      } else {
        debugPrint('⚠️ Không có module tiếp theo');
        return 'Hoàn thành toàn bộ khóa học';
      }
    } catch (e) {
      debugPrint('❌ Error getting next module: $e');
      return null;
    }
  }

  Widget _buildDetailRow(
      IconData icon, String title, String value, Color iconColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey[800],
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[900],
          ),
        ),
      ],
    );
  }

  int _getFlattenedQuestionNumber() {
    int currentNumber = 1;
    for (int i = 0; i < _currentQuestionIndex; i++) {
      if (_items[i] is TestQuestion) {
        currentNumber++;
      } else if (_items[i] is QuestionGroup) {
        currentNumber += (_items[i] as QuestionGroup).testQuestions.length;
      }
    }
    if (_items[_currentQuestionIndex] is QuestionGroup) {
      return currentNumber;
    }
    return currentNumber;
  }

  int _getTotalQuestions() {
    int total = 0;
    for (var item in _items) {
      if (item is TestQuestion) {
        total++;
      } else if (item is QuestionGroup) {
        total += (item as QuestionGroup).testQuestions.length;
      }
    }
    return total;
  }

  Future<void> _saveTestProgress() async {
    if (_resultId != null) {
      try {
        await supabase.from('user_test_results').update({
          'status': 'in_progress',
          'time_remaining': _timeRemaining ~/ 60,
          'last_activity': DateTime.now().toIso8601String(),
        }).eq('id', _resultId!);
      } catch (e) {
        debugPrint('Error saving test progress: $e');
      }
    }
  }


  Future<void> _updateLastActivity() async {
    if (_resultId == null) return;
    try {
      await supabase.from('user_test_results').update({
        'time_remaining': _timeRemaining ~/ 60,
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('id', _resultId!);
    } catch (e) {
      debugPrint('❌ Error updating last activity: $e');
    }
  }
  Future<void> _gradeEssaysWithAI(List<Map<String, dynamic>> essays) async {
  try {
    debugPrint('📝 Grading ${essays.length} essays with AI...');
    
    // Import AI service
    final aiService = AiGradingService();
    
    for (final essay in essays) {
      try {
        debugPrint('   Grading question: ${essay['question_id']}');
        
        // ✅ Call AI grading
        final result = await aiService.gradeWriting(
          questionText: essay['question_text'] ?? '',
          userAnswer: essay['user_answer'] ?? '',
          minWords: essay['min_words'],
          maxWords: essay['max_words'],
          guideline: essay['guideline'],
          provider: 'groq', // or 'gemini'
        );

        // ✅ Save AI score and feedback
        await supabase.from('user_test_answers').update({
          'ai_score': result['total_score'],
          'ai_feedback': result,
          'graded_at': DateTime.now().toIso8601String(),
          'is_correct': result['total_score'] >= 60, 
        }).match({
          'result_id': _resultId!,
          'question_id': essay['question_id'],
        });

        debugPrint('✅ Graded: ${essay['question_id']} - Score: ${result['total_score']}');
      } catch (e) {
        debugPrint('❌ Error grading essay ${essay['question_id']}: $e');
        
        // ✅ Save error status
        await supabase.from('user_test_answers').update({
          'ai_feedback': {'error': e.toString()},
          'graded_at': DateTime.now().toIso8601String(),
        }).match({
          'result_id': _resultId!,
          'question_id': essay['question_id'],
        });
      }
    }
    
    debugPrint('✅ All essays graded');
  } catch (e) {
    debugPrint('❌ Error in _gradeEssaysWithAI: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kiểm tra')),
        body: const Center(child: Text('Không tìm thấy câu hỏi nào.')),
      );
    }

    final currentItem = _items[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPlacementTest ? 'Kiểm tra đầu vào' : 'Kiểm tra cuối',
          style: TextStyle(
            fontSize: 20
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _showExitDialog,
        ),
        actions: [
          if (_timeRemaining > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Row(
                children: [
                  Icon(Icons.timer,
                      color: _timeRemaining < 180 ? Colors.red : Colors.white),
                  SizedBox(width: 4),
                  Text(
                    _formatTime(_timeRemaining),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _timeRemaining < 180 ? Colors.red : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(_isPanelOpen ? Icons.close : Icons.menu),
            onPressed: () => setState(() => _isPanelOpen = !_isPanelOpen),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _items.length,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(Colors.lightGreenAccent),
                minHeight: 6,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: currentItem is TestQuestion
                      ? _buildSingleQuestion(currentItem)
                      : _buildGroupQuestions(currentItem as QuestionGroup),
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
          _buildSidebarPanel(),
        ],
      ),
    );
  }

  Future<void> _showExitDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_outlined, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('Xác nhận thoát'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Bạn chắc chắn muốn thoát khỏi bài kiểm tra?',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tiến độ hiện tại sẽ được lưu lại.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tiếp tục làm bài',
                style: TextStyle(color: Colors.blue)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exitTest();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Thoát', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _exitTest() async {
    await _saveTestProgress();
    _timer?.cancel();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildSingleQuestion(TestQuestion question) {
    List<MapEntry<String, String>> options = [];
    if (question.options != null) {
      if (question.options is Map) {
        final optionsMap = question.options as Map;
        options = optionsMap.entries
            .map((e) => MapEntry(e.key.toString(), e.value.toString()))
            .toList();
      } else if (question.options is List) {
        final list = question.options as List;
        if (list.isNotEmpty && list.first is Map) {
          options = list
              .map((e) => MapEntry(
                    e['label']?.toString() ?? '',
                    e['text']?.toString() ?? '',
                  ))
              .toList();
        } else {
          options = list.asMap().entries
              .map((e) => MapEntry(
                    String.fromCharCode(65 + e.key),
                    e.value.toString(),
                  ))
              .toList();
        }
      }
    }
    if (question.isSpeaking) {
      final savedTranscript = _userAnswers[question.id] ?? '';
    
    // ✅ Restore transcript to service if navigating back
      if (savedTranscript.isNotEmpty && _speakingService.currentTranscript.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _speakingService.restoreTranscript(savedTranscript);
          debugPrint('🔄 Restored transcript for ${question.id}');
        });
      }
    return TestSpeakingQuestionCard(
      question: question,
      questionNumber: _getFlattenedQuestionNumber(),
      totalQuestions: _getTotalQuestions(),
      recordingEnabled: _speakingService.recordingEnabled,
      isRecording: _speakingService.isRecording,
      isPaused: _speakingService.isPaused,
      secondsRecorded: _speakingService.secondsRecorded,
      transcript: savedTranscript.isNotEmpty 
          ? savedTranscript 
          : _speakingService.currentTranscript,
      onStartRecording: () => _handleStartSpeaking(question),
      onPauseRecording: _speakingService.pauseRecording,
      onResumeRecording: _speakingService.resumeRecording,
      onStopRecording: () => _handleStopSpeaking(question),
      onReset: () => _handleResetSpeaking(question),
    );
  }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question number and difficulty
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Câu ${_getFlattenedQuestionNumber()}/${_getTotalQuestions()}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                question.difficulty,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ✅ REPLACE Text with MarkdownBody
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: MarkdownBody(
            data: question.questionText ?? '',
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5, color: Colors.black87),
              strong: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              em: TextStyle(fontStyle: FontStyle.italic),
              code: TextStyle(
                backgroundColor: Colors.blue.shade100,
                color: Colors.blue.shade900,
                fontFamily: 'monospace',
                fontSize: 16,
              ),
              h1: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              h2: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              h3: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            selectable: true,
          ),
        ),
        const SizedBox(height: 24),

        // ✅ ADD: Essay (multi-line) text editor
        if (question.questionType == 'essay') ...[
          _buildEssayEditor(question),
        ]
        // Fill in the blank (single line)
        else if (question.questionType == 'fill_blank') ...[
          TextField(
            decoration: InputDecoration(
              labelText: 'Nhập đáp án của bạn...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueAccent, width: 2),
              ),
            ),
            controller: TextEditingController(
              text: _userAnswers[question.id] ?? '',
            ),
            onChanged: (value) async {
              setState(() {
                _userAnswers[question.id] = value;
              });

              if (_resultId != null) {
                try {
                  await supabase.from('user_test_answers').upsert({
                    'result_id': _resultId,
                    'question_id': question.id,
                    'user_answer': value,
                    'is_correct': value.trim().toLowerCase() ==
                        question.correctAnswer?.trim().toLowerCase(),
                    'answered_at': DateTime.now().toIso8601String(),
                  }, onConflict: 'result_id,question_id');
                } catch (e) {
                  debugPrint('❌ Error saving fill_blank: $e');
                }
              }
            },
          ),
        ]
        // Multiple choice options
        else if (options.isNotEmpty) ...[
          ...options.map((entry) {
            final optionKey = entry.key;
            final optionValue = entry.value;
            final isSelected = _userAnswers[question.id] == optionKey;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () async {
                  setState(() {
                    _userAnswers[question.id] = optionKey;
                  });

                  if (_resultId != null) {
                    try {
                      await supabase.from('user_test_answers').upsert({
                        'result_id': _resultId,
                        'question_id': question.id,
                        'user_answer': optionKey,
                        'is_correct': optionKey == question.correctAnswer,
                        'answered_at': DateTime.now().toIso8601String(),
                      }, onConflict: 'result_id,question_id');
                    } catch (e) {
                      debugPrint('❌ Error saving multiple choice: $e');
                    }
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blueAccent.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blueAccent
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.blueAccent
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? Colors.blueAccent
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Text(
                                  optionKey,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  optionKey,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          optionValue,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.blueAccent
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildGroupQuestions(QuestionGroup group) {
    // ✅ Initialize play count for this specific group
    if (!_audioPlayCounts.containsKey(group.id)) {
      _audioPlayCounts[group.id] = 0;
    }
    
    final remainingPlays = 2 - (_audioPlayCounts[group.id] ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // === HEADER ===
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade50, Colors.blue.shade50],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (group.title != null) ...[
                Text(
                  group.title!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
                SizedBox(height: 8),
              ],
              if (group.instruction != null)
                Text(
                  group.instruction!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // === MEDIA ===
        // ✅ FIXED: Use group.id as unique key, not URL
        if (group.mediaType == 'audio' && group.mediaUrl != null)
          AudioPlayerWidget(
            key: ValueKey(group.id), // ✅ Unique key per group
            audioUrl: group.mediaUrl!,
            remainingPlays: remainingPlays,
            onPlayStart: () {
              // ✅ Increment play count when audio starts
              setState(() {
                _audioPlayCounts[group.id] = (_audioPlayCounts[group.id] ?? 0) + 1;
                _isAudioPlaying[group.id] = true;
              });
              debugPrint('🎧 Audio started: ${group.id}, count: ${_audioPlayCounts[group.id]}');
            },
            onPlayComplete: () {
              // ✅ Mark as not playing when completed
              if (mounted) {
                setState(() {
                  _isAudioPlaying[group.id] = false;
                });
              }
              debugPrint('✅ Audio completed: ${group.id}');
            },
          )
        else if (group.mediaType == 'text' && group.content != null)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: MarkdownBody(
              data: group.content!,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                h1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                h2: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple.shade600),
                h3: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple.shade500),
                listBullet: TextStyle(fontSize: 16, color: Colors.blue.shade700),
                code: TextStyle(backgroundColor: Colors.grey.shade200, color: Colors.red.shade700, fontFamily: 'monospace', fontSize: 14),
                codeblockDecoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(8)),
                blockquote: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                blockquoteDecoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border(left: BorderSide(color: Colors.blue.shade300, width: 4)),
                  borderRadius: BorderRadius.circular(4),
                ),
                strong: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                em: TextStyle(fontStyle: FontStyle.italic),
                a: TextStyle(color: Colors.blue.shade600, decoration: TextDecoration.underline),
              ),
              syntaxHighlighter: MarkdownSyntaxHighlighter(),
              selectable: true,
            ),
          ),

        SizedBox(height: 24),
        Text(
          'Câu hỏi:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.purple.shade700,
          ),
        ),
        SizedBox(height: 12),

        // === CÂU HỎI TRONG GROUP ===
        ...group.testQuestions.asMap().entries.map((entry) {
          final qIndex = entry.key;
          final question = entry.value;
          final questionNumber = qIndex + 1;

          // Xử lý options
          List<MapEntry<String, String>> options = [];
          if (question.options != null) {
            if (question.options is Map) {
              final optionsMap = question.options as Map;
              options = optionsMap.entries
                  .map((e) => MapEntry(e.key.toString(), e.value.toString()))
                  .toList();
            } else if (question.options is List) {
              final list = question.options as List;
              if (list.isNotEmpty && list.first is Map) {
                options = list
                    .map((e) => MapEntry(
                          e['label']?.toString() ?? '',
                          e['text']?.toString() ?? '',
                        ))
                    .toList();
              } else {
                options = list.asMap().entries
                    .map((e) => MapEntry(
                          String.fromCharCode(65 + e.key),
                          e.value.toString(),
                        ))
                    .toList();
              }
            }
          }

          return Container(
            margin: EdgeInsets.only(bottom: 24),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ REPLACE Text with MarkdownBody
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question number
                    Text(
                      '$questionNumber. ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    // Markdown question text
                    Expanded(
                      child: MarkdownBody(
                        data: question.questionText ?? '',
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                          strong: TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlue.shade900),
                          em: TextStyle(fontStyle: FontStyle.italic),
                          code: TextStyle(
                            backgroundColor: Colors.purple.shade100,
                            color: Colors.purple.shade900,
                            fontFamily: 'monospace',
                            fontSize: 15,
                          ),
                        ),
                        selectable: true,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Essay editor
                if (question.questionType == 'essay') ...[
                  _buildEssayEditorForGroup(question),
                ]
                // Fill blank
                else if (question.questionType == 'fill_blank')
                  TextFormField(
                    initialValue: _userAnswers[question.id] ?? '',
                    decoration: InputDecoration(
                      labelText: 'Nhập đáp án của bạn...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) async {
                      setState(() {
                        _userAnswers[question.id] = value;
                      });

                      if (_resultId != null) {
                        try {
                          await Future.delayed(Duration(milliseconds: 300));
                          
                          await supabase.from('user_test_answers').upsert({
                            'result_id': _resultId,
                            'question_id': question.id,
                            'user_answer': value,
                            'is_correct': value.trim().toLowerCase() == question.correctAnswer?.trim().toLowerCase(),
                            'answered_at': DateTime.now().toIso8601String(),
                          }, onConflict: 'result_id,question_id');

                          debugPrint('✅ Đã lưu câu điền khuyết: ${question.id}');
                        } catch (e) {
                          debugPrint('❌ Lỗi lưu user_test_answers (fill_blank): $e');
                        }
                      }
                    },
                  )
                // Câu chọn đáp án
                else if (options.isNotEmpty)
                  ...options.map((opt) {
                    final isSelected = _userAnswers[question.id] == opt.key;
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () async {
                          setState(() {
                            _userAnswers[question.id] = opt.key;
                          });
                          if (_resultId != null) {
                            await supabase.from('user_test_answers').upsert({
                              'result_id': _resultId,
                              'question_id': question.id,
                              'user_answer': opt.key,
                              'is_correct': opt.key == question.correctAnswer,
                              'answered_at': DateTime.now().toIso8601String(),
                            }, onConflict: 'result_id,question_id');
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.purple.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.purple
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.purple : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? Colors.purple : Colors.grey.shade400,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(Icons.check, color: Colors.white, size: 16)
                                    : Center(
                                      child: Text(
                                        opt.key,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  opt.value,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? Colors.purple : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousQuestion,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Quay lại'),
              ),
            ),
          if (_currentQuestionIndex > 0) SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _canMoveNext() ? _nextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Text(
                _currentQuestionIndex == _items.length - 1
                    ? 'Nộp bài'
                    : 'Tiếp theo',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarPanel() {
    List<TestQuestion> allQuestions = [];
    for (var item in _items) {
      if (item is TestQuestion) {
        allQuestions.add(item);
      } else if (item is QuestionGroup) {
        allQuestions.addAll(item.testQuestions);
      }
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      right: _isPanelOpen ? 0 : -300,
      top: 0,
      bottom: 0,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(allQuestions.length, (index) {
                    final question = allQuestions[index];
                    final isAnswered =
                        _userAnswers[question.id]?.trim().isNotEmpty ??
                            false;
                    final isCurrent =
                        _getCurrentQuestionIndex(index);

                    return _buildQuestionCircle(
                      index: index + 1,
                      isCurrent: isCurrent,
                      isAnswered: isAnswered,
                      isGroup: false,
                    );
                  }),
                ),
              ),
            ),
            Divider(),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chú thích:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildLegend(Colors.orange, 'Hiện tại'),
                  SizedBox(height: 8),
                  _buildLegend(Colors.blueAccent, 'Đã trả lời'),
                  SizedBox(height: 8),
                  _buildLegend(Colors.grey.shade200, 'Chưa trả lời'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _getCurrentQuestionIndex(int flatIndex) {
    int currentFlatIndex = 0;

    for (int i = 0; i < _items.length; i++) {
      if (i == _currentQuestionIndex) {
        if (_items[i] is TestQuestion) {
          return currentFlatIndex == flatIndex;
        } else if (_items[i] is QuestionGroup) {
          QuestionGroup group = _items[i] as QuestionGroup;
          return flatIndex >= currentFlatIndex &&
              flatIndex <
                  currentFlatIndex +
                      group.testQuestions.length;
        }
      }

      if (_items[i] is TestQuestion) {
        currentFlatIndex++;
      } else if (_items[i] is QuestionGroup) {
        currentFlatIndex +=
            (_items[i] as QuestionGroup).testQuestions.length;
      }
    }

    return false;
  }

  Widget _buildQuestionCircle({
    required int index,
    required bool isCurrent,
    required bool isAnswered,
    required bool isGroup,
  }) {
    return GestureDetector(
      onTap: () => _jumpToFlattenedQuestion(index - 1),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCurrent
              ? Colors.orange
              : (isAnswered ? Colors.blueAccent : Colors.grey.shade200),
          border: Border.all(
            color: isCurrent ? Colors.orange.shade700 : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            '$index',
            style: TextStyle(
              color: (isAnswered || isCurrent)
                  ? Colors.white
                  : Colors.grey[700],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _jumpToFlattenedQuestion(int flatIndex) {
    // Track audio play when jumping to another question
    final currentItem = _items[_currentQuestionIndex];
    if (currentItem is QuestionGroup && currentItem.mediaType == 'audio') {
      final isPlaying = _isAudioPlaying[currentItem.id] ?? false;
      if (isPlaying) {
        final currentCount = _audioPlayCounts[currentItem.id] ?? 0;
        if (currentCount == 0) {
          _audioPlayCounts[currentItem.id] = 1;
          debugPrint('⚠️ Audio interrupted (jump): ${currentItem.id}, counted as 1 play');
        }
        _isAudioPlaying[currentItem.id] = false;
      }
    }

    _resetSpeakingStateForNewQuestion();
    // Original jump logic
    int currentIndex = 0;

    for (int i = 0; i < _items.length; i++) {
      if (_items[i] is TestQuestion) {
        if (currentIndex == flatIndex) {
          setState(() {
            _currentQuestionIndex = i;
            _isPanelOpen = false;
          });
          return;
        }
        currentIndex++;
      } else if (_items[i] is QuestionGroup) {
        QuestionGroup group = _items[i] as QuestionGroup;
        if (flatIndex >= currentIndex &&
            flatIndex < currentIndex + group.testQuestions.length) {
          setState(() {
            _currentQuestionIndex = i;
            _isPanelOpen = false;
          });
          return;
        }
        currentIndex += group.testQuestions.length;
      }
    }
  }
  
  void _resetSpeakingStateForNewQuestion() {
    final currentItem = _items[_currentQuestionIndex];
    
    // ✅ FIX: Save current transcript to _userAnswers BEFORE reset
    if (currentItem is TestQuestion && currentItem.isSpeaking) {
      final currentTranscript = _speakingService.currentTranscript;
      
      // Only save if transcript is valid (not empty and not error/loading message)
      if (currentTranscript.isNotEmpty && 
          !currentTranscript.contains('Đang chuyển đổi') &&
          !currentTranscript.contains('Đang lưu') &&
          !currentTranscript.contains('Đang chấm') &&
          !currentTranscript.contains('Lỗi')) {
        
        debugPrint('💾 Saving transcript before navigation: ${currentItem.id}');
        debugPrint('   Transcript: ${currentTranscript.substring(0, currentTranscript.length > 50 ? 50 : currentTranscript.length)}...');
        
        setState(() {
          _userAnswers[currentItem.id] = currentTranscript;
        });
      }
    }
    
    // ✅ Then reset service state (clears currentTranscript)
    _speakingService.resetState();
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: color == Colors.grey.shade200
                  ? Colors.grey.shade400
                  : Colors.transparent,
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
Widget _buildEssayEditor(TestQuestion question) {
  // ✅ Get or create controller
  if (!_essayControllers.containsKey(question.id)) {
    _essayControllers[question.id] = TextEditingController(
      text: _userAnswers[question.id] ?? '',
    );
  }
  
  final controller = _essayControllers[question.id]!;

  // ✅ Update controller text if answer changed externally
  if (controller.text != (_userAnswers[question.id] ?? '')) {
    controller.text = _userAnswers[question.id] ?? '';
  }

  int wordCount = controller.text.trim().isEmpty
      ? 0
      : controller.text.trim().split(RegExp(r'\s+')).length;

  final minWords = question.minWords ?? 0;
  final maxWords = question.maxWords ?? 9999;
  final isValid = wordCount >= minWords && wordCount <= maxWords;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Word count requirement
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
                'Yêu cầu: $minWords-$maxWords từ',
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

      // Text editor
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isValid ? Colors.green.shade300 : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: controller, // ✅ Use persistent controller
            maxLines: 8,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              hintText: 'Write your essay here...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
              fontFamily: 'Roboto',
            ),
            onChanged: (value) async {
              // ✅ DON'T call setState immediately - causes rebuild & lose focus
              _userAnswers[question.id] = value;

              // Auto-save essay answer with debounce
              if (_resultId != null) {
                try {
                  await Future.delayed(Duration(milliseconds: 500));
                  await supabase.from('user_test_answers').upsert({
                    'result_id': _resultId,
                    'question_id': question.id,
                    'user_answer': value,
                    'is_correct': null,
                    'answered_at': DateTime.now().toIso8601String(),
                  }, onConflict: 'result_id,question_id');

                  debugPrint('✅ Essay saved: ${question.id}');
                } catch (e) {
                  debugPrint('❌ Error saving essay: $e');
                }
              }
              
              // ✅ Only update UI for word count (without rebuilding TextField)
              if (mounted) {
                setState(() {}); // Update word count display only
              }
            },
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Word count indicator
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Số từ: $wordCount',
            style: TextStyle(
              fontSize: 14,
              color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!isValid)
            Text(
              wordCount < minWords
                  ? 'Cần thêm ${minWords - wordCount} từ'
                  : 'Vượt ${wordCount - maxWords} từ',
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade700,
              ),
            ),
        ],
      ),

      // Guideline
      if (question.guideline != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Gợi ý:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                question.guideline!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.amber.shade900,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
Widget _buildEssayEditorForGroup(TestQuestion question) {
  // ✅ Get or create controller
  if (!_essayControllers.containsKey(question.id)) {
    _essayControllers[question.id] = TextEditingController(
      text: _userAnswers[question.id] ?? '',
    );
  }
  
  final controller = _essayControllers[question.id]!;

  // ✅ Update controller text if answer changed externally
  if (controller.text != (_userAnswers[question.id] ?? '')) {
    controller.text = _userAnswers[question.id] ?? '';
  }

  int wordCount = controller.text.trim().isEmpty
      ? 0
      : controller.text.trim().split(RegExp(r'\s+')).length;

  final minWords = question.minWords ?? 0;
  final maxWords = question.maxWords ?? 9999;
  final isValid = wordCount >= minWords && wordCount <= maxWords;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Word count requirement
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Yêu cầu: $minWords-$maxWords từ',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Text editor
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isValid ? Colors.green.shade300 : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: controller, // ✅ Use persistent controller
            maxLines: 6,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              hintText: 'Write your answer here...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.black87,
              fontFamily: 'Roboto',
            ),
            onChanged: (value) async {
              _userAnswers[question.id] = value;

              if (_resultId != null) {
                try {
                  await Future.delayed(Duration(milliseconds: 500));
                  await supabase.from('user_test_answers').upsert({
                    'result_id': _resultId,
                    'question_id': question.id,
                    'user_answer': value,
                    'is_correct': null,
                    'answered_at': DateTime.now().toIso8601String(),
                  }, onConflict: 'result_id,question_id');

                  debugPrint('✅ Essay saved (group): ${question.id}');
                } catch (e) {
                  debugPrint('❌ Error saving essay (group): $e');
                }
              }
              
              if (mounted) {
                setState(() {});
              }
            },
          ),
        ),
      ),
      const SizedBox(height: 10),

      // Word count indicator
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Số từ: $wordCount',
            style: TextStyle(
              fontSize: 13,
              color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!isValid)
            Text(
              wordCount < minWords
                  ? 'Cần thêm ${minWords - wordCount} từ'
                  : 'Vượt ${wordCount - maxWords} từ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
              ),
            ),
        ],
      ),

      // Guideline
      if (question.guideline != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Gợi ý:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                question.guideline!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.amber.shade900,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
/// ✅ Handle start speaking
Future<void> _handleStartSpeaking(TestQuestion question) async {
  try {
    await _speakingService.startRecording(question);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi bắt đầu ghi âm: $e')),
      );
    }
  }
}

/// ✅ Handle stop speaking
/// ✅ Handle stop speaking (FIXED - Upload audio + Grade immediately)
Future<void> _handleStopSpeaking(TestQuestion question) async {
  try {
    // 1. Stop recording & get transcript
    await _speakingService.stopRecording();
    
    final transcript = _speakingService.currentTranscript;
    final audioPath = _speakingService.currentAudioPath;
    
    if (transcript.isEmpty || transcript.contains('Lỗi')) {
      throw Exception('Transcript không hợp lệ');
    }
    
    // Save transcript to local state
    setState(() {
      _userAnswers[question.id] = transcript;
    });

    if (_resultId == null) {
      throw Exception('Result ID không tồn tại');
    }

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Đang lưu và chấm điểm...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );
    }

    // 2. Save to database (will upload audio)
    await _speakingService.saveSpeakingAnswer(
      resultId: _resultId!,
      questionId: question.id,
      transcript: transcript,
      audioPath: audioPath,
    );

    // 3. Grade with AI immediately
    try {
      final aiResult = await _speakingService.gradeSpeaking(
        question: question,
        transcript: transcript,
      );

      // 4. Update AI score in database
      await _speakingService.updateAiScore(
        resultId: _resultId!,
        questionId: question.id,
        aiResult: aiResult,
      );

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đã lưu! Điểm: ${aiResult['total_score']?.toStringAsFixed(1) ?? 'N/A'}/100',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (gradingError) {
      debugPrint('⚠️ AI grading failed (will retry on submit): $gradingError');
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Đã lưu! Sẽ chấm điểm khi nộp bài.'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('❌ Error in _handleStopSpeaking: $e');
    
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// ✅ Handle reset speaking
Future<void> _handleResetSpeaking(TestQuestion question) async {
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

  if (confirm == true) {
    try {
      setState(() {
        _userAnswers.remove(question.id);
      });
      await _speakingService.resetRecording(question);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi reset: $e')),
        );
      }
    }
  }
}
Future<void> _gradeSpeakingWithAI(List<Map<String, dynamic>> speaking) async {
  try {
    debugPrint('🎤 Grading ${speaking.length} speaking questions with AI...');
    
    int gradedCount = 0;
    int skippedCount = 0;
    
    for (final sq in speaking) {
      try {
        final question = sq['question'] as TestQuestion;
        final transcript = sq['transcript'] as String;
        final questionId = sq['question_id'] as String;
        
        // ✅ Check if already graded
        final existing = await supabase
            .from('user_test_answers')
            .select('ai_score')
            .eq('result_id', _resultId!)
            .eq('question_id', questionId)
            .maybeSingle();

        if (existing != null && existing['ai_score'] != null) {
          debugPrint('⏭️ Skipping already graded: $questionId (score: ${existing['ai_score']})');
          skippedCount++;
          continue;
        }
        
        debugPrint('   📝 Grading speaking: $questionId');
        
        // Grade with AI
        final result = await _speakingService.gradeSpeaking(
          question: question,
          transcript: transcript,
        );

        // Update AI score
        await _speakingService.updateAiScore(
          resultId: _resultId!,
          questionId: questionId,
          aiResult: result,
        );

        gradedCount++;
        debugPrint('✅ Speaking graded: $questionId - Score: ${result['total_score']}');
      } catch (e, stackTrace) {
        debugPrint('❌ Error grading speaking ${sq['question_id']}: $e');
        debugPrint('   Stack trace: $stackTrace');
        
        // Save error state
        try {
          await supabase.from('user_test_answers').update({
            'ai_feedback': {
              'error': e.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            },
            'graded_at': DateTime.now().toIso8601String(),
          }).match({
            'result_id': _resultId!,
            'question_id': sq['question_id'],
          });
        } catch (updateError) {
          debugPrint('❌ Error saving error state: $updateError');
        }
      }
    }
    
    debugPrint('✅ All speaking questions processed - Graded: $gradedCount, Skipped: $skippedCount');
  } catch (e, stackTrace) {
    debugPrint('❌ Error in _gradeSpeakingWithAI: $e');
    debugPrint('   Stack trace: $stackTrace');
  }
}

}


