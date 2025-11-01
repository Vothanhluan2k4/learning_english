import 'package:flutter/material.dart';
import 'package:learning_english/services/grammar_service.dart';
import 'package:learning_english/models/lesson_content.dart';
import '../exercise_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final String lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final GrammarService _grammarService = GrammarService();
  Map<String, dynamic>? _lesson;
  List<LessonContent> _contents = [];
  int _exerciseCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    final lesson = await _grammarService.getLessonById(widget.lessonId);
    final contents = await _grammarService.getLessonContents(widget.lessonId);
    final exercises = await _grammarService.getExercisesByLesson(widget.lessonId);

    setState(() {
      _lesson = lesson;
      _contents = contents;
      _exerciseCount = exercises.length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 20),
              Text('Đang tải bài học...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_lesson == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Lỗi')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
              SizedBox(height: 16),
              Text('Không tìm thấy bài học.'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Quay lại'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          title: Text(_lesson!['title'] ?? 'Bài học'),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.black87,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              const Tab(
                icon: Icon(Icons.book),
                text: 'Nội dung',
              ),
              Tab(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.assignment),
                        SizedBox(width: 6),
                        Text('Bài tập'),
                      ],
                    ),
                    if (_exerciseCount > 0)
                      Positioned(
                        right: -25,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue, width: 1),
                          ),
                          child: Text(
                            '$_exerciseCount',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        body: TabBarView(
          children: [
            _buildContentTab(),
            ExerciseScreen(lessonId: widget.lessonId),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTab() {
    if (_contents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('Chưa có nội dung cho bài học này'),
          ],
        ),
      );
    }


    // Phân loại nội dung
    final structures = _contents.where((c) => c.type == 'structure').toList();
    final explanations = _contents.where((c) => c.type == 'explanation').toList();
    final examples = _contents.where((c) => c.type == 'example').toList();

    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với màu nền đơn giản
          Container(
            width: double.infinity,
            color: Colors.white, // Thay bằng màu nền mong muốn
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lesson!['title'] ?? '',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (_lesson!['description'] != null) ...[
                  SizedBox(height: 8),
                  Text(
                    _lesson!['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 📋 Công thức
          if (structures.isNotEmpty) ...[
            _buildSectionHeader(Icons.architecture, 'Công thức', Colors.orange),
            ...structures.map((content) => _buildStructureCard(content)),
          ],

          // 💡 Giải thích
          if (explanations.isNotEmpty) ...[
            _buildSectionHeader(Icons.lightbulb_outline, 'Giải thích', Colors.purple),
            ...explanations.map((content) => _buildExplanationCard(content)),
          ],

          // 📝 Ví dụ
          if (examples.isNotEmpty) ...[
            _buildSectionHeader(Icons.format_quote, 'Ví dụ minh họa', Colors.green),
            ...examples.map((content) => _buildExampleCard(content)),
          ],

          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStructureCard(LessonContent content) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.dataTitle != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  content.dataTitle!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            if (content.dataBody != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!, width: 2),
                ),
                child: Text(
                  content.dataBody!,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.black,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard(LessonContent content) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.dataTitle != null)
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.purple[400], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      content.dataTitle!,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                  ),
                ],
              ),
            if (content.dataBody != null) ...[
              SizedBox(height: 12),
              Text(
                content.dataBody!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ],
            if (content.exampleSentence != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(color: Colors.purple[400]!, width: 4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ví dụ:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[600],
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      content.exampleSentence!,
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                    ),
                    if (content.exampleTranslation != null) ...[
                      SizedBox(height: 6),
                      Text(
                        '→ ${content.exampleTranslation!}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExampleCard(LessonContent content) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[300]!, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.dataTitle != null)
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, color: Colors.green[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      content.dataTitle!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                ],
              ),
            if (content.exampleSentence != null) ...[
              SizedBox(height: 12),
              Text(
                content.exampleSentence!,
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (content.exampleTranslation != null) ...[
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_forward, size: 16, color: Colors.green[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      content.exampleTranslation!,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}