import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/question_group.dart';
import '../../models/test_question.dart';
import '../../widgets/audio_player.dart';

class PlacementTestScreen extends StatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  State<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends State<PlacementTestScreen> {
  final supabase = Supabase.instance.client;

  String? _testId;
  String? _resultId;
  String? _userId;
  bool _isLoading = true;
  int _currentQuestionIndex = 0;

  List<dynamic> _items = []; // Có thể là TestQuestion hoặc QuestionGroup
  Map<String, String> _userAnswers = {}; // key = questionId

  bool _isPanelOpen = false;

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

  Future<void> _fetchQuestions(String testId) async {
    try {
      setState(() => _isLoading = true);

      final allItems = <dynamic>[];

      // 1. Lấy câu hỏi đơn (không thuộc group)
      final directRes = await supabase
          .from('test_questions')
          .select()
          .eq('test_id', testId)
          .isFilter('group_id', null)
          .order('order_in_test', ascending: true);

      final directQuestions =
      (directRes as List).map((q) => TestQuestion.fromJson(q)).toList();
      allItems.addAll(directQuestions);

      // 2. Lấy question groups (reading/listening passage)
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
        allItems.add(group);
      }

      // Sort by order_in_test
      allItems.sort((a, b) {
        final orderA = a is TestQuestion ? a.orderInTest : (a as QuestionGroup).orderInTest;
        final orderB = b is TestQuestion ? b.orderInTest : (b as QuestionGroup).orderInTest;
        return (orderA ?? 0).compareTo(orderB ?? 0);
      });


      // ✅ FIX: Thêm await để đảm bảo _resultId được gán trước khi user trả lời
      await _createUserTestResult();

      setState(() {
        _items = allItems;
        _userId = supabase.auth.currentUser?.id;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error: $e');
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
      // Check tất cả câu hỏi trong group đã trả lời chưa
      return currentItem.testQuestions.every(
              (q) => _userAnswers[q.id]?.trim().isNotEmpty ?? false
      );
    }

    return false;
  }

  //User test
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
      // ✅ LẤY users.id DỰA TRÊN auth_id
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

      // Kiểm tra kết quả test đã tồn tại chưa
      final existing = await supabase
          .from('user_test_results')
          .select('id, status')
          .eq('user_id', _userId as String)
          .eq('test_id', _testId as String)
          .maybeSingle();

      if (existing != null) {
        _resultId = existing['id'];

        if (existing['status'] == 'completed') {
          debugPrint('✅ Đã có kết quả completed: $_resultId');
        } else {
          debugPrint('🔄 Tiếp tục bài làm dở: $_resultId');
        }
      } else {
        final newResult = await supabase.from('user_test_results').insert({
          'user_id': _userId,
          'test_id': _testId,
          'status': 'in_progress',
          'started_at': DateTime.now().toIso8601String(),
        }).select('id').single();

        _resultId = newResult['id'];
        debugPrint('🆕 Tạo mới user_test_results: $_resultId');
      }
    } catch (e) {
      debugPrint('❌ Lỗi tạo user_test_results: $e');
    }
  }


  Future<void> _submitTest() async {
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

    // 🔹 Cập nhật user_test_results
    if (_resultId != null) {
      await supabase.from('user_test_results').update({
        'score': score,
        'total_questions': total,
        'correct_answers': correct,
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', _resultId as String);
    }

    // 🔹 Nếu là bài placement test → cập nhật user_placement_summary
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

    // 🔹 Hiển thị kết quả
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 40),
            SizedBox(width: 12),
            Text('Kết quả'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Điểm: ${score.toStringAsFixed(1)}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Số câu đúng: $correct/$total'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bài kiểm tra đầu vào')),
        body: const Center(child: Text('Không tìm thấy câu hỏi nào.')),
      );
    }

    final currentItem = _items[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài kiểm tra đầu vào'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isPanelOpen ? Icons.close : Icons.menu),
            onPressed: () => setState(() => _isPanelOpen = !_isPanelOpen),
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Progress bar
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

              // Navigation buttons
              _buildNavigationButtons(),
            ],
          ),

          // Sidebar Panel
          _buildSidebarPanel(),
        ],
      ),
    );
  }

  Widget _buildSingleQuestion(TestQuestion question) {
    // Parse options - FIX: Xử lý cả Map và List
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
          // ✅ Sửa lại để lấy đúng label & text
          options = list
              .map((e) => MapEntry(
            e['label']?.toString() ?? '',
            e['text']?.toString() ?? '',
          ))
              .toList();
        } else {
          options = list.asMap().entries
              .map((e) => MapEntry(
            String.fromCharCode(65 + e.key), // A, B, C...
            e.value.toString(),
          ))
              .toList();
        }
      }
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Câu ${_currentQuestionIndex + 1}/${_items.length}',
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

        // Question text
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

        // Options
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
                  await supabase.from('user_test_answers').upsert({
                    'result_id': _resultId,
                    'question_id': question.id,
                    'user_answer': value,
                    'is_correct': value == question.correctAnswer,
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

  Widget _buildGroupQuestions(QuestionGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // === HEADER ===
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
              Row(
                children: [
                  Icon(
                    group.mediaType == 'audio' ? Icons.headphones : Icons.article,
                    color: Colors.purple,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.title ?? 'Passage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              if (group.instruction != null) ...[
                SizedBox(height: 8),
                Text(
                  group.instruction!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 16),

        // === MEDIA ===
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

        // === CÂU HỎI TRONG GROUP ===
        ...group.testQuestions.asMap().entries.map((entry) {
          final qIndex = entry.key;
          final question = entry.value;

          // Xử lý options (có thể là Map, List hoặc List<Object>)
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
                  String.fromCharCode(65 + e.key), // A, B, C...
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
                  '${qIndex + 1}. ${question.questionText ?? ''}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),

                // Câu điền khuyết
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
                          await supabase.from('user_test_answers').upsert({
                            'result_id': _resultId,
                            'question_id': question.id,
                            'user_answer': value,
                            'is_correct': value == question.correctAnswer,
                            'answered_at': DateTime.now().toIso8601String(),
                          }, onConflict: 'result_id,question_id');

                          debugPrint('✅ Đã lưu câu điền khuyết: ${question.id}');
                        } catch (e) {
                          debugPrint('❌ Lỗi lưu user_test_answers (fill_blank): $e');
                        }
                      }
                    },
                  ),


                // Câu chọn đáp án
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
    // Count total questions
    int totalQuestions = 0;
    for (final item in _items) {
      if (item is TestQuestion) {
        totalQuestions++;
      } else if (item is QuestionGroup) {
        totalQuestions += item.testQuestions.length;
      }
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      right: _isPanelOpen ? 0 : -250,
      top: 0,
      bottom: 0,
      child: Container(
        width: 250,
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
              child: ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final isCurrent = index == _currentQuestionIndex;

                  if (item is TestQuestion) {
                    final answered = _userAnswers[item.id]?.trim().isNotEmpty ?? false;
                    return _buildSidebarItem(
                      index: index,
                      label: '${index + 1}',
                      isCurrent: isCurrent,
                      isAnswered: answered,
                    );
                  } else if (item is QuestionGroup) {
                    final allAnswered = item.testQuestions.every(
                            (q) => _userAnswers[q.id]?.trim().isNotEmpty ?? false
                    );
                    return _buildSidebarItem(
                      index: index,
                      label: '${index + 1}\n(${item.testQuestions.length})',
                      isCurrent: isCurrent,
                      isAnswered: allAnswered,
                      isGroup: true,
                    );
                  }
                  return SizedBox();
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildLegend(Colors.orange, 'Hiện tại'),
                  SizedBox(height: 8),
                  _buildLegend(Colors.blueAccent, 'Đã trả lời'),
                  SizedBox(height: 8),
                  _buildLegend(Colors.grey.shade200, 'Chưa trả lời'),
                  SizedBox(height: 8),
                  _buildLegend(Colors.purple, 'Nhóm câu hỏi'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required String label,
    required bool isCurrent,
    required bool isAnswered,
    bool isGroup = false,
  }) {
    return GestureDetector(
      onTap: () => _jumpToQuestion(index),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrent
              ? Colors.orange
              : (isAnswered
              ? (isGroup ? Colors.purple : Colors.blueAccent)
              : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent ? Colors.orange.shade700 : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
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

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}