import 'package:flutter/material.dart';
import 'package:learning_english/screens/drawer_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../models/question_group.dart';
import '../../models/test_question.dart';
import '../../widgets/audio_player.dart';

class PlacementTestScreen extends StatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  State<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends State<PlacementTestScreen> with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;

  String? _testId;
  String? _resultId;
  String? _userId;
  bool _isLoading = true;
  int _currentQuestionIndex = 0;

  List<dynamic> _items = [];
  Map<String, String> _userAnswers = {};
  bool _isPanelOpen = false;

  // ✅ UPDATED: Track audio plays per GROUP ID (not URL)
  final Map<String, int> _audioPlayCounts = {}; // groupId -> playCount
  final Map<String, bool> _isAudioPlaying = {}; // groupId -> isPlaying

  Timer? _timer;
  int _timeRemaining = 0;
  bool _isTimeUp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? testId = args?['testId'] as String?;
    if (testId != null && _testId != testId) {
      _testId = testId;
      _fetchQuestions(testId);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        }).eq('id', _resultId as String);
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
      }).eq('id', _resultId as String);
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
      }).eq('id', _resultId as String);
      
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
            child: Text('Đồng ý',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchQuestions(String testId) async {
    try {
      setState(() => _isLoading = true);

      final testInfo = await supabase
          .from('tests')
          .select('time_limit, test_type')
          .eq('id', testId)
          .single();

      final allItems = <dynamic>[];

      final directRes = await supabase
          .from('test_questions')
          .select()
          .eq('test_id', testId)
          .isFilter('group_id', null)
          .order('order_in_test', ascending: true);

      final directQuestions = 
          (directRes as List).map((q) => TestQuestion.fromJson(q)).toList();
      allItems.addAll(directQuestions);

      final groupRes = await supabase
          .from('question_groups')
          .select('''
          id, test_id, title, instruction, media_type, media_url, content, order_in_test,
          test_questions!inner(*)
        ''')
          .eq('test_id', testId)
          .order('order_in_test', ascending: true);

      for (final g in groupRes) {
        final group = QuestionGroup.fromJson(g);
        group.testQuestions.sort((a, b) => 
            (a.orderInTest ?? 0).compareTo(b.orderInTest ?? 0));
        allItems.add(group);
      }

      allItems.sort((a, b) {
        final orderA = a is TestQuestion ? a.orderInTest : (a as QuestionGroup).orderInTest;
        final orderB = b is TestQuestion ? b.orderInTest : (b as QuestionGroup).orderInTest;
        return (orderA ?? 0).compareTo(orderB ?? 0);
      });

      await _createUserTestResult();

      if (testInfo['time_limit'] != null) {
        _startTimer(testInfo['time_limit']);
      }

      setState(() {
        _items = allItems;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading questions: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ UPDATE: _nextQuestion to track audio plays
  void _nextQuestion() {
    // Track audio play when leaving current question
    final currentItem = _items[_currentQuestionIndex];
    if (currentItem is QuestionGroup && currentItem.mediaType == 'audio') {
      final isPlaying = _isAudioPlaying[currentItem.id] ?? false;
      if (isPlaying) {
        setState(() {
          final currentCount = _audioPlayCounts[currentItem.id] ?? 0;
          if (currentCount == 0) {
            _audioPlayCounts[currentItem.id] = 1;
            debugPrint('⚠️ Audio interrupted: ${currentItem.id}, counted as 1 play');
          }
          _isAudioPlaying[currentItem.id] = false;
        });
      }
    }

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

  // ✅ UPDATE: _previousQuestion to track audio plays
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

    // Original navigation logic
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
              (q) => _userAnswers[q.id]?.trim().isNotEmpty ?? false
      );
    }

    return false;
  }

  Future<void> _createUserTestResult() async {
    final authId = supabase.auth.currentUser?.id;

    if(authId != null){
      debugPrint('⚠️ Có user: $authId');
    }
    if (authId == null || _testId == null) {
      debugPrint('⚠️ Không có auth user hoặc test ID');
      return;
    }

    try {
      final userRecord = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', authId)
          .maybeSingle();

      if (userRecord == null) {
        debugPrint('❌ Không tìm thấy user với auth_id: $authId');
        debugPrint('💡 Cần tạo user trong bảng users trước khi làm bài test');
      } else {
        _userId = userRecord['id'];
        debugPrint('✅ Tìm thấy user id: $_userId');
      }

      final existing = await supabase
          .from('user_test_results')
          .select('id, status')
          .eq('user_id', _userId as String)
          .eq('test_id', _testId as String)
          .maybeSingle();

      if (existing != null) {
        _resultId = existing['id'];
        
        if (existing['status'] == 'in_progress' && 
            existing['time_remaining'] != null) {
          _startTimer(existing['time_remaining']);
        }
      } else {
        final newResult = await supabase.from('user_test_results').insert({
          'user_id': _userId,
          'test_id': _testId,
          'status': 'in_progress',
          'started_at': DateTime.now().toIso8601String(),
          'last_activity': DateTime.now().toIso8601String(),
        }).select('id').single();

        _resultId = newResult['id'];
      }
    } catch (e) {
      debugPrint('❌ Lỗi tạo user_test_results: $e');
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

    if (_resultId != null) {
      await supabase.from('user_test_results').update({
        'score': score,
        'total_questions': total,
        'correct_answers': correct,
        'status': _isTimeUp ? 'timeout' : 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'time_remaining': 0,
      }).eq('id', _resultId as String);
    }

    final testInfo = await supabase
        .from('tests')
        .select('test_type, recommended_course_id')
        .eq('id', _testId as String)
        .single();

    if (testInfo['test_type'] == 'placement') {
      await supabase.from('user_placement_summary').upsert({
        'user_id': _userId,
        'placement_test_id': _testId,
        'latest_result_id': _resultId,
        'score': score,
        'recommended_course_id': testInfo['recommended_course_id'],
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    _showResultDialog(score, correct, total, testInfo['recommended_course_id']);
  }

  Future<void> _showResultDialog(double score, int correct, int total, String? recommendedCourseId) async {
    try {
      final placementData = await supabase
          .from('user_placement_summary')
          .select('''
            score,
            courses:recommended_course_id (
              course_name
            )
          ''')
          .eq('user_id', _userId as String)
          .eq('placement_test_id', _testId as String)
          .single();

      if (placementData == null) {
        debugPrint('❌ Không tìm thấy thông tin placement test');
        return;
      }

      debugPrint('✅ Tìm thấy khóa học phù hợp: ${placementData['courses']['course_name']}');

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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

                Text(
                  'Kết quả bài kiểm tra',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
                SizedBox(height: 20),
                
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

                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        Icons.check_circle_outline,
                        'Số câu đúng',
                        '$correct/$total',
                        Colors.green,
                      ),
                      SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.school,
                        'Khóa học phù hợp',
                        placementData['courses']['course_name'] ?? 'Chưa xác định',
                        Colors.blue,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

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
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DrawerScreen(initialIndex: 1),
                            ),
                            (route) => false,
                          );
                        },
                        child: Text(
                          'Xem khóa học',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/homedrawer');
                      },
                      child: Text('Về trang chủ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy thông tin khóa học: $e');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Kết quả bài kiểm tra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Điểm số: ${score.toStringAsFixed(1)}%'),
              Text('Số câu đúng: $correct/$total'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/homedrawer'),
              child: Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String title, String value, Color iconColor) {
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Kiểm tra đầu vào'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('Không tìm thấy câu hỏi nào.')),
      );
    }

    final currentItem = _items[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm tra đầu vào'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
            const Text(
              'Bạn chắc chắn muốn thoát khỏi bài kiểm tra?',
              style: TextStyle(fontSize: 16),
            ),
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
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
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
            child: const Text(
              'Tiếp tục làm bài',
              style: TextStyle(color: Colors.blue),
            ),
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
            child: const Text(
              'Thoát',
              style: TextStyle(color: Colors.white),
            ),
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
                  await Future.delayed(Duration(milliseconds: 300));
                  
                  await supabase.from('user_test_answers').upsert({
                    'result_id': _resultId,
                    'question_id': question.id,
                    'user_answer': value,
                    'is_correct': value.trim().toLowerCase() == question.correctAnswer?.trim().toLowerCase(),
                    'answered_at': DateTime.now().toIso8601String(),
                  }, onConflict: 'result_id,question_id');

                  debugPrint('✅ Đã lưu câu trả lời: $value cho câu ${question.id}');
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
                  } else {
                    debugPrint('⚠️ Chưa có result_id, không thể lưu câu trả lời');
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
                            ? Icon(Icons.check, color: Colors.white, size: 20)
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
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? Colors.blueAccent : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ] else ...[
          Center(
            child: Text(
              'Không có đáp án',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }

  // ✅ FIXED: _buildGroupQuestions with proper audio tracking
  Widget _buildGroupQuestions(QuestionGroup group) {
    // ✅ Initialize play count for this specific group
    if (!_audioPlayCounts.containsKey(group.id)) {
      _audioPlayCounts[group.id] = 0;
    }
    
    final remainingPlays = 2 - (_audioPlayCounts[group.id] ?? 0);

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
            child: Text(
              group.content!,
              style: TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
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
                Text(
                  '$questionNumber. ${question.questionText ?? ''}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),

                if (question.questionType == 'fill_blank')
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
                  ),

                if (question.questionType != 'fill_blank' && options.isNotEmpty)
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
                _currentQuestionIndex == _items.length - 1 ? 'Nộp bài' : 'Tiếp theo',
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
                    final isAnswered = _userAnswers[question.id]?.trim().isNotEmpty ?? false;
                    final isCurrent = _getCurrentQuestionIndex(index);

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
                 flatIndex < currentFlatIndex + group.testQuestions.length;
        }
      }
      
      if (_items[i] is TestQuestion) {
        currentFlatIndex++;
      } else if (_items[i] is QuestionGroup) {
        currentFlatIndex += (_items[i] as QuestionGroup).testQuestions.length;
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
              color: (isAnswered || isCurrent) ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ✅ UPDATE: _jumpToFlattenedQuestion to track audio plays
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