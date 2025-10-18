import 'package:flutter/material.dart';
import 'package:learning_english/screens/grammar/conditionals/conditionals_screen.dart';
import 'package:learning_english/screens/grammar/linking_verb/linkingVerbs_screen.dart';
import 'package:learning_english/screens/grammar/pronunciation_screen.dart';
import 'package:learning_english/screens/grammar/tenses/tenses_screen.dart';
import 'package:learning_english/widgets/grammar_category.dart';
import '../widgets/grammar_card.dart';
import '../service/grammar_service.dart';
import '../models/topic.dart';
import 'grammar/articles/articles_screen.dart';
import 'grammar/modalverbs/modalVerbs_screen.dart';
import 'grammar/passivevoice/passiveVoice_screen.dart';
import 'grammar/prepositions/prepositions_screen.dart';

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  final GrammarService _grammarService = GrammarService();
  List<GrammarCategory> grammarCategories = [];
  bool isLoading = true;
  String? errorMessage;

  // Map màu sắc và icon cho từng topic
  final Map<int, Map<String, dynamic>> topicStyles = {
    0: {'color': Colors.red, 'icon': Icons.swap_horiz},
    1: {'color': Colors.brown, 'icon': Icons.place},
    2: {'color': Colors.blue, 'icon': Icons.access_time},
    3: {'color': Colors.green, 'icon': Icons.link},
    4: {'color': Colors.purple, 'icon': Icons.alt_route},
    5: {'color': Colors.orange, 'icon': Icons.record_voice_over},
    6: {'color': Colors.indigo, 'icon': Icons.text_fields},
    7: {'color': Colors.teal, 'icon': Icons.psychology},
  };

  // Map screens cho từng topic (theo topic_name_en hoặc id)
  final Map<String, Widget Function()> topicScreens = {
    'Tenses': () => const TensesScreen(),
    'Pronunciation': () => const PronunciationScreen(),
    'Linking Verbs': () => const LinkingVerbsScreen(),
    'Conditionals': () => const ConditionalsScreen(),
    'Passive Voice': () => const PassiveVoicesScreen(),
    'Modal Verbs': () => const ModalverbsScreen(),
    'Articles': () => const ArticlesScreen(),
    'Prepositions': () => const PrepositionsScreen(),
  };

  @override
  void initState() {
    super.initState();
    _loadGrammarCategories();
  }

  Future<void> _loadGrammarCategories() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final topicsWithCount = await _grammarService.getTopicsWithLessonCount();

      List<GrammarCategory> categories = [];

      for (int i = 0; i < topicsWithCount.length; i++) {
        final data = topicsWithCount[i];
        final Topic topic = data['topic'];
        final int lessonCount = data['lessonCount'];

        // Lấy style theo index (tuần tự)
        final style = topicStyles[i % topicStyles.length] ??
            {'color': Colors.grey, 'icon': Icons.book};

        // Lấy screen tương ứng
        final screen = topicScreens[topic.topicNameEn] ??
                () => _DefaultTopicScreen(topic: topic);

        categories.add(
          GrammarCategory(
            title: topic.topicNameVi,
            description: topic.description,
            color: style['color'],
            icon: style['icon'],
            screen: screen,
            lessonCount: lessonCount,
          ),
        );
      }

      setState(() {
        grammarCategories = categories;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Info
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[500]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.school,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Master English Grammar',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hãy chọn 1 chủ đề để bắt đầu',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue[100],
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(
            color: Colors.blue, // Tùy chỉnh màu thành indigo[700]
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Có lỗi xảy ra',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadGrammarCategories,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (grammarCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox,
                size: 60,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có chủ đề nào',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7, // Giảm giá trị để tăng chiều cao
      ),
      itemCount: grammarCategories.length,
      itemBuilder: (context, index) {
        final category = grammarCategories[index];
        return GrammarCard(category: category);
      },
    );
  }
}

// Screen mặc định cho các topics chưa có màn hình riêng
class _DefaultTopicScreen extends StatelessWidget {
  final Topic topic;

  const _DefaultTopicScreen({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(topic.topicNameVi),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 20),
              Text(
                topic.topicNameVi,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                topic.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Màn hình này đang được phát triển',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}