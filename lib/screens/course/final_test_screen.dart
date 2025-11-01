import 'package:flutter/material.dart';
import 'package:learning_english/screens/drawer_screen.dart';
import 'package:learning_english/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../models/question_group.dart';
import '../../models/test_question.dart';
import '../../widgets/audio_player.dart';

class FinalTestScreen extends StatefulWidget {
  final String testId;
  final String? lessonId; // Null = placement test, not null = lesson final test
  final bool isPlacementTest; // true = placement, false = lesson final test
  final double? targetScore; // Điểm cần đạt để pass (chỉ dùng cho lesson test)

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

class _FinalTestScreenState extends State<FinalTestScreen> with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;

  String? _resultId;
  String? _userId;
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  final _authService = AuthService();

  List<dynamic> _items = [];
  Map<String, String> _userAnswers = {};

  bool _isPanelOpen = false;

  Timer? _timer;
  int _timeRemaining = 0;
  bool _isTimeUp = false;

   @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 FinalTestScreen initState called');
    debugPrint('   testId: ${widget.testId}');
    debugPrint('   lessonId: ${widget.lessonId}');
    debugPrint('   isPlacementTest: ${widget.isPlacementTest}');

    WidgetsBinding.instance.addObserver(this);
    _fetchQuestions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveTestProgress();
    }
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

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _startTimer(int minutes) {
    _timeRemaining = minutes * 60;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
          if (_timeRemaining % 60 == 0) {
            _updateLastActivity();
          }
        } else {
          _isTimeUp = true;
          timer.cancel();
          _handleTimeout();
        }
      });
    });
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

  Future<void> _handleTimeout() async {
    if (_resultId == null) return;
    try {
      await supabase.from('user_test_results').update({
        'status': 'timeout',
        'completed_at': DateTime.now().toIso8601String(),
        'time_remaining': 0,
      }).eq('id', _resultId!);
      _showTimeoutDialog();
    } catch (e) {
      debugPrint('❌ Error handling timeout: $e');
    }
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Hết thời gian'),
          ],
        ),
        content: Text('Thời gian làm bài đã hết. Hệ thống sẽ tự động nộp bài của bạn.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitTest();
            },
            child: Text('Đồng ý', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchQuestions() async {
  try {
    setState(() => _isLoading = true);

    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 FINAL TEST SCREEN DEBUG');
    debugPrint('═══════════════════════════════════════');
    debugPrint('   testId: ${widget.testId}');
    debugPrint('   lessonId: ${widget.lessonId}');
    debugPrint('   isPlacementTest: ${widget.isPlacementTest}');
    debugPrint('═══════════════════════════════════════');

    // ✅ Kiểm tra testId valid
    if (widget.testId.isEmpty || widget.testId == 'null') {
      debugPrint('❌ TEST ID INVALID: ${widget.testId}');
      setState(() => _isLoading = false);
      return;
    }

    // ✅ Fetch test info
    final testInfoRes = await supabase
        .from('tests')
        .select('id, test_name, time_limit, test_type, total_questions')
        .eq('id', widget.testId)
        .maybeSingle();

    debugPrint('📋 Test Info Response: $testInfoRes');

    if (testInfoRes == null) {
      debugPrint('❌ ⚠️ TEST NOT FOUND IN DATABASE');
      debugPrint('   Looking for test_id: ${widget.testId}');
      
      // Debug: Fetch all tests để xem có test nào không
      final allTests = await supabase
          .from('tests')
          .select('id, test_name, test_type')
          .limit(5);
      debugPrint('📊 Available tests (first 5): $allTests');

      setState(() => _isLoading = false);
      return;
    }

    debugPrint('✅ Test found: ${testInfoRes['test_name']}');

    final allItems = <dynamic>[];

    // ✅ Fetch direct questions
    debugPrint('🔎 Fetching direct questions for test: ${widget.testId}');
    final directRes = await supabase
        .from('test_questions')
        .select()
        .eq('test_id', widget.testId)
        .isFilter('group_id', null)
        .order('order_in_test', ascending: true);

    debugPrint('✅ Direct questions found: ${directRes.length}');

    final directQuestions =
        (directRes as List).map((q) => TestQuestion.fromJson(q)).toList();
    allItems.addAll(directQuestions);

    // ✅ Fetch question groups
    debugPrint('🔎 Fetching question groups for test: ${widget.testId}');
    final groupRes = await supabase
        .from('question_groups')
        .select('''
          id, test_id, title, instruction, media_type, media_url, content, order_in_test,
          test_questions!inner(*)
        ''')
        .eq('test_id', widget.testId)
        .order('order_in_test', ascending: true);

    debugPrint('✅ Question groups found: ${groupRes.length}');

    for (final g in groupRes) {
      final group = QuestionGroup.fromJson(g);
      group.testQuestions.sort((a, b) =>
          (a.orderInTest ?? 0).compareTo(b.orderInTest ?? 0));
      allItems.add(group);
    }

    allItems.sort((a, b) {
      final orderA =
          a is TestQuestion ? a.orderInTest : (a as QuestionGroup).orderInTest;
      final orderB =
          b is TestQuestion ? b.orderInTest : (b as QuestionGroup).orderInTest;
      return (orderA ?? 0).compareTo(orderB ?? 0);
    });

    debugPrint('═══════════════════════════════════════');
    debugPrint('✅ TOTAL ITEMS LOADED: ${allItems.length}');
    debugPrint('   - Direct questions: ${directQuestions.length}');
    debugPrint('   - Question groups: ${groupRes.length}');
    debugPrint('═══════════════════════════════════════');

    if (allItems.isEmpty) {
      debugPrint('⚠️ NO QUESTIONS FOUND!');
      debugPrint('   Check if test_questions table has data for this test');
    }

    // ✅ Create result record
    await _createUserTestResult();

    if (testInfoRes['time_limit'] != null) {
      _startTimer(testInfoRes['time_limit']);
    }

    setState(() {
      _items = allItems;
      _isLoading = false;
    });
  } catch (e, stackTrace) {
    debugPrint('❌ ERROR in _fetchQuestions: $e');
    debugPrint('📍 Stack trace: $stackTrace');
    setState(() => _isLoading = false);
  }
}

  void _nextQuestion() {
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
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _isPanelOpen = false;
      });
    }
  }

  void _jumpToQuestion(int index) {
    setState(() {
      _currentQuestionIndex = index;
      _isPanelOpen = false;
    });
  }

  bool _canMoveNext() {
    final currentItem = _items[_currentQuestionIndex];

    if (currentItem is TestQuestion) {
      return _userAnswers[currentItem.id]?.trim().isNotEmpty ?? false;
    } else if (currentItem is QuestionGroup) {
      return currentItem.testQuestions.every(
          (q) => _userAnswers[q.id]?.trim().isNotEmpty ?? false);
    }

    return false;
  }

  // ✅ Create result record - hỗ trợ cả placement và lesson test
  Future<void> _createUserTestResult() async {
  try {
    debugPrint('📝 Creating user test result...');
    
    final authUser = supabase.auth.currentUser;
    if (authUser == null) {
      debugPrint('❌ User not authenticated');
      throw Exception('User not authenticated');
    }

    final authId = authUser.id;
    debugPrint('🔑 Auth ID: $authId');
    
    _userId = await _authService.getUserIdFromAuthId(authId);
    if (_userId == null) {
      debugPrint('❌ User ID not found from auth_id');
      throw Exception('User not found');
    }
    
    debugPrint('✅ User ID: $_userId');
    debugPrint('📝 Checking for existing attempt for test: ${widget.testId}');

    // Check existing result
    final existing = await supabase
        .from('user_test_results')
        .select('id, status, time_remaining')
        .eq('user_id', _userId!)
        .eq('test_id', widget.testId)
        .maybeSingle();

    if (existing != null) {
      _resultId = existing['id'];
      debugPrint('♻️ Found existing result: $_resultId');
      debugPrint('   Status: ${existing['status']}');
      debugPrint('   Time remaining: ${existing['time_remaining']}');

      if (existing['status'] == 'in_progress' &&
          existing['time_remaining'] != null) {
        _startTimer(existing['time_remaining']);
      }
    } else {
      debugPrint('🆕 Creating new result...');
      
      final newResult = await supabase
          .from('user_test_results')
          .insert({
            'user_id': _userId,
            'test_id': widget.testId,
            'status': 'in_progress',
            'started_at': DateTime.now().toIso8601String(),
            'last_activity': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      _resultId = newResult['id'];
      debugPrint('✅ New result created: $_resultId');
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Lỗi tạo user_test_results: $e');
    debugPrint('📍 Stack trace: $stackTrace');
  }
}

  Future<void> _submitTest() async {
    _timer?.cancel();

    int total = 0;
    int correct = 0;

    for (final item in _items) {
      if (item is TestQuestion) {
        total++;
        final userAnswer = _userAnswers[item.id];
        if (userAnswer == item.correctAnswer) correct++;
      } else if (item is QuestionGroup) {
        for (final q in item.testQuestions) {
          total++;
          final userAnswer = _userAnswers[q.id];
          if (userAnswer == q.correctAnswer) correct++;
        }
      }
    }

    final score = total > 0 ? (correct / total * 100) : 0.0;

    // ✅ Update result
    if (_resultId != null) {
      await supabase.from('user_test_results').update({
        'score': score,
        'total_questions': total,
        'correct_answers': correct,
        'status': _isTimeUp ? 'timeout' : 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'time_remaining': 0,
      }).eq('id', _resultId!);
    }

    // ✅ Xử lý theo test type
    if (widget.isPlacementTest) {
      // Placement test - cập nhật user_placement_summary
      await _handlePlacementTestCompletion(score);
    } else {
      // Lesson final test - cập nhật user_lesson_attempts
      await _handleLessonTestCompletion(score);
    }

    _showResultDialog(score, correct, total);
  }

  /// ✅ Xử lý placement test hoàn thành
  Future<void> _handlePlacementTestCompletion(double score) async {
    try {
      final testInfo = await supabase
          .from('tests')
          .select('recommended_course_id')
          .eq('id', widget.testId)
          .single();

      await supabase.from('user_placement_summary').upsert({
        'user_id': _userId,
        'placement_test_id': widget.testId,
        'latest_result_id': _resultId,
        'score': score,
        'recommended_course_id': testInfo['recommended_course_id'],
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Cập nhật placement summary thành công');
    } catch (e) {
      debugPrint('❌ Lỗi cập nhật placement summary: $e');
    }
  }

  /// ✅ Xử lý lesson final test hoàn thành
    Future<void> _handleLessonTestCompletion(double score) async {
  if (widget.lessonId == null) return;

  try {
    final targetScore = widget.targetScore ?? 50.0;
    final isPassed = score >= targetScore;

    debugPrint('═══════════════════════════════════════');
    debugPrint('📊 UPDATING LESSON PROGRESS');
    debugPrint('   lesson_id: ${widget.lessonId}');
    debugPrint('   user_id: $_userId');
    debugPrint('   score: $score');
    debugPrint('   isPassed: $isPassed');
    debugPrint('═══════════════════════════════════════');

    final attemptNum = await _getNextAttemptNumber();

    // ✅ Step 1: Create attempt record
    await supabase.from('user_lesson_attempts').insert({
      'user_id': _userId,
      'lesson_id': widget.lessonId,
      'attempt_number': attemptNum,
      'score': score,
      'is_passed': isPassed,
      'finished_at': DateTime.now().toIso8601String(),
    });
    debugPrint('✅ Attempt created');

    // ✅ Step 2: Check existing progress
    debugPrint('📝 Checking existing progress...');
    
    final existingData = await supabase
        .from('user_progress_lessons_course')
        .select()
        .eq('user_id', _userId!)
        .eq('lesson_id', widget.lessonId!)
        .maybeSingle();

    debugPrint('📋 Existing data: $existingData');

    if (existingData == null) {
      // ✅ INSERT mới
      debugPrint('📝 Creating new progress record...');
      
      await supabase.from('user_progress_lessons_course').insert({
        'user_id': _userId,
        'lesson_id': widget.lessonId, // ✅ UUID
        'status': 'in_progress',
        'score': 0,
        'is_passed': false,
        'attempts': 0,
      });
      
      debugPrint('✅ Progress record created');
    }

    // ✅ Step 3: UPDATE to completed
    debugPrint('📝 Updating progress to completed...');
    
    // ✅ DEBUG: Print update data trước khi gửi
    final updateData = {
      'status': 'completed',
      'score': score,
      'is_passed': isPassed,
      'attempts': attemptNum,
      'completed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    debugPrint('📦 Update data: $updateData');
    debugPrint('🔑 Where clause: user_id=$_userId, lesson_id=${widget.lessonId}');

    // ✅ FIX: Kiểm tra lessonId không phải là lesson_type
    if (widget.lessonId == null || widget.lessonId == 'final_test' || widget.lessonId == 'mid_test') {
      debugPrint('❌ INVALID LESSON_ID: ${widget.lessonId}');
      throw Exception('Invalid lesson_id: ${widget.lessonId}');
    }

    await supabase
        .from('user_progress_lessons_course')
        .update(updateData)
        .eq('user_id', _userId!)
        .eq('lesson_id', widget.lessonId!); // ✅ Phải là UUID, không phải "final_test"
    
    debugPrint('✅ Progress updated - TRIGGER SHOULD FIRE');

    // ✅ Wait for trigger
    await Future.delayed(Duration(milliseconds: 1000));

    // ✅ Verify notification
    final notification = await supabase
        .from('notifications')
        .select()
        .eq('user_id', _userId!)
        .eq('type', 'ket_qua_test')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (notification != null) {
      debugPrint('✅ Notification: ${notification['title']}');
    } else {
      debugPrint('⚠️ Notification not found!');
    }

    if (isPassed) {
      await _unlockNextLesson();
    }

    debugPrint('═══════════════════════════════════════');
  } catch (e, stackTrace) {
    debugPrint('❌ Error: $e');
    debugPrint('📍 Stack trace: $stackTrace');
  }
}
  /// ✅ Lấy attempt number tiếp theo
  Future<int> _getNextAttemptNumber() async {
    if (widget.lessonId == null) return 1;

    try {
      final result = await supabase
          .from('user_lesson_attempts')
          .select('attempt_number')
          .eq('user_id', _userId!)
          .eq('lesson_id', widget.lessonId!)
          .order('attempt_number', ascending: false)
          .limit(1)
          .maybeSingle();

      return (result?['attempt_number'] as int? ?? 0) + 1;
    } catch (e) {
      debugPrint('Error getting next attempt number: $e');
      return 1;
    }
  }

  /// ✅ Unlock bài học tiếp theo
  Future<void> _unlockNextLesson() async {
    if (widget.lessonId == null) return;

    try {
      // Get current lesson
      final currentLesson = await supabase
          .from('lessons_course')
          .select('module_id, order_index')
          .eq('id', widget.lessonId!)
          .single();

      // Get next lesson
      final nextLesson = await supabase
          .from('lessons_course')
          .select('id')
          .eq('module_id', currentLesson['module_id'])
          .gt('order_index', currentLesson['order_index'])
          .order('order_index', ascending: true)
          .limit(1)
          .maybeSingle();

      if (nextLesson != null) {
        await supabase
            .from('lessons_course')
            .update({'is_locked': false}).eq('id', nextLesson['id']);

        debugPrint('✅ Unlock next lesson: ${nextLesson['id']}');
      }
    } catch (e) {
      debugPrint('❌ Lỗi unlock next lesson: $e');
    }
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
        title: Text(widget.isPlacementTest ? 'Kiểm tra đầu vào' : 'Kiểm tra cuối bài'),
        centerTitle: true,
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
                      color: _timeRemaining < 300 ? Colors.red : Colors.white),
                  SizedBox(width: 4),
                  Text(
                    _formatTime(_timeRemaining),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _timeRemaining < 300 ? Colors.red : Colors.white,
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
                valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            question.questionText ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (question.questionType == 'fill_blank') ...[
          TextField(
            decoration: InputDecoration(
              labelText: 'Nhập đáp án của bạn...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.blueAccent, width: 2),
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
                  await Future.delayed(Duration(milliseconds: 300));
                  await supabase.from('user_test_answers').upsert({
                    'result_id': _resultId,
                    'question_id': question.id,
                    'user_answer': value,
                    'is_correct': value.trim().toLowerCase() ==
                        question.correctAnswer?.trim().toLowerCase(),
                    'answered_at': DateTime.now().toIso8601String(),
                  }, onConflict: 'result_id,question_id');

                  debugPrint('✅ Đã lưu câu trả lời: $value');
                } catch (e) {
                  debugPrint('❌ Lỗi lưu user_test_answers: $e');
                }
              }
            },
          ),
        ] else if (options.isNotEmpty) ...[
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

                      debugPrint('✅ Đã lưu câu trả lời: ${question.id}');
                    } catch (e) {
                      debugPrint('❌ Lỗi lưu user_test_answers: $e');
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
                        width: 32,
                        height: 32,
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
                            ? Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : Center(
                              child: Text(
                                optionKey,
                                style: TextStyle(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (group.mediaType == 'audio' && group.mediaUrl != null)
          AudioPlayerWidget(audioUrl: group.mediaUrl!)
        else if (group.mediaType == 'text' && group.content != null)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              group.content!,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.black87,
              ),
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
        ...group.testQuestions.asMap().entries.map((entry) {
          final qIndex = entry.key;
          final question = entry.value;
          final questionNumber = qIndex + 1;

          List<MapEntry<String, String>> options = [];
          if (question.options != null) {
            if (question.options is Map) {
              final optionsMap = question.options as Map;
              options = optionsMap.entries
                  .map((e) =>
                      MapEntry(e.key.toString(), e.value.toString()))
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
                Text(
                  '$questionNumber. ${question.questionText ?? ''}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                if (question.questionType == 'fill_blank')
                  TextFormField(
                    initialValue: _userAnswers[question.id] ?? '',
                    decoration: InputDecoration(
                      labelText: 'Nhập đáp án của bạn...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) async {
                      setState(() {
                        _userAnswers[question.id] = value;
                      });

                      if (_resultId != null) {
                        try {
                          await Future.delayed(
                              Duration(milliseconds: 300));
                          await supabase.from('user_test_answers')
                              .upsert({
                            'result_id': _resultId,
                            'question_id': question.id,
                            'user_answer': value,
                            'is_correct': value.trim().toLowerCase() ==
                                question.correctAnswer
                                    ?.trim()
                                    .toLowerCase(),
                            'answered_at':
                                DateTime.now().toIso8601String(),
                          }, onConflict: 'result_id,question_id');

                          debugPrint(
                              '✅ Đã lưu câu điền khuyết: ${question.id}');
                        } catch (e) {
                          debugPrint(
                              '❌ Lỗi lưu user_test_answers (fill_blank): $e');
                        }
                      }
                    },
                  ),
                if (question.questionType != 'fill_blank' &&
                    options.isNotEmpty)
                  ...options.map((opt) {
                    final isSelected =
                        _userAnswers[question.id] == opt.key;
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () async {
                          setState(() {
                            _userAnswers[question.id] = opt.key;
                          });
                          if (_resultId != null) {
                            await supabase.from('user_test_answers')
                                .upsert({
                              'result_id': _resultId,
                              'question_id': question.id,
                              'user_answer': opt.key,
                              'is_correct': opt.key ==
                                  question.correctAnswer,
                              'answered_at':
                                  DateTime.now().toIso8601String(),
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
                                  color: isSelected
                                      ? Colors.purple
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.purple
                                        : Colors.grey.shade400,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(Icons.check,
                                        color: Colors.white, size: 16)
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
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.purple
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
}