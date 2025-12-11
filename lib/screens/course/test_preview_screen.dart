import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lesson_course.dart';
import '../../services/auth/auth_service.dart';
import 'final_test_screen.dart';

class TestPreviewScreen extends StatefulWidget {
  final String testId;
  final String lessonId;
  final LessonCourse lesson;

  const TestPreviewScreen({
    required this.testId,
    required this.lessonId,
    required this.lesson,
    super.key,
  });

  @override
  State<TestPreviewScreen> createState() => _TestPreviewScreenState();
}

class _TestPreviewScreenState extends State<TestPreviewScreen> {
  final supabase = Supabase.instance.client;
  final _authService = AuthService();

  bool _isLoading = true;
  Map<String, dynamic>? _testInfo;
  Map<String, dynamic>? _userResult;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadTestData();
  }

  Future<void> _loadTestData() async {
    try {
      setState(() => _isLoading = true);

      debugPrint('═══════════════════════════════════════');
      debugPrint('📊 Loading Test Data');
      debugPrint('═══════════════════════════════════════');
      debugPrint('   testId: ${widget.testId}');

      // ✅ Get current user ID
      final authUser = supabase.auth.currentUser;
      if (authUser != null) {
        _userId = await _authService.getUserIdFromAuthId(authUser.id);
        debugPrint('   userId: $_userId');
      }

      // ✅ Fetch test info
      debugPrint('🔍 Fetching test info...');
      final testRes = await supabase
          .from('tests')
          .select('id, test_name, time_limit, total_questions, test_type')
          .eq('id', widget.testId)
          .maybeSingle();

      debugPrint('📋 Raw test response: $testRes');
      if (testRes != null) {
        debugPrint('   test_name: ${testRes['test_name']}');
        debugPrint('   time_limit: ${testRes['time_limit']}');
        debugPrint('   total_questions: ${testRes['total_questions']}');
      } else {
        debugPrint('❌ Test not found!');

        final allTests = await supabase
            .from('tests')
            .select('id, test_name, time_limit, total_questions')
            .limit(5);
        debugPrint('📊 All tests in DB: $allTests');
      }

      // ✅ Fetch user's last result - FIX: Remove created_at
      Map<String, dynamic>? userRes;
      if (_userId != null) {
        debugPrint('🔍 Fetching user results...');
        try {
          userRes = await supabase
              .from('user_test_results')
              .select(
                  'id, score, total_questions, correct_answers, status, completed_at')
              .eq('user_id', _userId!)
              .eq('test_id', widget.testId)
              .order('completed_at', ascending: false)
              .limit(1)
              .maybeSingle();

          debugPrint('👤 User result: $userRes');
        } catch (e) {
          debugPrint('⚠️ Error fetching user results: $e');
          debugPrint('   Trying alternative query without ordering...');

          // Fallback: query without ordering by completed_at
          try {
            userRes = await supabase
                .from('user_test_results')
                .select(
                    'id, score, total_questions, correct_answers, status, completed_at')
                .eq('user_id', _userId!)
                .eq('test_id', widget.testId)
                .limit(1)
                .maybeSingle();

            debugPrint('✅ Fallback query success: $userRes');
          } catch (e2) {
            debugPrint('❌ Fallback also failed: $e2');
          }
        }
      }

      setState(() {
        _testInfo = testRes;
        _userResult = userRes;
        _isLoading = false;
      });

      debugPrint('═══════════════════════════════════════');
      debugPrint('✅ Test data loaded');
      debugPrint('═══════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading test data: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.lesson.lessonName, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Test thông tin header
                    _buildTestInfoCard(),
                    const SizedBox(height: 24),

                    // ✅ Nếu chưa làm test
                    if (_userResult == null) ...[
                      _buildNotStartedSection(),
                    ] else ...[
                      // ✅ Nếu đã làm test
                      _buildResultSection(),
                    ],

                    const SizedBox(height: 32),

                    // ✅ Nút action
                    _buildActionButtons(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTestInfoCard() {
    final timeLimit = _testInfo?['time_limit'] as int? ?? 0;
    final totalQuestions = _testInfo?['total_questions'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade700],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.quiz,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _testInfo?['test_name'] ?? 'Bài kiểm tra',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kiểm tra cuối bài',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoColumn(
                icon: Icons.help_outline,
                label: 'Số câu',
                value: '$totalQuestions',
              ),
              _buildInfoColumn(
                icon: Icons.timer,
                label: 'Thời gian',
                value: '$timeLimit phút',
              ),
              _buildInfoColumn(
                icon: Icons.percent,
                label: 'Điểm cần',
                value: '${widget.lesson.targetScore?.toStringAsFixed(0) ?? '50'}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildNotStartedSection() {
    return Column(
      children: [
        // ✅ Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.shade50,
            border: Border.all(color: Colors.green.shade200, width: 2),
          ),
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.green.shade600,
            size: 48,
          ),
        ),
        const SizedBox(height: 20),

        // ✅ Tiêu đề
        Text(
          'Bạn chưa làm bài kiểm tra này',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // ✅ Mô tả
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hãy làm bài kiểm tra này để kiểm tra kiến thức của bạn.',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.amber.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bạn cần đạt ${widget.lesson.targetScore?.toStringAsFixed(0) ?? '50'}% để vượt qua',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection() {
    final score = _userResult?['score'] as num? ?? 0;
    final correctAnswers = _userResult?['correct_answers'] as int? ?? 0;
    final totalQuestions = _userResult?['total_questions'] as int? ?? 0;
    final status = _userResult?['status'] as String? ?? 'unknown';
    final completedAt = _userResult?['completed_at'] as String?;

    final targetScore = widget.lesson.targetScore ?? 50.0;
    final isPassed = score >= targetScore;

    // ✅ FIX: Validate totalQuestions trước khi tính toán
    if (totalQuestions == 0) {
      debugPrint('⚠️ totalQuestions is 0, cannot calculate progress');
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange.shade700),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bài kiểm tra chưa hoàn thành. Vui lòng làm lại!',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ Tính số câu cần đúng để vượt qua
    final targetCorrectAnswers = (totalQuestions * targetScore / 100).ceil();
    final moreCorrectNeeded = (targetCorrectAnswers - correctAnswers).clamp(0, totalQuestions);
    final percentNeedMore = (targetScore - score).clamp(0.0, 100.0);

    // ✅ Safe progress calculation
    final progressValue = targetCorrectAnswers > 0
        ? (correctAnswers / targetCorrectAnswers).clamp(0.0, 1.0)
        : 0.0;

    debugPrint('📊 Score calculation:');
    debugPrint('   totalQuestions: $totalQuestions');
    debugPrint('   correctAnswers: $correctAnswers');
    debugPrint('   targetScore: $targetScore%');
    debugPrint('   targetCorrectAnswers: $targetCorrectAnswers');
    debugPrint('   moreCorrectNeeded: $moreCorrectNeeded');
    debugPrint('   progressValue: $progressValue');

    return Column(
      children: [
        // ✅ Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isPassed ? Colors.green.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPassed ? Colors.green.shade300 : Colors.red.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPassed ? Icons.check_circle : Icons.cancel,
                color: isPassed ? Colors.green.shade700 : Colors.red.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isPassed ? 'Đã vượt qua' : 'Chưa vượt qua',
                style: TextStyle(
                  color: isPassed ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ✅ Score circle
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                isPassed ? Colors.green.shade400 : Colors.orange.shade400,
                isPassed ? Colors.green.shade700 : Colors.orange.shade700,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: (isPassed ? Colors.green : Colors.orange).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${score.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ✅ Details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              _buildDetailRow(
                Icons.check_circle_outline,
                'Câu trả lời đúng',
                '$correctAnswers/$totalQuestions',
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.trending_up,
                'Cần đạt',
                '$targetCorrectAnswers/$totalQuestions câu',
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.calendar_today,
                'Hoàn thành lúc',
                _formatDate(completedAt),
                Colors.purple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ✅ Warning if not passed
        if (!isPassed && moreCorrectNeeded > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_outlined, color: Colors.orange.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cần cố gắng thêm',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Số câu cần đúng thêm',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$moreCorrectNeeded câu',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Cần thêm ${percentNeedMore.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // ✅ FIX: Safe progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressValue, // ✅ Safe value (0.0 - 1.0)
                          minHeight: 6,
                          backgroundColor: Colors.orange.shade100,
                          valueColor: AlwaysStoppedAnimation(Colors.orange.shade600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tiến độ: $correctAnswers/$targetCorrectAnswers câu',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[900],
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final targetScore = widget.lesson.targetScore ?? 50.0;
    final score = _userResult?['score'] as num? ?? 0;
    final isPassed = score >= targetScore;

    return Column(
      children: [
        // ✅ Start/Retry button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => FinalTestScreen(
                    testId: widget.testId,
                    lessonId: widget.lessonId,
                    isPlacementTest: false,
                    targetScore: targetScore,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _userResult == null ? Icons.play_arrow : Icons.refresh,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _userResult == null ? 'Bắt đầu làm bài' : 'Làm lại bài kiểm tra',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        

        // ✅ Info message
        if (isPassed)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn có thể làm lại để nâng cao điểm số',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Chưa xác định';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      String _formatTime(DateTime dt) {
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final minute = dt.minute.toString().padLeft(2, '0');
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $amPm';
      }

      if (difference.inDays == 0) {
        return 'Hôm nay  ${_formatTime(date)}';
      } else if (difference.inDays == 1) {
        return 'Hôm qua  ${_formatTime(date)}';
      } else {
        return '${date.day}/${date.month}/${date.year}  ${_formatTime(date)}';
      }
    } catch (e) {
      return 'Chưa xác định';
    }
  }

}