import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/service/flashcard_service.dart';
import 'package:learning_english/screens/flashcard/create_deck_screen.dart';
import 'package:learning_english/screens/flashcard/review_session_screen.dart';
import 'package:intl/intl.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> with SingleTickerProviderStateMixin {
  late Future<List<ListWord>> _listWordsFuture;
  late TabController _tabController;

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
        Navigator.of(context).pushReplacementNamed('/signIn');
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            _buildTabBar(context),
            _buildInfoBanner(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyListsTab(context),
                  _buildLearningTab(),
                  _buildExploreTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1.0)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Theme.of(context).primaryColor,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.black54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: 'List từ của tôi'),
          Tab(text: 'Đang học'),
          Tab(text: 'Khám phá'),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      color: Colors.green.shade100,
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.green),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              'Chú ý: Bạn có thể tạo flashcards từ highlights (bao gồm các highlights các bạn đã tạo trước đây) trong trang chi tiết từ vựng.',
              style: TextStyle(color: Colors.green.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyListsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('List từ đã tạo:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16.0),
          FutureBuilder<List<ListWord>>(
            future: _listWordsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Lỗi: ${snapshot.error}'));
              }
              final lists = snapshot.data ?? [];
              return _buildDeckGrid(context, lists);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLearningTab() {
    return const Center(child: Text('Nội dung tab Đang học'));
  }

  Widget _buildExploreTab() {
    return const Center(child: Text('Nội dung tab Khám phá'));
  }

  Widget _buildDeckGrid(BuildContext context, List<ListWord> lists) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final crossAxisCount = isMobile ? 2 : 4;

    List<Widget> deckCards = [
      _buildCreateDeckCard(context),
      ...lists.map((list) => _buildDeckItemCard(context, list)).toList(),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 1.0,
      ),
      itemCount: deckCards.length,
      itemBuilder: (context, index) => deckCards[index],
    );
  }

  Widget _buildCreateDeckCard(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateDeckScreen()),
        );
        _refreshListWords();
      },
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.blue, size: 36),
              SizedBox(height: 8.0),
              Text('Tạo list từ', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // SỬA ĐỔI CHÍNH NẰM Ở ĐÂY
  // ==========================================================
  Widget _buildDeckItemCard(BuildContext context, ListWord list) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReviewSessionScreen(list: list)),
        );
        _refreshListWords();
      },
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tiêu đề list từ
              Text(
                list.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Số lượng từ và mô tả
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bookmark_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${list.wordCount ?? 0} từ', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // THAY ĐỔI 1: Thay "Learning" bằng mô tả
                  Text(
                    list.description ?? 'Không có mô tả',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontStyle: list.description == null ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // THAY ĐỔI 2: Thay avatar/tên bằng ngày tạo
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    list.createdAt != null
                        ? DateFormat('dd/MM/yyyy').format(list.createdAt!)
                        : 'Không rõ ngày',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}