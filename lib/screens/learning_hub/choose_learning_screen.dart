import 'package:flutter/material.dart';
import 'package:learning_english/screens/learning_hub/review_wrong_questions_screen.dart';
import '../ai_practice/ai_practice_check_screen.dart';
import '../../services/learning_service.dart';

class ChooseLearningScreen extends StatelessWidget {
  final List<LearningMistake> mistakes; // 🔥 NEW: All mistakes

  const ChooseLearningScreen({
    super.key,
    required this.mistakes, // 🔥 REQUIRED
  });

  // 🔥 Helper: Calculate total mistakes
  int get totalMistakes {
    return mistakes.fold<int>(0, (sum, m) => sum + m.mistakeCount);
  }

  // 🔥 Helper: Get top mistake
  LearningMistake get topMistake {
    return mistakes.isNotEmpty ? mistakes.first : LearningMistake(
      lessonName: 'Unknown',
      mistakeCount: 0,
      source: 'combined',
    );
  }

  // 🔥 Helper: Format all topics
  String get formattedTopics {
    if (mistakes.isEmpty) return 'Unknown';
    
    if (mistakes.length == 1) {
      return mistakes.first.lessonName;
    }
    
    if (mistakes.length == 2) {
      return '${mistakes[0].lessonName} , ${mistakes[1].lessonName}';
    }
    
    // For 3+ topics: "Topic1, Topic2 và Topic3"
    final topicsExceptLast = mistakes.take(mistakes.length - 1)
        .map((m) => m.lessonName)
        .join(', ');
    
    return '$topicsExceptLast , ${mistakes.last.lessonName}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Gợi ý học tập',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER CARD - Lỗi gặp phải
            _buildErrorCard(),

            SizedBox(height: 24),

            // TITLE
            Text(
              'Lựa chọn phương pháp học',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 16),

            // OPTION 1 - Xem lại bài tập sai
            _buildOption1Card(context),

            SizedBox(height: 16),

            // OPTION 2 - Luyện tập với AI
            _buildOption2Card(context),

            SizedBox(height: 24),

            // TIPS SECTION
            _buildTipsSection(),
          ],
        ),
      ),
    );
  }

  // HEADER CARD - Hiển thị TẤT CẢ lỗi
  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFFEF5350),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFEF5350).withOpacity(0.2),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFEF5350).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Color(0xFFD32F2F),
                  size: 32,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lỗi gặp phải',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      topMistake.lessonName, // ✅ Top mistake
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB71C1C),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),

          // 🔥 MESSAGE - Tổng số câu sai
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cancel,
                  color: Color(0xFFEF5350),
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bạn đã sai tổng cộng $totalMistakes câu trong ${mistakes.length} chủ đề khác nhau!', // ✅ Dynamic message
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF424242),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // 🔥 DANH SÁCH TẤT CẢ LỖI
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.list, color: Color(0xFFEF5350), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Chi tiết các lỗi (7 ngày qua):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // List all mistakes
                ...mistakes.map((mistake) => _buildMistakeItem(mistake)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 Helper: Build mistake item
  Widget _buildMistakeItem(LearningMistake mistake) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(0xFFEF5350).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${mistake.mistakeCount}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              mistake.lessonName,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF424242),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // OPTION 1 - Xem lại bài tập sai
  Widget _buildOption1Card(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // TODO: Navigate to exercise review with all mistakes
        final bool? needsRefresh = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewWrongQuestionsScreen(),
          ),
        );
        if (needsRefresh == true && context.mounted) {
        Navigator.pop(context, true); // ✅ Signal home to refresh
      }
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Color(0xFF2196F3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF2196F3).withOpacity(0.2),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Color(0xFF2196F3).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.assignment,
                    color: Color(0xFF1976D2),
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Option 1',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Khuyên dùng',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Xem lại bài tập sai',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF1976D2),
                  size: 20,
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Những gì bạn sẽ có:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF424242),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  _buildBulletPoint('Xem lại từng câu đã làm sai'),
                  _buildBulletPoint('Giải thích chi tiết từng lỗi'),
                  _buildBulletPoint('Lộ trình học tập phù hợp'),
                  _buildBulletPoint('Theo dõi tiến độ cải thiện'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // OPTION 2 - Luyện tập với AI
  Widget _buildOption2Card(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AiPracticeCheckScreen(
              topic: formattedTopics, // ✅ Use formatted topics
              mistakeCount: totalMistakes,
            ),
          ),
        );

        if (result == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Hoàn thành bài luyện tập!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Color(0xFF9C27B0),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF9C27B0).withOpacity(0.2),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFAB47BC), Color(0xFF9C27B0)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF9C27B0).withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Option 2',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7B1FA2),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Mới',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Luyện tập với AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6A1B9A),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF9C27B0),
                  size: 20,
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFFFF9800), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Những gì bạn sẽ có:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF424242),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  _buildBulletPoint('Bài tập được AI tạo riêng cho bạn'),
                  _buildBulletPoint('Độ khó tự động điều chỉnh'),
                  _buildBulletPoint('Phản hồi chi tiết tức thì'),
                  _buildBulletPoint('Luyện tập không giới hạn'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TIPS SECTION
  Widget _buildTipsSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFFFFB74D),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                color: Color(0xFFFF9800),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Mẹo học tập',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildTipItem('Học 15-20 phút mỗi ngày tốt hơn học dồn 2 giờ cuối tuần'),
          _buildTipItem('Xem lại lỗi ngay sau khi làm bài để ghi nhớ tốt hơn'),
          _buildTipItem('Thực hành với AI giúp bạn đa dạng bài làm hơn'),
        ],
      ),
    );
  }

  // Helper: Bullet point
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(0xFF2196F3),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF424242),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Tip item
  Widget _buildTipItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFFFF9800),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF5D4037),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}