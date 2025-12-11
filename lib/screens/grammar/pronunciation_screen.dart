import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learning_english/widgets/grammar/pronunciation_lesson.dart';
import 'package:learning_english/widgets/grammar/pronunciation_item.dart';

class PronunciationScreen extends StatefulWidget {
  const PronunciationScreen({super.key});

  @override
  State<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends State<PronunciationScreen> {
  int selectedLessonIndex = -1;
  FlutterTts flutterTts = FlutterTts();
  String? currentSpeakingWord;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    initTts();
  }

  void initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.6);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    flutterTts.setStartHandler(() {
      setState(() {
        isPlaying = true;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        isPlaying = false;
        currentSpeakingWord = null;
      });
    });
  }

  Future<void> speakWord(String word) async {
    if (isPlaying) {
      await flutterTts.stop();
      setState(() {
        isPlaying = false;
        currentSpeakingWord = null;
      });
    }

    setState(() {
      currentSpeakingWord = word;
    });

    // Xử lý các ví dụ chứa "→", lấy phần phát âm thực tế
    String cleanWord = word.contains(' → ') ? word.split(' → ')[1].trim() : word;
    await flutterTts.speak(cleanWord);
  }

  Future<void> speakIpa(String ipa) async {
    if (isPlaying) {
      await flutterTts.stop();
      setState(() {
        isPlaying = false;
        currentSpeakingWord = null;
      });
    }

    setState(() {
      currentSpeakingWord = ipa;
    });

    // Ánh xạ IPA sang âm gần đúng
    String speakableText = ipa;
    const ipaToText = {
      '/iː/': 'ee',
      '/ɪ/': 'ih',
      '/e/': 'eh',
      '/æ/': 'ae',
      '/ɑː/': 'ah',
      '/ɒ/': 'short o',
      '/ɔː/': 'aw',
      '/ʊ/': 'uh',
      '/uː/': 'oo',
      '/ʌ/': 'uh',
      '/ə/': 'schwa',
      '/ɜː/': 'er',
      '/eɪ/': 'ay',
      '/aɪ/': 'eye',
      '/ɔɪ/': 'oy',
      '/aʊ/': 'ow',
      '/əʊ/': 'oh',
      '/ɪə/': 'ear',
      '/eə/': 'air',
      '/ʊə/': 'oor',
      '/b/': 'b',
      '/d/': 'd',
      '/g/': 'g',
      '/v/': 'v',
      '/z/': 'z',
      '/ʒ/': 'zh',
      '/dʒ/': 'j',
      '/ð/': 'th voiced',
      '/p/': 'p',
      '/t/': 't',
      '/k/': 'k',
      '/f/': 'f',
      '/s/': 's',
      '/ʃ/': 'sh',
      '/tʃ/': 'ch',
      '/θ/': 'th voiceless',
      '/m/': 'm',
      '/n/': 'n',
      '/ŋ/': 'ng',
      '/l/': 'l',
      '/r/': 'r',
      '/w/': 'w',
      '/j/': 'y',
      '/h/': 'h',
    };

    speakableText = ipaToText[ipa] ?? ipa;
    await flutterTts.speak(speakableText);
  }

  Future<void> speakAllWords(List<String> words) async {
    if (isPlaying) {
      await flutterTts.stop();
      setState(() {
        isPlaying = false;
        currentSpeakingWord = null;
      });
      return;
    }

    setState(() {
      isPlaying = true;
    });

    for (int i = 0; i < words.length; i++) {
      if (!isPlaying) break;

      String word = words[i];
      setState(() {
        currentSpeakingWord = word;
      });

      String cleanWord = word.contains(' → ') ? word.split(' → ')[1].trim() : word;

      // Tạo Completer để đợi TTS hoàn thành
      final completer = Completer<void>();

      flutterTts.setCompletionHandler(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      await flutterTts.speak(cleanWord);
      await completer.future; // Đợi TTS hoàn thành

      // Delay giữa các từ
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      isPlaying = false;
      currentSpeakingWord = null;
    });

    // Reset completion handler
    flutterTts.setCompletionHandler(() {
      setState(() {
        isPlaying = false;
        currentSpeakingWord = null;
      });
    });
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  final List<PronunciationLesson> lessons = [
    PronunciationLesson(
      title: "Nguyên âm (đơn & đôi)",
      subtitle: "Single & Double Vowels",
      description: "Học cách phát âm các nguyên âm đơn và nguyên âm đôi trong tiếng Anh",
      icon: Icons.keyboard_voice,
      color: Colors.blue,
      duration: "15 phút",
      difficulty: "Cơ bản",
      content: PronunciationContent(
        sections: [
          PronunciationSection(
            title: "Nguyên âm đơn (Monophthongs)",
            items: [
              PronunciationItem(sound: "/iː/", examples: ["see", "tree", "bee"], vietnamese: "i dài"),
              PronunciationItem(sound: "/ɪ/", examples: ["sit", "hit", "bit"], vietnamese: "i ngắn"),
              PronunciationItem(sound: "/e/", examples: ["bed", "red", "head"], vietnamese: "e"),
              PronunciationItem(sound: "/æ/", examples: ["cat", "hat", "bat"], vietnamese: "a rộng"),
              PronunciationItem(sound: "/ɑː/", examples: ["car", "star", "far"], vietnamese: "a dài"),
              PronunciationItem(sound: "/ɒ/", examples: ["hot", "pot", "not"], vietnamese: "o ngắn"),
              PronunciationItem(sound: "/ɔː/", examples: ["saw", "law", "call"], vietnamese: "o dài"),
              PronunciationItem(sound: "/ʊ/", examples: ["put", "book", "good"], vietnamese: "u ngắn"),
              PronunciationItem(sound: "/uː/", examples: ["food", "moon", "cool"], vietnamese: "u dài"),
              PronunciationItem(sound: "/ʌ/", examples: ["cup", "run", "sun"], vietnamese: "ă"),
              PronunciationItem(sound: "/ə/", examples: ["about", "sofa", "banana"], vietnamese: "ơ"),
              PronunciationItem(sound: "/ɜː/", examples: ["bird", "word", "heard"], vietnamese: "ơ dài"),
            ],
          ),
          PronunciationSection(
            title: "Nguyên âm đôi (Diphthongs)",
            items: [
              PronunciationItem(sound: "/eɪ/", examples: ["day", "say", "play"], vietnamese: "ei"),
              PronunciationItem(sound: "/aɪ/", examples: ["my", "try", "fly"], vietnamese: "ai"),
              PronunciationItem(sound: "/ɔɪ/", examples: ["boy", "toy", "joy"], vietnamese: "oi"),
              PronunciationItem(sound: "/aʊ/", examples: ["now", "how", "cow"], vietnamese: "au"),
              PronunciationItem(sound: "/əʊ/", examples: ["go", "so", "know"], vietnamese: "ou"),
              PronunciationItem(sound: "/ɪə/", examples: ["here", "near", "clear"], vietnamese: "ia"),
              PronunciationItem(sound: "/eə/", examples: ["hair", "care", "share"], vietnamese: "ea"),
              PronunciationItem(sound: "/ʊə/", examples: ["tour", "sure", "poor"], vietnamese: "ua"),
            ],
          ),
        ],
      ),
    ),
    PronunciationLesson(
      title: "Phụ âm",
      subtitle: "Consonants",
      description: "Phân biệt và phát âm chính xác các phụ âm tiếng Anh",
      icon: Icons.speaker,
      color: Colors.green,
      duration: "18 phút",
      difficulty: "Cơ bản",
      content: PronunciationContent(
        sections: [
          PronunciationSection(
            title: "Phụ âm hữu thanh (Voiced)",
            items: [
              PronunciationItem(sound: "/b/", examples: ["bat", "cab", "rub"], vietnamese: "b"),
              PronunciationItem(sound: "/d/", examples: ["day", "red", "bed"], vietnamese: "d"),
              PronunciationItem(sound: "/g/", examples: ["go", "big", "dog"], vietnamese: "g"),
              PronunciationItem(sound: "/v/", examples: ["very", "love", "give"], vietnamese: "v"),
              PronunciationItem(sound: "/z/", examples: ["zoo", "buzz", "is"], vietnamese: "z"),
              PronunciationItem(sound: "/ʒ/", examples: ["vision", "measure", "Asia"], vietnamese: "gi/gi"),
              PronunciationItem(sound: "/dʒ/", examples: ["jump", "bridge", "age"], vietnamese: "j"),
              PronunciationItem(sound: "/ð/", examples: ["this", "mother", "breathe"], vietnamese: "th hữu thanh"),
            ],
          ),
          PronunciationSection(
            title: "Phụ âm vô thanh (Voiceless)",
            items: [
              PronunciationItem(sound: "/p/", examples: ["pat", "cap", "stop"], vietnamese: "p"),
              PronunciationItem(sound: "/t/", examples: ["top", "cat", "sit"], vietnamese: "t"),
              PronunciationItem(sound: "/k/", examples: ["cat", "back", "kick"], vietnamese: "k"),
              PronunciationItem(sound: "/f/", examples: ["fish", "laugh", "half"], vietnamese: "f"),
              PronunciationItem(sound: "/s/", examples: ["sun", "pass", "miss"], vietnamese: "s"),
              PronunciationItem(sound: "/ʃ/", examples: ["ship", "push", "cash"], vietnamese: "sh"),
              PronunciationItem(sound: "/tʃ/", examples: ["chair", "watch", "much"], vietnamese: "ch"),
              PronunciationItem(sound: "/θ/", examples: ["think", "math", "both"], vietnamese: "th vô thanh"),
            ],
          ),
          PronunciationSection(
            title: "Phụ âm đặc biệt",
            items: [
              PronunciationItem(sound: "/m/", examples: ["man", "come", "swim"], vietnamese: "m"),
              PronunciationItem(sound: "/n/", examples: ["no", "sun", "win"], vietnamese: "n"),
              PronunciationItem(sound: "/ŋ/", examples: ["sing", "ring", "long"], vietnamese: "ng"),
              PronunciationItem(sound: "/l/", examples: ["love", "all", "call"], vietnamese: "l"),
              PronunciationItem(sound: "/r/", examples: ["run", "car", "very"], vietnamese: "r"),
              PronunciationItem(sound: "/w/", examples: ["we", "water", "away"], vietnamese: "w"),
              PronunciationItem(sound: "/j/", examples: ["yes", "you", "yesterday"], vietnamese: "y"),
              PronunciationItem(sound: "/h/", examples: ["hat", "hello", "house"], vietnamese: "h"),
            ],
          ),
        ],
      ),
    ),
    PronunciationLesson(
      title: "Trọng âm (từ & câu)",
      subtitle: "Word & Sentence Stress",
      description: "Quy tắc đặt trọng âm trong từ và câu tiếng Anh",
      icon: Icons.graphic_eq,
      color: Colors.purple,
      duration: "20 phút",
      difficulty: "Trung bình",
      content: PronunciationContent(
        sections: [
          PronunciationSection(
            title: "Trọng âm từ (Word Stress)",
            items: [
              PronunciationItem(
                sound: "Từ 2 âm tiết",
                examples: ["'table", "'happy", "be'fore"],
                vietnamese: "Danh từ, tính từ: âm tiết đầu. Động từ: âm tiết cuối",
              ),
              PronunciationItem(
                sound: "Từ 3+ âm tiết",
                examples: ["'family", "im'portant", "infor'mation"],
                vietnamese: "Thường ở âm tiết thứ 3 từ cuối lên",
              ),
              PronunciationItem(
                sound: "Hậu tố ion",
                examples: ["infor'mation", "deci'sion", "educa'tion"],
                vietnamese: "Trọng âm trước hậu tố",
              ),
              PronunciationItem(
                sound: "Hậu tố ic, ical",
                examples: ["dra'matic", "eco'nomical", "'graphic"],
                vietnamese: "Trọng âm trước hậu tố",
              ),
            ],
          ),
          PronunciationSection(
            title: "Trọng âm câu (Sentence Stress)",
            items: [
              PronunciationItem(
                sound: "Từ quan trọng",
                examples: ["I 'LOVE 'chocolate", "'SHE is 'BEAUTIFUL"],
                vietnamese: "Nhấn mạnh danh từ, động từ, tính từ, trạng từ",
              ),
              PronunciationItem(
                sound: "Từ chức năng",
                examples: ["I can 'HELP you", "She 'IS a teacher"],
                vietnamese: "Không nhấn: a, an, the, to, of, and, but...",
              ),
              PronunciationItem(
                sound: "Tương phản",
                examples: ["'I like it, not 'YOU", "'THIS book, not 'THAT one"],
                vietnamese: "Nhấn mạnh để so sánh hoặc đối lập",
              ),
            ],
          ),
        ],
      ),
    ),
    PronunciationLesson(
      title: "Nối âm & ngữ điệu",
      subtitle: "Linking & Intonation",
      description: "Kỹ thuật nối âm và điều chỉnh ngữ điệu trong giao tiếp",
      icon: Icons.multiline_chart,
      color: Colors.red,
      duration: "22 phút",
      difficulty: "Nâng cao",
      content: PronunciationContent(
        sections: [
          PronunciationSection(
            title: "Nối âm (Linking)",
            items: [
              PronunciationItem(
                sound: "phụ + nguyên",
                examples: ["an apple → a-napple", "sit down → si-tdown"],
                vietnamese: "Nối phụ âm cuối với nguyên âm đầu",
              ),
              PronunciationItem(
                sound: "V + V",
                examples: ["go out → go-wout", "see it → see-yit"],
                vietnamese: "Thêm /w/ hoặc /y/ để nối(nguyên âm + nguyên âm)",
              ),
              PronunciationItem(
                sound: "Cùng phụ âm",
                examples: ["bad day → ba-day", "big girl → bi-girl"],
                vietnamese: "Chỉ phát âm một lần",
              ),
              PronunciationItem(
                sound: "Âm câm",
                examples: ["next to → nex-to", "want to → wan-to"],
                vietnamese: "Một số âm bị nuốt trong lời nói nhanh",
              ),
            ],
          ),
          PronunciationSection(
            title: "Ngữ điệu (Intonation)",
            items: [
              PronunciationItem(
                sound: "Phát biểu ",
                examples: ["I like coffee", "She is beautiful"],
                vietnamese: "Giọng xuống ở cuối câu khẳng định",
              ),
              PronunciationItem(
                sound: "Yes/No ",
                examples: ["Are you ready?", "Do you like it?"],
                vietnamese: "Giọng lên ở cuối câu hỏi Yes/No",
              ),
              PronunciationItem(
                sound: "Câu hỏi Wh- ",
                examples: ["What time is it?", "Where are you going?"],
                vietnamese: "Giọng xuống với câu hỏi thông tin",
              ),
              PronunciationItem(
                sound: "Liệt kê ",
                examples: ["I need pen, paper, and book"],
                vietnamese: "Giọng lên các item đầu, xuống item cuối",
              ),
            ],
          ),
        ],
      ),
    ),
    PronunciationLesson(
      title: "Quy tắc phát âm tận cùng",
      subtitle: "Ending Sounds (-s, -ed)",
      description: "Cách phát âm đuôi -s/-es và -ed trong tiếng Anh",
      icon: Icons.record_voice_over_outlined,
      color: Colors.teal,
      duration: "16 phút",
      difficulty: "Trung bình",
      content: PronunciationContent(
        sections: [
          PronunciationSection(
            title: "Đuôi -s/-es",
            items: [
              PronunciationItem(
                sound: "/s/",
                examples: ["cats", "books", "stops"],
                vietnamese: "Sau /p/, /t/, /k/, /f/, /θ/",
              ),
              PronunciationItem(
                sound: "/z/",
                examples: ["dogs", "beds", "runs"],
                vietnamese: "Sau nguyên âm và phụ âm hữu thanh",
              ),
              PronunciationItem(
                sound: "/ɪz/",
                examples: ["horses", "watches", "judges"],
                vietnamese: "Sau /s/, /z/, /ʃ/, /ʒ/, /tʃ/, /dʒ/",
              ),
              PronunciationItem(
                sound: "Bất quy tắc",
                examples: ["says ", "does"],
                vietnamese: "Một số từ có cách đọc đặc biệt",
              ),
            ],
          ),
          PronunciationSection(
            title: "Đuôi -ed",
            items: [
              PronunciationItem(
                sound: "/t/",
                examples: ["worked", "helped", "stopped"],
                vietnamese: "Sau /p/, /k/, /f/, /s/, /ʃ/, /tʃ/, /θ/",
              ),
              PronunciationItem(
                sound: "/d/",
                examples: ["played", "lived", "studied"],
                vietnamese: "Sau nguyên âm và phụ âm hữu thanh",
              ),
              PronunciationItem(
                sound: "/ɪd/",
                examples: ["wanted", "needed", "decided"],
                vietnamese: "Sau /t/ và /d/ tạo thêm âm tiết",
              ),
              PronunciationItem(
                sound: "Bất quy tắc",
                examples: ["learned ", "blessed "],
                vietnamese: "Một số từ có cách đọc đặc biệt",
              ),
            ],
          ),
        ],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Phát âm - Pronunciation',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.orange,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Info
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.orange.shade300],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.record_voice_over,
                    size: 50,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Học phát âm tiếng Anh chuẩn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nguyên âm, phụ âm và ngữ điệu',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Lessons List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: lessons.length,
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                final isExpanded = selectedLessonIndex == index;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            selectedLessonIndex = isExpanded ? -1 : index;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: lesson.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  lesson.icon,
                                  color: lesson.color,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Lesson ${index + 1}',
                                            style: TextStyle(
                                              color: lesson.color,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: lesson.color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            lesson.difficulty,
                                            style: TextStyle(
                                              color: lesson.color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lesson.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lesson.subtitle,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      lesson.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          lesson.duration,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: lesson.color,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Expanded Content
                      if (isExpanded)
                        Container(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const SizedBox(height: 16),

                              ...lesson.content.sections.map((section) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      section.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: lesson.color,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    ...section.items.map((item) {
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: lesson.color.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: lesson.color.withOpacity(0.2),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Header với IPA symbol và nút phát âm
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: lesson.color,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  constraints: const BoxConstraints(
                                                    maxWidth: 150, // Giới hạn chiều rộng
                                                  ),
                                                  child: Text(
                                                    item.sound,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                    overflow: TextOverflow.ellipsis, // Thêm ellipsis nếu quá dài
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Nút phát âm IPA
                                                InkWell(
                                                  onTap: () => speakIpa(item.sound),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: lesson.color.withOpacity(0.1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.volume_up,
                                                      color: lesson.color,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                const Spacer(),
                                                // Nút phát tất cả từ
                                                InkWell(
                                                  onTap: () => speakAllWords(item.examples),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: isPlaying ? Colors.red.shade100 : Colors.green.shade100,
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isPlaying ? Icons.stop : Icons.play_arrow,
                                                          color: isPlaying ? Colors.red.shade700 : Colors.green.shade700,
                                                          size: 14,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          isPlaying ? 'Dừng' : 'Phát tất cả',
                                                          style: TextStyle(
                                                            color: isPlaying ? Colors.red.shade700 : Colors.green.shade700,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),

                                            // Label ví dụ
                                            const Text(
                                              'Ví dụ:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // Danh sách từ có thể click để phát âm
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: item.examples.map((word) {
                                                bool isCurrentWord = currentSpeakingWord == word;

                                                return InkWell(
                                                  onTap: () => speakWord(word),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: isCurrentWord
                                                          ? Colors.orange.shade200
                                                          : Colors.white,
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(
                                                        color: isCurrentWord
                                                            ? Colors.orange.shade400
                                                            : lesson.color.withOpacity(0.3),
                                                      ),
                                                      boxShadow: isCurrentWord ? [
                                                        BoxShadow(
                                                          color: Colors.orange.withOpacity(0.3),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ] : [],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          word,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 14,
                                                            color: isCurrentWord
                                                                ? Colors.orange.shade800
                                                                : lesson.color,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Icon(
                                                          isCurrentWord ? Icons.volume_up : Icons.volume_up_outlined,
                                                          size: 14,
                                                          color: isCurrentWord
                                                              ? Colors.orange.shade700
                                                              : lesson.color.withOpacity(0.7),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),

                                            const SizedBox(height: 12),

                                            // Mô tả tiếng Việt
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.info_outline,
                                                    size: 16,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      item.vietnamese,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[700],
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Thanh tiến trình khi đang phát
                                            if (isPlaying && (item.examples.contains(currentSpeakingWord) || currentSpeakingWord == item.sound)) ...[
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.graphic_eq,
                                                    size: 16,
                                                    color: Colors.orange.shade600,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: LinearProgressIndicator(
                                                      backgroundColor: Colors.grey.shade300,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),

                                    const SizedBox(height: 16),
                                  ],
                                );
                              }).toList(),

                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}