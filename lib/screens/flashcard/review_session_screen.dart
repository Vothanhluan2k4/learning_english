import 'package:flutter/material.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/models/word.dart';
import 'package:learning_english/screens/flashcard/ReviewLearningScreen.dart';
import 'package:learning_english/service/flashcard_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learning_english/screens/flashcard/random_review_screen.dart';

class ReviewSessionScreen extends StatefulWidget {
  final ListWord list;
  const ReviewSessionScreen({super.key, required this.list});

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen> {
  late Future<List<Word>> _wordsFuture;
  late ListWord _currentList;
  FilePickerResult? _imageFileResult;
  final FlutterTts flutterTts = FlutterTts();
  Map<String, int> _progressData = {'total': 0, 'studied': 0, 'remembered': 0, 'to_review': 0};
  bool _isProgressLoading = true;

  @override
  void initState() {
    super.initState();
    _currentList = widget.list;
    _initializeTts();
    _refreshAllData();
    if (_currentList.id != null) {
      FlashcardService().hasReviewHistory(_currentList.id!).then((hasHistory) {
        if (hasHistory && mounted) {
          _showReviewOptionDialog();
        }
      });
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  void _initializeTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
  }

  void _showReviewOptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tiếp tục ôn tập'),
        content: const Text('Bạn đã ôn tập danh sách này trước đây. Bạn muốn ôn tiếp hay ôn lại từ đầu?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => ReviewLearningScreen(list: _currentList)));
            },
            child: const Text('Ôn tiếp'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => ReviewLearningScreen(list: _currentList, resetProgress: true)));
            },
            child: const Text('Ôn lại'),
          ),
        ],
      ),
    );
  }

  void _refreshAllData() {
    if (_currentList.id == null) return;

    setState(() {
      _isProgressLoading = true;
    });

    FlashcardService().getProgress(_currentList.id!).then((progress) {
      if (mounted) {
        setState(() {
          _progressData = progress;
          _isProgressLoading = false;
        });
      }
    }).catchError((e) {
      if (mounted) {
        print('Lỗi khi tải tiến độ: $e');
        setState(() => _isProgressLoading = false);
      }
    });

    setState(() {
      _wordsFuture = FlashcardService().getWords(_currentList.id!);
    });
  }

  Future<void> _playAudio(String word) async {
    if (word.isNotEmpty) {
      await flutterTts.speak(word);
    }
  }

  void _handleAddCard(BuildContext context) {
    if (_currentList.id == null) return;
    showDialog(
      context: context,
      builder: (context) => _buildAddCardDialog(context, _currentList),
    ).then((result) {
      if (result == true && mounted) _refreshAllData();
    });
  }

  void _handleDeleteCard(BuildContext context, String? wordId) {
    if (wordId == null) return;
    FlashcardService().deleteWord(wordId).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xóa thẻ thành công!')));
        _refreshAllData();
      }
    }).catchError((e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi xóa: $e')));
    });
  }

  Future<void> _handleStopLearning() async {
    final listId = _currentList.id;
    if (listId == null) return;
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dừng học list này?'),
          content: const Text('Thao tác này sẽ xóa vĩnh viễn list từ này và tất cả các thẻ liên quan. Bạn có chắc chắn?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
          ],
        ));
    if (result == true) {
      try {
        await FlashcardService().deleteListWord(listId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa list thành công.')));
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi xóa list: $e')));
      }
    }
  }

  Future<void> _editDeck(BuildContext context) async {
    final titleController = TextEditingController(text: _currentList.title);
    final descriptionController = TextEditingController(text: _currentList.description ?? '');
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chỉnh sửa bộ thẻ'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Tiêu đề')),
            TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Mô tả')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            TextButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    try {
                      await FlashcardService().updateListWord(ListWord(
                        id: _currentList.id,
                        userId: _currentList.userId,
                        title: titleController.text,
                        description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                      ));
                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {
                          _currentList = ListWord(
                            id: _currentList.id,
                            userId: _currentList.userId,
                            title: titleController.text,
                            description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                            wordCount: _currentList.wordCount,
                          );
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!')));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                    }
                  }
                },
                child: const Text('Lưu')),
          ],
        ));
  }

  Future<void> _createBulkWords(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => _buildBulkAddDialog(context, _currentList.id!),
    ).then((result) {
      if (result == true && mounted) _refreshAllData();
    });
  }

  void _handleEditWord(BuildContext context, Word word) {
    showDialog(
      context: context,
      builder: (context) => _buildEditWordDialog(context, word),
    ).then((result) {
      if (result == true && mounted) _refreshAllData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: FutureBuilder<List<Word>>(
        future: _wordsFuture,
        builder: (context, snapshot) {
          return _buildBody(context, snapshot.connectionState, snapshot.data ?? []);
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text('Flashcards: ${_currentList.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: false,
      actions: [
        TextButton(onPressed: () => _editDeck(context), child: const Text('Chỉnh sửa', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
        TextButton(onPressed: () => _handleAddCard(context), child: const Text('Thêm từ mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: TextButton.styleFrom(backgroundColor: Colors.blue)),
        TextButton(onPressed: () => _createBulkWords(context), child: const Text('Tạo hàng loạt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: TextButton.styleFrom(backgroundColor: Colors.blue)),
        const SizedBox(width: 8.0),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ConnectionState state, List<Word> words) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Learning', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 16.0),
              _buildInfoBanner(),
              const SizedBox(height: 16.0),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => ReviewLearningScreen(list: _currentList)));
                    _refreshAllData();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16.0)),
                  child: const Text('Luyện tập flashcards', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16.0),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => RandomReviewScreen(list: _currentList)));
                    },
                    icon: const Icon(Icons.shuffle, size: 18, color: Colors.blue),
                    label: const Text('Xem ngẫu nhiên', style: TextStyle(color: Colors.blue))),
                TextButton.icon(onPressed: _handleStopLearning, icon: const Icon(Icons.calendar_today, size: 18, color: Colors.red), label: const Text('Dừng học list từ này', style: TextStyle(color: Colors.red))),
              ]),
              const SizedBox(height: 24.0),
              _buildProgressSection(),
              const SizedBox(height: 24.0),
              Text('List có ${words.length} từ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16.0),
              if (state == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (words.isEmpty)
                const Center(child: Text('Chưa có thẻ nào'))
              else
                _buildWordList(words),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    if (_isProgressLoading) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }
    return Card(
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _buildStatItem(_progressData['total'].toString(), 'Tổng số từ'),
                _buildStatItem(_progressData['studied'].toString(), 'Đã học'),
                _buildStatItem(_progressData['remembered'].toString(), 'Đã nhớ'),
                _buildStatItem(
                  _progressData['to_review'].toString(),
                  'Cần ôn tập',
                  textColor: (_progressData['to_review'] ?? 0) > 0 ? Colors.red : Colors.black,
                ),
              ]),
              const SizedBox(height: 16),
              if ((_progressData['total'] ?? 0) > 0)
                LinearProgressIndicator(
                  value: (_progressData['remembered'] ?? 0) / _progressData['total']!,
                  backgroundColor: Colors.grey.shade300,
                  color: Colors.green,
                )
              else
                Container(height: 4, color: Colors.grey.shade300),
            ])));
  }

  Widget _buildStatItem(String value, String label, {Color textColor = Colors.black}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]);
  }

  Widget _buildInfoBanner() {
    return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8.0)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, color: Colors.green),
          const SizedBox(width: 8.0),
          Expanded(child: Text('Chú ý: nếu như list từ vựng của bạn là tiếng Trung, Nhật, hay Hàn, click vào nút chỉnh sửa để thay đổi ngôn ngữ. Audio mặc định là tiếng Anh-Anh và Anh-Mỹ. Các ngôn ngữ khác chỉ hỗ trợ trên máy tính.', style: TextStyle(color: Colors.green.shade800))),
        ]));
  }

  Widget _buildWordList(List<Word> words) {
    return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: words.length,
        itemBuilder: (context, index) {
          final word = words[index];
          return _buildWordItem(context, word);
        });
  }

  Widget _buildWordItem(BuildContext context, Word word) {
    return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16.0),
        shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300, width: 1.0), borderRadius: BorderRadius.circular(8.0)),
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Text(word.word, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8.0),
                  IconButton(icon: const Icon(Icons.volume_up, color: Colors.blue, size: 20), onPressed: () => _playAudio(word.word), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  const SizedBox(width: 8.0),
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _handleEditWord(context, word), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ]),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _handleDeleteCard(context, word.id)),
              ]),
              const SizedBox(height: 8.0),
              const Text('Định nghĩa:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(word.define),
            ])));
  }

  Widget _buildAddCardDialog(BuildContext context, ListWord list) {
    final wordController = TextEditingController();
    final defineController = TextEditingController();
    final wordTypeController = TextEditingController();
    final transcriptionController = TextEditingController();
    final exampleController = TextEditingController();
    final pictureUrlController = TextEditingController();
    final noteController = TextEditingController();
    bool _isExpanded = false;

    Future<void> _chooseFileAction(StateSetter setState) async {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null) {
        setState(() {
          _imageFileResult = result;
          pictureUrlController.text = result.files.single.name;
        });
      }
    }

    Future<void> saveWord() async {
      if (wordController.text.isEmpty || defineController.text.isEmpty) return;
      final newWord = Word(
        listWordId: list.id!,
        word: wordController.text.trim(),
        define: defineController.text.trim(),
        wordType: wordTypeController.text.isNotEmpty ? wordTypeController.text : null,
        transcription: transcriptionController.text.isNotEmpty ? transcriptionController.text : null,
        example: exampleController.text.isNotEmpty ? exampleController.text : null,
        pictureUrl: pictureUrlController.text.isNotEmpty ? pictureUrlController.text : null,
        note: noteController.text.isNotEmpty ? noteController.text : null,
      );
      try {
        await FlashcardService().createWord(newWord);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm thẻ thành công!')));
          _imageFileResult = null;
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context, false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi thêm: $e')));
        }
      }
    }

    return AlertDialog(
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Padding(padding: EdgeInsets.only(left: 24, top: 24), child: Text('Tạo flashcard', style: TextStyle(fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
        ]),
        content: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          final fileName = _imageFileResult?.files.single.name ?? 'No file chosen';
          return SingleChildScrollView(
              child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('List từ: ${list.title}', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    const Text('Từ mới'),
                    TextField(controller: wordController),
                    const SizedBox(height: 16),
                    const Text('Định nghĩa'),
                    TextField(controller: defineController, maxLines: 3),
                    const SizedBox(height: 16),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Thêm phiên âm, ví dụ, ảnh, ghi chú ...', style: TextStyle(color: Colors.blue, fontSize: 14)),
                      trailing: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.blue),
                      onExpansionChanged: (bool expanded) => setState(() => _isExpanded = expanded),
                      children: [
                        const SizedBox(height: 16),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Loại từ (N, V, ADJ...)'),
                                TextField(controller: wordTypeController),
                              ])),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Phiên âm'),
                                TextField(controller: transcriptionController),
                              ])),
                        ]),
                        const SizedBox(height: 16),
                        const Text('Ảnh'),
                        Row(children: [
                          SizedBox(
                              height: 34,
                              child: ElevatedButton(
                                onPressed: () => _chooseFileAction(setState),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade300,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0), side: BorderSide(color: Colors.grey.shade500)),
                                ),
                                child: const Text('Choose File', style: TextStyle(fontSize: 14)),
                              )),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileName,
                              style: const TextStyle(color: Colors.black54),
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        const Text('Hoặc Link Ảnh/URL'),
                        TextField(controller: pictureUrlController, decoration: const InputDecoration(hintText: 'Nhập URL ảnh trực tiếp')),
                        const SizedBox(height: 16),
                        const Text('Ví dụ (tối đa 10 câu)'),
                        TextField(controller: exampleController, maxLines: 3),
                        const SizedBox(height: 16),
                        const Text('Ghi chú'),
                        TextField(controller: noteController, maxLines: 3),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: saveWord, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text('Lưu'))),
                  ])));
        }));
  }

  Widget _buildEditWordDialog(BuildContext context, Word word) {
    final wordController = TextEditingController(text: word.word);
    final defineController = TextEditingController(text: word.define);
    final wordTypeController = TextEditingController(text: word.wordType);
    final transcriptionController = TextEditingController(text: word.transcription);
    final exampleController = TextEditingController(text: word.example);
    final pictureUrlController = TextEditingController(text: word.pictureUrl);
    final noteController = TextEditingController(text: word.note);
    bool _isExpanded = true;

    Future<void> _chooseFileAction(StateSetter setState) async {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null) {
        setState(() {
          _imageFileResult = result;
          pictureUrlController.text = result.files.single.name;
        });
      }
    }

    Future<void> updateWord() async {
      if (wordController.text.isEmpty || defineController.text.isEmpty) return;

      final updatedWord = Word(
        id: word.id,
        listWordId: word.listWordId,
        word: wordController.text.trim(),
        define: defineController.text.trim(),
        wordType: wordTypeController.text.isNotEmpty ? wordTypeController.text : null,
        transcription: transcriptionController.text.isNotEmpty ? transcriptionController.text : null,
        example: exampleController.text.isNotEmpty ? exampleController.text : null,
        pictureUrl: pictureUrlController.text.isNotEmpty ? pictureUrlController.text : null,
        note: noteController.text.isNotEmpty ? noteController.text : null,
      );

      try {
        await FlashcardService().updateWord(updatedWord);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật từ thành công!')));
          _imageFileResult = null;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi cập nhật: $e')));
        }
      }
    }

    return AlertDialog(
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Padding(padding: const EdgeInsets.only(left: 24, top: 24), child: Text('Chỉnh sửa: ${word.word}', style: const TextStyle(fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
        ]),
        content: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          final fileName = _imageFileResult?.files.single.name ?? (word.pictureUrl ?? 'No file chosen');
          return SingleChildScrollView(
              child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Từ mới'),
                    TextField(controller: wordController),
                    const SizedBox(height: 16),
                    const Text('Định nghĩa'),
                    TextField(controller: defineController, maxLines: 3),
                    const SizedBox(height: 16),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      initiallyExpanded: _isExpanded,
                      title: const Text('Chỉnh sửa chi tiết', style: TextStyle(color: Colors.blue, fontSize: 14)),
                      trailing: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.blue),
                      onExpansionChanged: (bool expanded) => setState(() => _isExpanded = expanded),
                      children: [
                        const SizedBox(height: 16),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Loại từ (N, V, ADJ...)'),
                                TextField(controller: wordTypeController),
                              ])),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Phiên âm'),
                                TextField(controller: transcriptionController),
                              ])),
                        ]),
                        const SizedBox(height: 16),
                        const Text('Ảnh'),
                        Row(children: [
                          SizedBox(
                              height: 34,
                              child: ElevatedButton(
                                onPressed: () => _chooseFileAction(setState),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black, elevation: 0),
                                child: const Text('Choose File'),
                              )),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileName,
                              style: const TextStyle(color: Colors.black54),
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        const Text('Hoặc Link Ảnh/URL'),
                        TextField(controller: pictureUrlController),
                        const SizedBox(height: 16),
                        const Text('Ví dụ'),
                        TextField(controller: exampleController, maxLines: 3),
                        const SizedBox(height: 16),
                        const Text('Ghi chú'),
                        TextField(controller: noteController, maxLines: 3),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: updateWord, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text('Lưu thay đổi'))),
                  ])));
        }));
  }

  Widget _buildBulkAddDialog(BuildContext context, String listId) {
    final List<Map<String, TextEditingController>> rows = [
      {'word': TextEditingController(), 'define': TextEditingController(), 'example': TextEditingController()}
    ];

    void addNewRow(StateSetter setState) => setState(() => rows.add({'word': TextEditingController(), 'define': TextEditingController(), 'example': TextEditingController()}));
    void removeRow(int index, StateSetter setState) {
      if (rows.length > 1) {
        setState(() {
          rows[index].forEach((key, controller) => controller.dispose());
          rows.removeAt(index);
        });
      }
    }

    Future<void> saveBulkWords() async {
      final wordsToCreate = rows
          .where((row) => row['word']!.text.isNotEmpty && row['define']!.text.isNotEmpty)
          .map((row) => Word(
        listWordId: listId,
        word: row['word']!.text.trim(),
        define: row['define']!.text.trim(),
        example: row['example']!.text.trim().isNotEmpty ? row['example']!.text.trim() : null,
      ))
          .toList();

      if (wordsToCreate.isEmpty) return;
      try {
        await FlashcardService().createWords(wordsToCreate);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm ${wordsToCreate.length} từ thành công!')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi thêm hàng loạt: $e')));
      }
    }

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.symmetric(vertical: 24.0),
      title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Padding(padding: EdgeInsets.only(left: 24, top: 24), child: Text('Tạo hàng loạt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24))),
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
      ]),
      content: StatefulBuilder(
        builder: (context, setState) => SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(children: const [
                  Expanded(flex: 2, child: Text('Từ mới', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 8),
                  Expanded(flex: 2, child: Text('Định nghĩa', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 8),
                  Expanded(flex: 3, child: Text('Ví dụ', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 48),
                ]),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Expanded(flex: 2, child: TextField(controller: rows[index]['word'], decoration: const InputDecoration(hintText: 'Word...', border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: TextField(controller: rows[index]['define'], decoration: const InputDecoration(hintText: 'Definition...', border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: TextField(controller: rows[index]['example'], decoration: const InputDecoration(hintText: 'Example...', border: OutlineInputBorder()))),
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => removeRow(index, setState)),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  TextButton.icon(onPressed: () => addNewRow(setState), icon: const Icon(Icons.add), label: const Text('Thêm hàng')),
                  ElevatedButton(onPressed: saveBulkWords, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text('Lưu')),
                ]),
              ),
            ])),
      ),
    );
  }

  TableRow _buildBulkAddRow(int index) {
    return TableRow(children: [
      TableCell(child: Center(child: Text('$index'))),
      TableCell(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: TextField(decoration: const InputDecoration(border: InputBorder.none), textAlign: TextAlign.center))),
      TableCell(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: TextField(decoration: const InputDecoration(border: InputBorder.none), textAlign: TextAlign.center))),
      TableCell(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: TextField(decoration: const InputDecoration(border: InputBorder.none), textAlign: TextAlign.center))),
      TableCell(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: TextField(decoration: const InputDecoration(border: InputBorder.none), textAlign: TextAlign.center))),
    ]);
  }
}