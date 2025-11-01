import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/services/flashcard_service.dart';
import 'package:learning_english/screens/flashcard/create_deck_screen.dart';
import 'package:learning_english/screens/flashcard/review_session_screen.dart';
import 'package:learning_english/screens/flashcard/ReviewLearningScreen.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> with SingleTickerProviderStateMixin {
  late Future<List<ListWord>> _listWordsFuture;
  late TabController _tabController;

  // --- Modern Color Scheme ---
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color secondaryColor = Color(0xFF00B894);
  static const Color backgroundColor = Color(0xFFF5F6FA);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshListWords();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshListWords();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshListWords() {
    setState(() {
      _listWordsFuture = FlashcardService().getListWords();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/signIn');
      });
      return const Scaffold(backgroundColor: backgroundColor);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildHeader(context)];
        },
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMyListsTab(context),
                    _buildLearningTab(),
                    _buildExploreTab(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  SliverAppBar _buildHeader(BuildContext context) {
    return SliverAppBar(
      title: const Text('Flashcards', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
      backgroundColor: backgroundColor,
      elevation: 0,
      pinned: true,
      floating: true,
      forceElevated: true,
      shadowColor: Colors.black.withOpacity(0.1),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: TabBar(
              controller: _tabController,
              indicatorColor: primaryColor,
              labelColor: primaryColor,
              unselectedLabelColor: textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              tabs: const [
                Tab(text: 'Bộ thẻ của tôi'),
                Tab(text: 'Đang học'),
                Tab(text: 'Khám phá'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: secondaryColor.withOpacity(0.5)),
      ),
      color: secondaryColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: secondaryColor, size: 24),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                'Mẹo: Bạn có thể tạo flashcards từ các từ đã highlight trong trang chi tiết từ vựng.',
                style: const TextStyle(color: textPrimary, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyListsTab(BuildContext context) {
    return FutureBuilder<List<ListWord>>(
      future: _listWordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        final lists = snapshot.data ?? [];
        return Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoBanner(),
                _buildDeckGrid(context, lists),
                // === NÚT "XEM TẤT CẢ" ===
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _tabController.animateTo(1); // Chuyển sang tab "Đang học"
                      },
                      child: const Text(
                        "Xem tất cả >",
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: primaryColor.withOpacity(0.8)),
            ),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningTab() {
    return FutureBuilder<List<ListWord>>(
      future: _listWordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Lỗi tải dữ liệu',
            message: 'Vui lòng thử lại sau.',
          );
        }

        final lists = snapshot.data!;
        if (lists.isEmpty) {
          return _buildEmptyState(
            icon: Icons.school_outlined,
            title: 'Chưa có gì ở đây',
            message: 'Các bộ thẻ bạn đang học sẽ xuất hiện tại đây.',
          );
        }


        final activeLists = lists.where((l) => (l.wordCount ?? 0) > 0).toList();
        if (activeLists.isEmpty) {
          return _buildEmptyState(
            icon: Icons.auto_stories_outlined,
            title: 'Bắt đầu học thôi!',
            message: 'Chọn một bộ thẻ để bắt đầu học.',
          );
        }

        int totalStudied = 0;
        int totalRemembered = 0;
        int totalToReview = 0;
        final Map<String, Map<String, int>> progressCache = {};

        return FutureBuilder(
          future: Future.wait(activeLists.map((list) async {
            final progress = await FlashcardService().getProgress(list.id!);

            int total = progress['total'] ?? 0;
            int studied = progress['studied'] ?? 0;
            int remembered = progress['remembered'] ?? 0;

            // ✅ Đảm bảo dữ liệu không vượt tổng
            if (studied > total) studied = total;
            if (remembered > total) remembered = total;

            // ✅ Tính số cần ôn tập và tránh âm
            final toReview = max(0, total - studied - remembered);

            // ✅ Lưu vào cache
            progressCache[list.id!] = {
              'total': total,
              'studied': studied,
              'remembered': remembered,
            };

            // ✅ Cộng dồn tổng
            totalStudied += studied;
            totalRemembered += remembered;
            totalToReview += toReview;

            return list;
          })),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryColor));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đang học:',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // === THANH TIẾN ĐỘ ===
                  _buildProgressBar(totalStudied, totalRemembered, totalToReview),
                  const SizedBox(height: 16),

                  // === 3 Ô THỐNG KÊ ===
                  Row(
                    children: [
                      _buildStatCard('$totalStudied\nĐã học', Colors.green, Icons.auto_stories),
                      const SizedBox(width: 12),
                      _buildStatCard('$totalRemembered\nĐã nhớ', Colors.orange, Icons.check_circle),
                      const SizedBox(width: 12),
                      _buildStatCard('$totalToReview\nCần ôn tập', Colors.red, Icons.refresh),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // === DANH SÁCH BỘ HỌC ===
                  ...activeLists.map((list) {
                    final p = progressCache[list.id!] ??
                        {'total': 0, 'studied': 0, 'remembered': 0};
                    final total = p['total']!;
                    final studied = p['studied']!;
                    final remembered = p['remembered']!;
                    final toReview = max(0, total - studied - remembered);

                    return _buildActiveLearningCard(context, list, p, toReview);
                  }).toList(),
                ],
              ),
            );
          },
        );
      },
    );
  }


  // === THANH TIẾN ĐỘ MỚI ===
  Widget _buildProgressBar(int studied, int remembered, int toReview) {
    final total = studied + remembered + toReview;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildProgressNumber(studied, "Đã học", Colors.green),
            _buildProgressNumber(remembered, "Đã nhớ", Colors.orange),
            _buildProgressNumber(toReview, "Cần ôn tập", Colors.red),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Row(
              children: [
                if (studied > 0)
                  Expanded(
                    flex: studied,
                    child: Container(color: Colors.green),
                  ),
                if (remembered > 0)
                  Expanded(
                    flex: remembered,
                    child: Container(color: Colors.orange),
                  ),
                if (toReview > 0)
                  Expanded(
                    flex: toReview,
                    child: Container(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressNumber(int count, String label, Color color) {
    return Column(
      children: [
        Text(
          "$count",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: textSecondary),
        ),
      ],
    );
  }

  Widget _buildExploreTab() {
    return _buildEmptyState(
      icon: Icons.explore_outlined,
      title: 'Tính năng sắp ra mắt',
      message: 'Khám phá các bộ thẻ từ cộng đồng trong tương lai.',
    );
  }

  Widget _buildDeckGrid(BuildContext context, List<ListWord> lists) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = (screenWidth / 240).floor().clamp(2, 5);

    List<Widget> deckCards = [
      _buildCreateDeckCard(context),
      ...lists.map((list) => _buildDeckItemCard(context, list)).toList(),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 0.9,
      ),
      itemCount: deckCards.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: deckCards[index],
        );
      },
    );
  }

  Widget _buildCreateDeckCard(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateDeckScreen()),
        );
        if (result == true) _refreshListWords();
      },
      borderRadius: BorderRadius.circular(16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        color: cardColor,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline_rounded, color: primaryColor, size: 36),
              SizedBox(height: 12.0),
              Text('Tạo bộ thẻ mới', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeckItemCard(BuildContext context, ListWord list) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReviewSessionScreen(list: list)),
        );
        if (result == true) _refreshListWords();
      },
      borderRadius: BorderRadius.circular(16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.style_rounded, color: primaryColor, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                list.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                list.description ?? 'Không có mô tả',
                style: const TextStyle(color: textSecondary, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.layers_rounded, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text('${list.wordCount ?? 0} từ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    list.createdAt != null
                        ? DateFormat('dd/MM/yyyy').format(list.createdAt!)
                        : 'Không rõ',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String text, Color color, IconData icon) {
    final lines = text.split('\n');
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              lines[0],
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
            Text(
              lines[1],
              style: TextStyle(fontSize: 12, color: textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLearningCard(BuildContext context, ListWord list, Map<String, int> progress, int toReview) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.style_rounded, color: primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Cần ôn tập: $toReview', style: TextStyle(fontSize: 13, color: Colors.red.shade600)),
                      const SizedBox(width: 12),
                      Text('Đã nhớ: ${progress['remembered']}', style: TextStyle(fontSize: 13, color: Colors.orange.shade600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReviewLearningScreen(list: list)),
                );
                if (result == true) _refreshListWords();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Học tiếp', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}