import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/models/word.dart';
import 'package:learning_english/screens/flashcard/ReviewLearningScreen.dart';
import 'package:learning_english/services/flashcard_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learning_english/screens/flashcard/random_review_screen.dart';

class ReviewSessionScreen extends StatefulWidget {
  final ListWord list;
  const ReviewSessionScreen({super.key, required this.list});

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen> with SingleTickerProviderStateMixin {
  late Future<List<Word>> _wordsFuture;
  late ListWord _currentList;
  FilePickerResult? _imageFileResult;
  final FlutterTts flutterTts = FlutterTts();
  // KHÔNG CẦN THAY ĐỔI: Giữ State cục bộ
  Map<String, int> _progressData = {'total': 0, 'studied': 0, 'remembered': 0, 'to_review': 0};
  bool _isProgressLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showProgress = true;

  // --- ✨ Modern Color Scheme ---
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color secondaryColor = Color(0xFF00B894);
  static const Color accentColor = Color(0xFFFF7675);
  static const Color backgroundColor = Color(0xFFF5F6FA);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);

  @override
  void initState() {
    super.initState();
    _currentList = widget.list;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
    _initializeTts();

    // Khởi tạo, gọi refresh toàn bộ
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
    _animationController.dispose();
    super.dispose();
  }

  // --- ✨ LOGIC CẬP NHẬT TIẾN ĐỘ TỐI ƯU ---

  // TÍNH TOÁN % TIẾN ĐỘ (Helper Getter)
  double get _progressPercentage {
    final total = _progressData['total'] ?? 0;
    final studied = _progressData['studied'] ?? 0;
    return total == 0 ? 0.0 : studied / total;
  }

  // HÀM 1: Tải lại Tiến độ VÀ Danh sách từ (Dùng khi thêm/xóa từ)
  void _refreshAllData() {
    if (_currentList.id == null) return;
    setState(() => _isProgressLoading = true);

    // Tải tiến độ
    FlashcardService().getProgress(_currentList.id!).then((progress) {
      if (mounted) setState(() { _progressData = progress; _isProgressLoading = false; });
    }).catchError((e) {
      if (mounted) { print('Lỗi khi tải tiến độ: $e'); setState(() => _isProgressLoading = false); }
    });

    // Tải list từ
    setState(() { _wordsFuture = FlashcardService().getWords(_currentList.id!); });
  }

  // ✨ HÀM 2 MỚI: Chỉ tải lại Tiến độ (Dùng sau khi học xong Flashcard)
  void _refreshProgressOnly() {
    if (_currentList.id == null) return;
    setState(() => _isProgressLoading = true);

    FlashcardService().getProgress(_currentList.id!).then((progress) {
      if (mounted) setState(() {
        _progressData = progress;
        _isProgressLoading = false;
      });
    }).catchError((e) {
      if (mounted) {
        print('Lỗi khi tải tiến độ: $e');
        setState(() => _isProgressLoading = false);
      }
    });
    // KHÔNG gọi setState cho _wordsFuture ở đây -> Giảm rebuild cho FutureBuilder
  }

  // --- LOGIC FUNCTIONS (Đã Cập Nhật) ---

