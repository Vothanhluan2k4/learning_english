import 'package:flutter/material.dart';
import 'package:learning_english/widgets/grammar_category.dart';
import '../widgets/grammar_card.dart';

// Import all your grammar lesson screens
import 'grammar/articles_screen.dart';
import 'grammar/conditionals_screen.dart';
import 'grammar/linkingVerbs_screen.dart';
import 'grammar/modalVerbs_screen.dart';
import 'grammar/passiveVoice_screen.dart';
import 'grammar/prepositions_screen.dart';
import 'grammar/pronunciation_screen.dart';
import 'grammar/tenses_screen.dart';

class GrammarScreen extends StatelessWidget {
  const GrammarScreen({super.key});

  final List<GrammarCategory> grammarCategories = const [
    GrammarCategory(
      title: "Thì",
      description: "Hiện tại, Quá khứ, Tương lai và cấu trúc",
      color: Colors.blue,
      icon: Icons.access_time,
      screen: TensesScreen.new,
      lessonCount: 12,
    ),
    GrammarCategory(
      title: "Phát âm",
      description: "Nguyên âm, phụ âm và ngữ điệu",
      color: Colors.orange,
      icon: Icons.record_voice_over,
      screen: PronunciationScreen.new,
      lessonCount: 8,
    ),
    GrammarCategory(
      title: "Linking verbs",
      description: "Be, seem, become và các động từ nối khác",
      color: Colors.green,
      icon: Icons.link,
      screen: LinkingVerbsScreen.new,
      lessonCount: 6,
    ),
    GrammarCategory(
      title: "Câu điều kiện",
      description: "Mệnh đề if và câu điều kiện loại 0, loại 1, loại 2, loại 3",
      color: Colors.purple,
      icon: Icons.alt_route,
      screen: ConditionalsScreen.new,
      lessonCount: 10,
    ),
    GrammarCategory(
      title: "Câu bị động",
      description: "Chuyển đổi chủ động sang bị động",
      color: Colors.red,
      icon: Icons.swap_horiz,
      screen: PassiveVoiceScreen.new,
      lessonCount: 7,
    ),
    GrammarCategory(
      title: "Modal verbs",
      description: "Can, could, should, must, might, would",
      color: Colors.teal,
      icon: Icons.psychology,
      screen: ModalVerbsScreen.new,
      lessonCount: 9,
    ),
    GrammarCategory(
      title: "Mạo từ",
      description: "A, an, the và cách sử dụng",
      color: Colors.indigo,
      icon: Icons.text_fields,
      screen: ArticlesScreen.new,
      lessonCount: 5,
    ),
    GrammarCategory(
      title: "Giới từ",
      description: "In, on, at, by, for, with and more",
      color: Colors.brown,
      icon: Icons.place,
      screen: PrepositionsScreen.new,
      lessonCount: 11,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.blue[600],
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Grammar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue[600]!,
                      Colors.blue[500]!,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    const Icon(
                      Icons.school,
                      size: 50,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 5),
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
                      'Hãy chọn 1 chủ đề bắt đầu ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue[100],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: grammarCategories.length,
                  itemBuilder: (context, index) {
                    final category = grammarCategories[index];
                    return GrammarCard(category: category);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}