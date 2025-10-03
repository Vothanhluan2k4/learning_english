import 'package:flutter/material.dart';
import 'package:learning_english/widgets/tense_category.dart';
import 'package:learning_english/widgets/tense.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../widgets/youtube_player_screen.dart';

class TensesScreen extends StatefulWidget {
  const TensesScreen({super.key});

  @override
  State<TensesScreen> createState() => _TensesScreenState();
}

class _TensesScreenState extends State<TensesScreen> {
  int selectedTenseIndex = 0;

  final List<TenseCategory> tenseCategories = [
    TenseCategory(
      title: "Hiện tại",
      color: Colors.blue,
      icon: Icons.access_time,
      tenses: [
        Tense(
          name: "Hiện tại đơn",
          structure: "S + V(s/es)",
          usage: "Dùng để diễn tả hành động lặp đi lặp lại, thói quen, sự thật hiển nhiên, hoặc đặc điểm trong hiện tại.",
          examples: [
            "- I work every day.",
            "- She speaks English fluently.",
            "- The sun rises in the east."
          ],
          positiveForm: "S + V(s/es)",
          negativeForm: "S + do/does + not + V",
          questionForm: "Do/Does + S + V?",
          videoUrl: "https://www.youtube.com/watch?v=2rohVIy3v1U&t=13s",
        ),
        Tense(
          name: "Hiện tại tiếp diễn",
          structure: "S + am/is/are + V-ing",
          usage: "Để diễn tả hành động xảy trong thời điểm hiện tại",
          examples: [
            "- I am studying English now.",
            "- They are playing football.",
            "- She is working on a project."
          ],
          positiveForm: "I am + V-ing\nYou/We/They are + V-ing\nHe/She/It is + V-ing",
          negativeForm: "I am not + V-ing\nYou/We/They are not + V-ing\nHe/She/It is not + V-ing",
          questionForm: "Am I + V-ing?\nAre you/we/they + V-ing?\nIs he/she/it + V-ing?",
          videoUrl:"https://www.youtube.com/watch?v=_8DXjppSoyk&t=1s",
        ),
        Tense(
          name: "Hiện tại hoàn thành",
          structure: "S + have/has + V3/ed",
          usage: "Diễn tả những hành động kết thúc trong quá khứ",
          examples: [
            "- I have visited London twice.",
            "- She has finished her homework.",
            "- They have lived here for 5 years."
          ],
          positiveForm: "I/You/We/They + have + V3/ed\nHe/She/It + has + V3/ed",
          negativeForm: "I/You/We/They + haven't + V3/ed\nHe/She/It + hasn't + V3/ed",
          questionForm: "Have + I/you/we/they + V3/ed?\nHas + he/she/it + V3/ed?",
          videoUrl: "https://www.youtube.com/watch?v=PbGnR-5gYpk",
        ),
        Tense(
          name: "Hiện thành hoàn thành tiếp diễn",
          structure: "S + have/has + been + V-ing",
          usage: "Hành động diễn ra trong quá khứ và tiếp diễn đến hiện tại",
          examples: [
            "- I have been studying for 3 hours.",
            "- She has been working here since 2020.",
            "- They have been waiting for the bus."
          ],
          positiveForm: "I/You/We/They + have been + V-ing\nHe/She/It + has been + V-ing",
          negativeForm: "I/You/We/They + haven't been + V-ing\nHe/She/It + hasn't been + V-ing",
          questionForm: "Have + I/you/we/they + been + V-ing?\nHas + he/she/it + been + V-ing?",
          videoUrl: "https://www.youtube.com/watch?v=h-cprKWQmY0",
        ),
      ],
    ),
    TenseCategory(
      title: "Quá khứ",
      color: Colors.orange,
      icon: Icons.history,
      tenses: [
        Tense(
          name: "Quá khứ đơn",
          structure: "S + V2/ed",
          usage: "Sự việc đã xảy ra ở quá khứ,ở thời điểm xác định",
          examples: [
            "- I visited Paris last year.",
            "- She studied English yesterday.",
            "- They went to the cinema."
          ],
          positiveForm: "S + S2/ed",
          negativeForm: "S + didn't + V-inf",
          questionForm: "Did + S + V-inf?",
          videoUrl: "https://www.youtube.com/watch?v=lmCBxXztfEY",
        ),
        Tense(
          name: "Quá khứ tiếp diễn",
          structure: "S + was/were + V-ing",
          usage: "Diễn tả hành động đang xảy ra trong quá khứ",
          examples: [
            "- I was reading when you called.",
            "- They were playing football at 5 PM.",
            "- She was cooking dinner."
          ],
          positiveForm: "I/He/She/It + was + V-ing\nYou/We/They + were + V-ing",
          negativeForm: "I/He/She/It + wasn't + V-ing\nYou/We/They + weren't + V-ing",
          questionForm: "Was + I/he/she/it + V-ing?\nWere + you/we/they + V-ing?",
          videoUrl: "https://www.youtube.com/watch?v=ygcboZ7Jpvs",
        ),
        Tense(
          name: "Quá khứ hoàn thành",
          structure: "S + had + V3/ed",
          usage: "Diễn tả hành động, sự việc xảy ra trước mốc thời gian cụ thể trong quá khứ",
          examples: [
            "- I had finished my work before he arrived.",
            "- She had already left when I got there.",
            "- They had seen the movie before."
          ],
          positiveForm: "S + had + V3/ed",
          negativeForm: "S + had not(hadn't) + V3/ed",
          questionForm: "Had + S + V3/ed?",
          videoUrl: "https://www.youtube.com/watch?v=_DCeOxI6G44",
        ),
        Tense(
          name: "Quá khứ hoàn thành tiếp diễn",
          structure: "S + had + been + V-ing",
          usage: "Những hành động đang diễn ra trước một hành động quá khứ khác",
          examples: [
            "- I had been waiting for an hour when she arrived.",
            "- They had been living there for 10 years.",
            "- She had been studying before the exam."
          ],
          positiveForm: "S + had + been + V-ing",
          negativeForm: "S + had not(hadn't) + been + V-ing",
          questionForm: "Had + S + been + V-ing?",
          videoUrl: "https://www.youtube.com/watch?v=nOid1SbUo1k",
        ),
      ],
    ),
    TenseCategory(
      title: "Tương lai",
      color: Colors.green,
      icon: Icons.trending_up,
      tenses: [
        Tense(
          name: "Tương lai đơn",
          structure: "S/shall + will + V-inf",
          usage: "Dự đoán, quyết định ",
          examples: [
            "- We shall go out tomorrow.",
            "- She will call you later.",
            "- It will rain tomorrow."
          ],
          positiveForm: "S + will/shall + V-inf",
          negativeForm: "S + will/shall not + V-inf",
          questionForm: "Will/shall + S + V-inf?",
          videoUrl: "https://www.youtube.com/watch?v=ziHWgJrmIS0",
        ),
        Tense(
          name: "Tương lai tiếp diễn",
          structure: "S + will/shall + be + V-ing",
          usage: "Hành động xảy ra tại một thời điểm hoặc thời gian cụ thể trong tương lai",
          examples: [
            "- I will be working at 9 AM tomorrow.",
            "- She will be traveling next week.",
            "- They will be sleeping at midnight."
          ],
          positiveForm: "S + will/shall be + V-ing",
          negativeForm: "S + will/shall not + be + V-ing",
          questionForm: "Will/shall + S + be + V-ing?",
          videoUrl: "https://www.youtube.com/watch?v=7d0MpOr9x0o",
        ),
        Tense(
          name: "Tương lai hoàn thành ",
          structure: "S + will + have + V3/ed",
          usage: "Hành động xảy ra và hoàn thành trước một thời điểm hoặc một hành động khác trong tương lai",
          examples: [
            "- I will have finished by 6 PM.",
            "- She will have graduated by next year.",
            "- They will have arrived before the meeting."
          ],
          positiveForm: "S + will have + V3/ed",
          negativeForm: "S + won't have + V3/ed",
          questionForm: "Will + S + have + V3/ed?",
          videoUrl: "https://www.youtube.com/watch?v=OmjAJXeKeIg",
        ),
        Tense(
          name: "Tương lai hoàn thành tiếp diễn",
          structure: "S + will + have been + V-ing",
          usage: "Diễn tả các hành động kéo dài liên tục đến thời điểm ở tương lai",
          examples: [
            "- By 9 PM tonight, I will have been working for 5 hours.",
            "- They won’t have been waiting for more than an hour by the time we arrive.",
            "- Why will they have been waiting so long?"
          ],
          positiveForm: "S + will + have been + V-ing",
          negativeForm: "S + will + not + have been + V-ing",
          questionForm: "Will + S + have been + V-ing ?",
          videoUrl: "https://www.youtube.com/watch?v=VopXfpb3IAk"
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Các thì trong tiếng anh', style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back , color: Colors.white,),
          onPressed: (){
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Category Tabs
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              itemCount: tenseCategories.length,
              itemBuilder: (context, index) {
                final category = tenseCategories[index];
                final isSelected = selectedTenseIndex == index;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedTenseIndex = index;
                    });
                  },
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? category.color : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: category.color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ] : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category.icon,
                          color: isSelected ? Colors.white : Colors.grey[600],
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category.title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Tense List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tenseCategories[selectedTenseIndex].tenses.length,
              itemBuilder: (context, index) {
                final tense = tenseCategories[selectedTenseIndex].tenses[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      tense.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: tenseCategories[selectedTenseIndex].color,
                      ),
                    ),
                    subtitle: Text(
                      tense.structure,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSection("Sử dụng", tense.usage),
                            const SizedBox(height: 16),
                            _buildSection("Ví dụ", tense.examples.join('\n')),
                            const SizedBox(height: 16),
                            _buildFormSection("Khẳng định", tense.positiveForm),
                            const SizedBox(height: 12),
                            _buildFormSection("Phủ định", tense.negativeForm),
                            const SizedBox(height: 12),
                            _buildFormSection("Câu hỏi", tense.questionForm),
                            if (tense.videoUrl != null && tense.videoUrl!.isNotEmpty)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.play_circle_fill),
                                label: const Text("Xem video"),
                                onPressed: () {
                                  String? videoId = YoutubePlayer.convertUrlToId(tense.videoUrl!);
                                  if (videoId != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => YoutubePlayerScreen(
                                          videoId: videoId,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),

                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}