  void _initializeTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
  }

  void _showReviewOptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.replay_circle_filled, color: primaryColor, size: 28)),
            const SizedBox(width: 12),
            const Text('Tiếp tục ôn tập', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Bạn đã ôn tập danh sách này trước đây. Bạn muốn ôn tiếp hay ôn lại từ đầu?'),
        actions: [
          TextButton(
            onPressed: () async { // Đã sửa thành async
              Navigator.pop(context);
              final shouldRefreshProgress = await Navigator.push(context, MaterialPageRoute(builder: (context) => ReviewLearningScreen(list: _currentList)));
              if (shouldRefreshProgress == true && mounted) {
                _refreshProgressOnly(); // Dùng refreshProgressOnly
              }
            },
            style: TextButton.styleFrom(backgroundColor: primaryColor.withOpacity(0.1), foregroundColor: primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Ôn tiếp', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async { // Đã sửa thành async
              Navigator.pop(context);
              final shouldRefreshProgress = await Navigator.push(context, MaterialPageRoute(builder: (context) => ReviewLearningScreen(list: _currentList, resetProgress: true)));
              if (shouldRefreshProgress == true && mounted) {
                _refreshProgressOnly(); // Dùng refreshProgressOnly
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Ôn lại từ đầu', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _playAudio(String word) async {
    if (word.isNotEmpty) { await flutterTts.speak(word); }
  }

  void _handleAddCard(BuildContext context) {
    if (_currentList.id == null) return;
    showDialog(
      context: context,
      builder: (context) => _buildAddCardDialog(context, _currentList),
    ).then((result) {
      // Khi thêm/xóa thẻ, TỔNG SỐ TỪ thay đổi -> Cần _refreshAllData
      if (result == true && mounted) {
        _refreshAllData();
      }
    });
  }

  void _handleDeleteCard(BuildContext context, String? wordId) {
    if (wordId == null) return;
    FlashcardService().deleteWord(wordId).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Xóa thẻ thành công!'), backgroundColor: secondaryColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
        // Khi thêm/xóa thẻ, TỔNG SỐ TỪ thay đổi -> Cần _refreshAllData
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.warning_rounded, color: accentColor, size: 28)),
            const SizedBox(width: 12),
            const Text('Dừng học list này?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Thao tác này sẽ xóa lịch sử ôn tập của list này. Các từ sẽ vẫn được giữ nguyên. Bạn có chắc chắn?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await FlashcardService().deleteReviewHistory(listId);
        final wordIds = (await FlashcardService().getWords(listId)).map((word) => word.id!).toList();
        for (var wordId in wordIds) {
          await FlashcardService().updateWordStatus(wordId, 'to_review', listId);
        }
        if (mounted) {
          setState(() => _showProgress = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Đã xóa lịch sử ôn tập thành công.'), backgroundColor: secondaryColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
          _refreshAllData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
          print('Chi tiết lỗi: $e');
        }
      }
    }
  }

  Future<void> _handleDeleteList() async {
    final listId = _currentList.id;
    if (listId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_forever_rounded, color: accentColor, size: 28)),
            const SizedBox(width: 12),
            const Text('Xác nhận xóa?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn xóa vĩnh viễn list này không? Tất cả các từ trong list cũng sẽ bị xóa. Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy bỏ', style: TextStyle(color: textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Xóa vĩnh viễn', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FlashcardService().deleteListWord(listId);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi xóa list: $e'), backgroundColor: accentColor));
      }
    }
  }

  Future<void> _editDeck(BuildContext context) async {
    final titleController = TextEditingController(text: _currentList.title);
    final descriptionController = TextEditingController(text: _currentList.description ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_rounded, color: primaryColor, size: 28)),
            const SizedBox(width: 12),
            const Text('Chỉnh sửa bộ thẻ', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Tiêu đề',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Mô tả',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () { Navigator.of(context).pop(); _handleDeleteList(); }, child: const Text('Xóa List Này', style: TextStyle(color: accentColor))),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: textSecondary))),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                try {
                  await FlashcardService().updateListWord(ListWord(id: _currentList.id, userId: _currentList.userId, title: titleController.text, description: descriptionController.text.isNotEmpty ? descriptionController.text : null));
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() { _currentList = ListWord(id: _currentList.id, userId: _currentList.userId, title: titleController.text, description: descriptionController.text.isNotEmpty ? descriptionController.text : null, wordCount: _currentList.wordCount); });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Cập nhật thành công!'), backgroundColor: secondaryColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _createBulkWords(BuildContext context) async {
    showDialog(context: context, builder: (context) => _buildBulkAddDialog(context, _currentList.id!)).then((result) {
      if (result == true && mounted) _refreshAllData();
    });
  }

  void _handleEditWord(BuildContext context, Word word) {
    showDialog(context: context, builder: (context) => _buildEditWordDialog(context, word)).then((result) {
      if (result == true && mounted) _refreshAllData();
    });
  }

  // --- ✨ UI BUILDERS (Redesigned for Responsiveness) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        // ✨ NEW: Added LayoutBuilder and ConstrainedBox for responsive layout
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200), // Max width for web
                // ✨ NEW: Added Scrollbar for better web/desktop experience
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 24.0),
                        _buildActionButtons(),
                        const SizedBox(height: 24.0),
                        if (_showProgress) ...[
                          _buildProgressSection(),
                          const SizedBox(height: 32.0),
                        ],
                        // Dùng total từ _progressData để hiển thị số lượng từ
                        _buildSectionTitle('Danh sách từ vựng', _progressData['total'] ?? 0),
                        const SizedBox(height: 16.0),
                        FutureBuilder<List<Word>>(
                          future: _wordsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return _buildLoadingShimmer(constraints);
                            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return _buildEmptyState();
                            }
                            return _buildWordList(snapshot.data!, constraints);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: cardColor,
      foregroundColor: textPrimary,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bộ thẻ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textSecondary)),
          Text(_currentList.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
        ],
      ),
      centerTitle: false,
      actions: [
        if (MediaQuery.of(context).size.width > 700)
          Row(
            children: [
              _buildAppBarButton(icon: Icons.edit_rounded, label: 'Chỉnh sửa', onPressed: () => _editDeck(context)),
              const SizedBox(width: 8),
              _buildAppBarButton(icon: Icons.add_rounded, label: 'Thêm từ', onPressed: () => _handleAddCard(context)),
              const SizedBox(width: 8),
              _buildAppBarButton(icon: Icons.library_add_rounded, label: 'Tạo hàng loạt', onPressed: () => _createBulkWords(context)),
              const SizedBox(width: 16.0),
            ],
          )
        else
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: textPrimary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'edit') _editDeck(context);
              if (value == 'add') _handleAddCard(context);
              if (value == 'bulk') _createBulkWords(context);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'edit', child: Row(children: const [Icon(Icons.edit_rounded, color: textPrimary, size: 20), SizedBox(width: 12), Text('Chỉnh sửa')])),
              PopupMenuItem<String>(value: 'add', child: Row(children: const [Icon(Icons.add_rounded, color: textPrimary, size: 20), SizedBox(width: 12), Text('Thêm từ mới')])),
              PopupMenuItem<String>(value: 'bulk', child: Row(children: const [Icon(Icons.library_add_rounded, color: textPrimary, size: 20), SizedBox(width: 12), Text('Tạo hàng loạt')])),
            ],
          ),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1.0), child: Container(color: Colors.grey.shade200, height: 1.0)),
    );
  }

  Widget _buildAppBarButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(
        foregroundColor: textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // NÚT "Luyện tập flashcards"
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.play_circle_filled_rounded, size: 24),
            label: const Text(
              'Luyện tập flashcards',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              // ✨ CHỈNH SỬA QUAN TRỌNG: Dùng Navigator.push trả về giá trị
              // Màn hình ReviewLearningScreen CẦN trả về `true` nếu có từ đã học/thay đổi status.
              final bool? shouldRefreshProgress = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => ReviewLearningScreen(list: _currentList)),
              );
              // Nếu màn hình con trả về true, chỉ refresh tiến độ
              if (shouldRefreshProgress == true && mounted) {
                _refreshProgressOnly();
              }
            },
          ),
        ),

        const SizedBox(height: 12),

        // HÀNG: "Học lại từ đầu" + "Xem ngẫu nhiên"
        Row(
          children: [
            // NÚT "Học lại từ đầu"
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Học lại từ đầu',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.refresh_rounded, color: Colors.orange, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Text('Học lại từ đầu?', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: const Text('Tất cả tiến độ học tập sẽ bị xóa. Bạn sẽ học lại từ đầu như lần đầu tiên.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Hủy', style: TextStyle(color: textSecondary)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                          child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await FlashcardService().resetListProgress(_currentList.id!);
                      if (mounted) {

                        // ✨ SỬA ĐỔI QUAN TRỌNG: DÙNG push THAY VÌ pushReplacement
                        final bool? shouldRefreshProgress = await Navigator.push<bool?>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReviewLearningScreen(list: _currentList, resetProgress: true),
                          ),
                        );

                        if (shouldRefreshProgress == true && mounted) {
                          // Nếu ReviewLearningScreen có thay đổi (kể cả dừng), chỉ refresh tiến độ và KHÔNG pop ReviewSessionScreen
                          _refreshProgressOnly();
                        } else {
                          // Nếu người dùng reset xong mà không học gì, chỉ cần refresh để thấy tiến độ reset (nếu có)
                          _refreshAllData();
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi khi đặt lại: $e'), backgroundColor: accentColor),
                        );
                      }
                    }
                  }
                },
              ),
            ),

            const SizedBox(width: 12), // Khoảng cách giữa 2 nút

            // NÚT "XEM NGẪU NHIÊN" – TÍCH HỢP CHUYÊN NGHIỆP
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text(
                  'Xem ngẫu nhiên',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RandomReviewScreen(list: _currentList)),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildProgressSection() {
    if (_isProgressLoading) {
      return Card(
        elevation: 0, color: cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(color: primaryColor))),
      );
    }
    return Card(
      elevation: 0, color: cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0), side: BorderSide(color: Colors.grey.shade200, width: 1)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.analytics_rounded, color: primaryColor, size: 24)),
            const SizedBox(width: 12),
            const Text('Tiến độ học tập', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
          ]),

          // ✨ BỔ SUNG: Thanh tiến trình tổng thể
          const SizedBox(height: 20),
          _buildOverallProgressBar(),
          const SizedBox(height: 32),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _buildStatItem(_progressData['total'].toString(), 'Tổng số từ', primaryColor, Icons.library_books_rounded),
                  _buildStatDivider(),
                  _buildStatItem(_progressData['studied'].toString(), 'Đã học', Colors.blue, Icons.school_rounded),
                  _buildStatDivider(),
                  _buildStatItem(_progressData['remembered'].toString(), 'Đã nhớ', secondaryColor, Icons.check_circle_rounded),
                  _buildStatDivider(),
                  _buildStatItem(_progressData['to_review'].toString(), 'Cần ôn tập', (_progressData['to_review'] ?? 0) > 0 ? accentColor : textSecondary, Icons.refresh_rounded),
                ]);
              } else {
                return Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _buildStatItem(_progressData['total'].toString(), 'Tổng số từ', primaryColor, Icons.library_books_rounded),
                    _buildStatItem(_progressData['studied'].toString(), 'Đã học', Colors.blue, Icons.school_rounded),
                  ]),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _buildStatItem(_progressData['remembered'].toString(), 'Đã nhớ', secondaryColor, Icons.check_circle_rounded),
                    _buildStatItem(_progressData['to_review'].toString(), 'Cần ôn tập', (_progressData['to_review'] ?? 0) > 0 ? accentColor : textSecondary, Icons.refresh_rounded),
                  ]),
                ]);
              }
            },
          ),
        ]),
      ),
    );
  }

  // ✨ HÀM MỚI: Thanh tiến trình tổng thể (LinearProgressIndicator)
  Widget _buildOverallProgressBar() {
    final percentage = _progressPercentage;
    final total = _progressData['total'] ?? 0;
    final studied = _progressData['studied'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đã hoàn thành',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
            ),
            Text(
              '${(percentage * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: secondaryColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage, // Giá trị từ 0.0 đến 1.0
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(secondaryColor), // Màu xanh lá cho tiến độ hoàn thành
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Đã học $studied/$total từ',
            style: const TextStyle(fontSize: 12, color: textSecondary),
          ),
        ),
      ],
    );
  }


  Widget _buildStatDivider() {
    return Container(height: 60, width: 1, color: Colors.grey.shade200);
  }

  Widget _buildStatItem(String value, String label, Color color, IconData icon) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Text('$count từ', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    ]);
  }

  Widget _buildLoadingShimmer(BoxConstraints constraints) {
    // ... (Giữ nguyên) ...
    final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 16.0, mainAxisSpacing: 16.0, childAspectRatio: crossAxisCount > 1 ? 2.8 : 2.2),
      itemCount: 4,
      itemBuilder: (context, index) {
        // Simple shimmer placeholder
        return Card(
          elevation: 0, color: cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0), side: BorderSide(color: Colors.grey.shade200, width: 1)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(children: [
              Container(width: 80, height: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 120, height: 20, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 12),
                  Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 8),
                  Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), shape: BoxShape.circle), child: Icon(Icons.style_rounded, size: 64, color: primaryColor.withOpacity(0.6))),
          const SizedBox(height: 24),
          const Text('Chưa có thẻ nào', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 8),
          const Text('Hãy thêm thẻ đầu tiên để bắt đầu học!', style: TextStyle(fontSize: 14, color: textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _handleAddCard(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm thẻ mới', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      ),
    );
  }

  Widget _buildWordList(List<Word> words, BoxConstraints constraints) {
    // ✨ MODIFIED: Responsive crossAxisCount for word list
    final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
    final childAspectRatio = crossAxisCount > 1 ? 2.8 : 2.2;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 16.0, mainAxisSpacing: 16.0, childAspectRatio: childAspectRatio),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, double value, child) {
            return Transform.translate(offset: Offset(0, 20 * (1 - value)), child: Opacity(opacity: value, child: child));
          },
          child: _buildWordItem(context, word),
        );
      },
    );
  }

  Widget _buildWordItem(BuildContext context, Word word) {
    return Card(
      elevation: 0, margin: EdgeInsets.zero, color: cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0), side: BorderSide(color: Colors.grey.shade200, width: 1)),
      child: InkWell(
        onTap: () => _handleEditWord(context, word),
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side for image or placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: word.pictureUrl?.isNotEmpty ?? false
                    ? Image.network(
                  word.pictureUrl!,
                  height: double.infinity, width: 100, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(width: 100, color: Colors.grey.shade100, child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40))),
                )
                    : Container(width: 100, color: primaryColor.withOpacity(0.05), child: const Center(child: Icon(Icons.image_rounded, color: primaryColor, size: 40))),
              ),
              const SizedBox(width: 16),
              // Right side for text content
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(word.word, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if ((word.wordType?.isNotEmpty ?? false) || (word.transcription?.isNotEmpty ?? false))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${word.wordType ?? ''} ${word.transcription != null ? '/${word.transcription}/' : ''}', style: const TextStyle(fontSize: 13, color: textSecondary, fontStyle: FontStyle.italic)),
                          ),
                      ]),
                    ),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _buildIconButton(icon: Icons.volume_up_rounded, color: Colors.blue, onPressed: () => _playAudio(word.word), tooltip: 'Phát âm'),
                      _buildIconButton(icon: Icons.edit_rounded, color: secondaryColor, onPressed: () => _handleEditWord(context, word), tooltip: 'Chỉnh sửa'),
                      _buildIconButton(icon: Icons.delete_rounded, color: accentColor, onPressed: () => _handleDeleteCard(context, word.id), tooltip: 'Xóa'),
                    ]),
                  ]),
                  const SizedBox(height: 8.0),
                  Divider(color: Colors.grey.shade200, height: 1),
                  const SizedBox(height: 8.0),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildInfoSection('Định nghĩa', word.define ?? 'Chưa có định nghĩa', Icons.description_rounded),
                        if (word.example?.isNotEmpty ?? false) ...[const SizedBox(height: 12.0), _buildInfoSection('Ví dụ', word.example!, Icons.format_quote_rounded)],
                        if (word.note?.isNotEmpty ?? false) ...[const SizedBox(height: 12.0), _buildInfoSection('Ghi chú', word.note!, Icons.note_rounded)],
                      ]),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: primaryColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: textSecondary,
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Thay thế hàm _buildAddCardDialog hiện tại bằng hàm này
  Widget _buildAddCardDialog(BuildContext context, ListWord list) {
    final wordController = TextEditingController();
    final defineController = TextEditingController();
    final wordTypeController = TextEditingController();
    final transcriptionController = TextEditingController();
    final exampleController = TextEditingController();
    final noteController = TextEditingController();
    bool _isExpanded = false;

    // ✨ CHỈNH SỬA: Chuyển _imageFileResult thành biến cục bộ của dialog
    FilePickerResult? dialogImageFileResult;

    // Sử dụng PopScope để bắt sự kiện người dùng nhấn nút Back hoặc swipe to dismiss
    return PopScope(
      canPop: true, // Cho phép pop mặc định
      onPopInvoked: (didPop) {
        // Khi dialog bị đóng (nhấn nút Back vật lý hoặc swipe),
        // các controller sẽ tự dispose và dialogImageFileResult bị GC.
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.all(24),
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.05),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_card_rounded, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('Tạo flashcard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                // Khi đóng, pop với false để không refresh dữ liệu
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final fileName = dialogImageFileResult?.files.single.name ?? 'Chưa chọn file';

            Future<void> _chooseFileAction() async {
              final result = await FilePicker.platform.pickFiles(type: FileType.image);
              if (result != null) {
                setState(() {
                  dialogImageFileResult = result;
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
                pictureUrl: null,
                note: noteController.text.isNotEmpty ? noteController.text : null,
              );
              try {
                // Sử dụng biến cục bộ của dialog
                await FlashcardService().createWord(newWord, imageFile: dialogImageFileResult);
                if (mounted) {
                  // Thoát dialog với kết quả true (đã lưu)
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Thêm thẻ thành công!'),
                      backgroundColor: secondaryColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  // ✨ CHỈNH SỬA: Reset biến ảnh tạm thời về null SAU KHI LƯU THÀNH CÔNG
                  // Thao tác này là không cần thiết vì dialog đang pop, nhưng giữ lại
                  // để đảm bảo tính nhất quán nếu dialog được tái sử dụng.
                  dialogImageFileResult = null;
                }
              } catch (e) {
                if (mounted) {
                  // Không pop dialog, chỉ hiển thị lỗi
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi thêm: $e')));
                }
              }
            }

            return SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ... UI code khác (Container, _buildDialogTextField, ExpansionTile) ...
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_rounded, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'List: ${list.title}',
                            style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDialogTextField('Từ mới', wordController),
                    const SizedBox(height: 16),
                    _buildDialogTextField('Định nghĩa', defineController, maxLines: 3),
                    const SizedBox(height: 16),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Thêm phiên âm, ví dụ, ảnh, ghi chú...',
                        style: TextStyle(color: primaryColor, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      trailing: Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: primaryColor,
                      ),
                      onExpansionChanged: (bool expanded) => setState(() => _isExpanded = expanded),
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildDialogTextField('Loại từ (N,V,...)', wordTypeController)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildDialogTextField('Phiên âm', transcriptionController)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Ảnh', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              // ✨ CHỈNH SỬA: Gọi hàm cục bộ _chooseFileAction
                              onPressed: _chooseFileAction,
                              icon: const Icon(Icons.upload_file_rounded, size: 18),
                              label: const Text('Chọn file'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade100,
                                foregroundColor: textPrimary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                fileName,
                                style: TextStyle(color: textSecondary, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDialogTextField('Ví dụ (tối đa 10 câu)', exampleController, maxLines: 3),
                        const SizedBox(height: 16),
                        _buildDialogTextField('Ghi chú', noteController, maxLines: 3),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saveWord,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    // HÀM _chooseFileAction CẦN ĐƯỢC ĐỊNH NGHĨA NGOÀI ĐÂY NẾU DÙNG BIẾN CỤC BỘ DƯỚI DẠNG Dialog
    Future<void> _chooseFileActionDialog(StateSetter setState) async {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null) {
        setState(() {
          _imageFileResult = result;
        });
      }
    }

    Future<void> saveWordDialog() async {
      if (wordController.text.isEmpty || defineController.text.isEmpty) return;
      final newWord = Word(
        listWordId: list.id!,
        word: wordController.text.trim(),
        define: defineController.text.trim(),
        wordType: wordTypeController.text.isNotEmpty ? wordTypeController.text : null,
        transcription: transcriptionController.text.isNotEmpty ? transcriptionController.text : null,
        example: exampleController.text.isNotEmpty ? exampleController.text : null,
        pictureUrl: null,
        note: noteController.text.isNotEmpty ? noteController.text : null,
      );
      try {
        await FlashcardService().createWord(newWord, imageFile: _imageFileResult);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Thêm thẻ thành công!'),
              backgroundColor: secondaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          _imageFileResult = null;
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context, false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi thêm: $e')));
        }
      }
    }

    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ HEADER
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_card_rounded, color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Tạo flashcard',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context, false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ✅ CONTENT (Scrollable)
              Flexible(
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    final fileName = _imageFileResult?.files.single.name ?? 'Chưa chọn file';
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // List info badge
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.folder_rounded, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'List: ${list.title}',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Required fields
                          _buildDialogTextField('Từ mới *', wordController),
                          const SizedBox(height: 16),
                          _buildDialogTextField('Định nghĩa *', defineController, maxLines: 3),
                          const SizedBox(height: 16),

                          // Optional fields (Expandable)
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(top: 16),
                              title: const Text(
                                'Thêm phiên âm, ví dụ, ảnh, ghi chú...',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Icon(
                                _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: primaryColor,
                              ),
                              onExpansionChanged: (bool expanded) => setState(() => _isExpanded = expanded),
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildDialogTextField('Loại từ', wordTypeController)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildDialogTextField('Phiên âm', transcriptionController)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Image picker
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Ảnh', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _chooseFileActionDialog(setState),
                                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                                      label: const Text('Chọn file'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade100,
                                        foregroundColor: textPrimary,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        fileName,
                                        style: TextStyle(color: textSecondary, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildDialogTextField('Ví dụ', exampleController, maxLines: 3),
                                const SizedBox(height: 16),
                                _buildDialogTextField('Ghi chú', noteController, maxLines: 3),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Save button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: saveWordDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        )
    );
  }

  Widget _buildDialogTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildEditWordDialog(BuildContext context, Word word) {
    final wordController = TextEditingController(text: word.word);
    final defineController = TextEditingController(text: word.define);
    final wordTypeController = TextEditingController(text: word.wordType);
    final transcriptionController = TextEditingController(text: word.transcription);
    final exampleController = TextEditingController(text: word.example);
    final noteController = TextEditingController(text: word.note);
    bool _isExpanded = true;

    Future<void> _chooseFileAction(StateSetter setState) async {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null) {
        setState(() {
          _imageFileResult = result;
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
        pictureUrl: null,
        note: noteController.text.isNotEmpty ? noteController.text : null,
      );

      try {
        await FlashcardService().updateWord(updatedWord, imageFile: _imageFileResult);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cập nhật từ thành công!'),
              backgroundColor: secondaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          _imageFileResult = null;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi cập nhật: $e')));
        }
      }
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.all(24),
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: secondaryColor.withOpacity(0.05),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded, color: secondaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chỉnh sửa: ${word.word}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final fileName = _imageFileResult?.files.single.name ?? (word.pictureUrl?.split('/').last ?? 'Chưa chọn file');
          return SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogTextField('Từ mới', wordController),
                  const SizedBox(height: 16),
                  _buildDialogTextField('Định nghĩa', defineController, maxLines: 3),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    initiallyExpanded: _isExpanded,
                    title: const Text(
                      'Chỉnh sửa chi tiết',
                      style: TextStyle(color: primaryColor, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    trailing: Icon(
                      _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: primaryColor,
                    ),
                    onExpansionChanged: (bool expanded) => setState(() => _isExpanded = expanded),
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildDialogTextField('Loại từ', wordTypeController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDialogTextField('Phiên âm', transcriptionController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Ảnh', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _chooseFileAction(setState),
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: const Text('Chọn file'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              foregroundColor: textPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              fileName,
                              style: TextStyle(color: textSecondary, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDialogTextField('Ví dụ', exampleController, maxLines: 3),
                      const SizedBox(height: 16),
                      _buildDialogTextField('Ghi chú', noteController, maxLines: 3),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: updateWord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBulkAddDialog(BuildContext context, String listId) {
    final List<Map<String, TextEditingController>> rows = [
      {'word': TextEditingController(), 'define': TextEditingController(), 'example': TextEditingController()}
    ];

    void addNewRow(StateSetter setState) => setState(() => rows.add({
      'word': TextEditingController(),
      'define': TextEditingController(),
      'example': TextEditingController()
    }));

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã thêm ${wordsToCreate.length} từ thành công!'),
              backgroundColor: secondaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi thêm hàng loạt: $e')),
          );
        }
      }
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.symmetric(vertical: 24.0),
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.library_add_rounded, color: primaryColor, size: 28),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Tạo hàng loạt',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
      content: StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                  ),
                ),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Từ mới',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Định nghĩa',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Ví dụ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: rows.length,
                  itemBuilder: (context, index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: rows[index]['word'],
                            decoration: InputDecoration(
                              hintText: 'Word...',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: rows[index]['define'],
                            decoration: InputDecoration(
                              hintText: 'Definition...',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: rows[index]['example'],
                            decoration: InputDecoration(
                              hintText: 'Example...',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: accentColor, size: 20),
                            onPressed: () => removeRow(index, setState),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            tooltip: 'Xóa hàng',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => addNewRow(setState),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Thêm từ', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: const BorderSide(color: primaryColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    SizedBox(
                      width: 4,
                    ),
                    ElevatedButton.icon(
                      onPressed: saveBulkWords,
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: Text('Lưu ${rows.length} từ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}