import 'package:flutter/material.dart';
import 'package:learning_english/services/learning_service.dart';

// =========================================================================
// 1. WIDGETS ĐỊNH NGHĨA (LessonDetailScreen, QuizScreen)
// =========================================================================

class LessonDetailScreen extends StatelessWidget {
  final String lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ôn Lại Bài Học')),
      body: Center(
        child: Text('Nội dung lý thuyết/ôn tập cho Lesson ID: $lessonId'),
      ),
    );
  }
}

class QuizScreen extends StatelessWidget {
  final String questionId;
  final String lessonId;

  const QuizScreen({
    super.key,
    required this.questionId,
    required this.lessonId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ôn Tập Câu Hỏi')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ôn tập câu hỏi ID: $questionId từ bài học $lessonId'),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hoàn thành'),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 2. WIDGET CHÍNH: ReviewWrongQuestionsScreen
// =========================================================================

class ReviewWrongQuestionsScreen extends StatefulWidget {
  const ReviewWrongQuestionsScreen({super.key});

  @override
  State<ReviewWrongQuestionsScreen> createState() => _ReviewWrongQuestionsScreenState();
}

class _ReviewWrongQuestionsScreenState extends State<ReviewWrongQuestionsScreen> {
  final LearningService _service = LearningService();
  List<Map<String, dynamic>> wrongQuestions = [];
  bool isLoading = true;
  String? userId;

  @override
  void initState() {
    super.initState();
    _fetchUserIdAndData();
  }

  // 🚨 HÀM CẬP NHẬT CSDL: Đánh dấu câu hỏi là đã ôn tập (is_correct = true)
  Future<void> _markAsReviewed(String type, Map<String, dynamic> item) async {
    if (userId == null || userId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy ID người dùng để cập nhật.')));
      }
      return;
    }

    setState(() {
      item['is_updating'] = true;
    });

    try {
      await _service.markAsReviewed(type, item, userId!);

      // Tải lại dữ liệu để câu hỏi biến mất
      await _fetchWrongQuestions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xác nhận và cập nhật thành công! ✅')));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi xác nhận và cập nhật: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          item['is_updating'] = false;
        });
      }
    }
  }

  Future<void> _fetchUserIdAndData() async {
    userId = await _service.fetchUserId();

    if (userId == null || userId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Lỗi: Không tìm thấy ID người dùng nào.')),
        );
        if (mounted) Navigator.pop(context);
      }
      setState(() => isLoading = false);
      return;
    }

    await _fetchWrongQuestions();
  }

  Future<void> _fetchWrongQuestions() async {
    if (userId == null || userId!.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await _service.fetchWrongQuestions(userId!);

      if (mounted) {
        setState(() {
          // Khởi tạo trạng thái is_updating cho từng item
          wrongQuestions = response.map((item) => {
            ...item,
            'is_updating': false,
          }).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu từ RPC: $e')),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // LOGIC NHÓM: Nhóm theo Lesson Title và Loại Bài Tập
  Map<String, List<Map<String, dynamic>>> _groupByLesson() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var q in wrongQuestions) {
      final lessonTitle = q['lesson_title']?.toString() ?? 'Bài học không xác định';
      final type = q['type']?.toString() ?? 'unknown';

      final String typeLabel = type == 'grammar' ? 'Ngữ pháp' : 'Lộ trình';
      final String groupKey = '$lessonTitle | $typeLabel';

      grouped.putIfAbsent(groupKey, () => []).add(q);
    }
    return grouped;
  }

  // 🚨 HÀM ĐÃ SỬA: CHỈ GỌI CẬP NHẬT CSDL (KHÔNG CHUYỂN TRANG)
  void _retryAction(BuildContext context, Map<String, dynamic> item) {
    final itemType = item['type']?.toString() ?? 'grammar';

    final lessonId = item['lesson_id']?.toString() ?? '';
    if (lessonId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xác nhận: Thiếu ID bài học.')),
      );
      return;
    }

    // CHỈ GỌI HÀM CẬP NHẬT CSDL
    _markAsReviewed(itemType, item);
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2D3142), size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ôn Tập Câu Sai',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE8EAF0),
            height: 1,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B8DEE)),
        ),
      )
          : wrongQuestions.isEmpty
          ? _buildEmptyState()
          : Container(
        constraints: BoxConstraints(maxWidth: isWideScreen ? 1200 : double.infinity),
        margin: EdgeInsets.symmetric(horizontal: isWideScreen ? 32 : 0),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: isWideScreen ? 0 : 16,
            right: isWideScreen ? 0 : 16,
            top: 20,
            bottom: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              ..._groupByLesson().entries.map((entry) {
                return _buildLessonGroup(entry.key, entry.value, isWideScreen);
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              size: 80,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Tuyệt vời!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bạn chưa có câu sai nào',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tiếp tục phát huy nhé! 🎯',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B8DEE), Color(0xFF0066FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B8DEE).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Các bài học có câu sai',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${wrongQuestions.length} câu hỏi cần ôn tập',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonGroup(String groupKey, List<Map<String, dynamic>> questions, bool isWideScreen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              groupKey.contains('Ngữ pháp') ? Icons.menu_book : Icons.route,
              color: groupKey.contains('Ngữ pháp') ? const Color(0xFF9C27B0) : const Color(0xFF5B8DEE),
              size: 24,
            ),
          ),
          title: Text(
            groupKey,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF2D3142),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${questions.length} câu hỏi',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          children: [
            if (isWideScreen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: questions.map((q) => SizedBox(
                    width: (MediaQuery.of(context).size.width - 100) / 2,
                    child: _buildQuestionCard(q),
                  )).toList(),
                ),
              )
            else
              ...questions.map((q) => _buildQuestionCard(q)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? 'N/A';
    final questionContent = item['question_content']?.toString() ?? '';
    final explanation = item['explanation']?.toString() ?? '';
    final userAnswer = item['user_answer']?.toString() ?? '';
    final timeSpent = item['time_spent'] as int? ?? 0;
    final isUpdating = item['is_updating'] as bool? ?? false;

    String sourceLabel = type == 'grammar' ? 'Ngữ pháp' : 'Lộ trình';
    Color sourceColor = type == 'grammar' ? const Color(0xFF9C27B0) : const Color(0xFF5B8DEE);
    IconData sourceIcon = type == 'grammar' ? Icons.menu_book : Icons.route;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: const Color(0xFFE8EAF0), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sourceColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(sourceIcon, size: 14, color: sourceColor),
                          const SizedBox(width: 6),
                          Text(
                            sourceLabel,
                            style: TextStyle(
                              color: sourceColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  questionContent,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF2D3142),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnswerSection(
                  icon: Icons.close,
                  iconColor: const Color(0xFFEF5350),
                  label: 'Đáp án của bạn',
                  answer: userAnswer.isEmpty ? 'Không có đáp án' : userAnswer,
                  timeSpent: timeSpent,
                ),
                const SizedBox(height: 12),
                _buildAnswerSection(
                  icon: Icons.check,
                  iconColor: const Color(0xFF66BB6A),
                  label: 'Xem giải thích',
                  answer: '',
                  isCorrect: true,
                ),

                if (explanation.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFB3D9FF), width: 1),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: const Icon(Icons.info_outline, color: Color(0xFF5B8DEE), size: 20),
                        title: const Text(
                          'Giải thích chi tiết',
                          style: TextStyle(
                            color: Color(0xFF5B8DEE),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              explanation,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isUpdating ? null : () => _retryAction(context, item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUpdating ? const Color(0xFFE8EAF0) : const Color(0xFF66BB6A),
                      foregroundColor: isUpdating ? Colors.grey[600] : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isUpdating
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Đang cập nhật...',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ],
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Xác nhận và cập nhật',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerSection({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String answer,
    int? timeSpent,
    bool isCorrect = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect
            ? const Color(0xFFF1F8F4)
            : const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCorrect
              ? const Color(0xFFB3E0C6)
              : const Color(0xFFFFCDD2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: iconColor,
                  ),
                ),
                if (answer.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    answer,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ],
                if (timeSpent != null && timeSpent > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '$timeSpent giây',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}