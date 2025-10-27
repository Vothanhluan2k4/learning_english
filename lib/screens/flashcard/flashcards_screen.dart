import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/service/flashcard_service.dart';
import 'create_deck_screen.dart';
import 'review_session_screen.dart';

// Import thêm để dùng các widget giống trên web
// Giả sử các model và service đã được định nghĩa đúng
// Các màn hình CreateDeckScreen và ReviewSessionScreen đã tồn tại

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

// Thêm SingleTickerProviderStateMixin để dùng TabController
class _FlashcardsScreenState extends State<FlashcardsScreen> with SingleTickerProviderStateMixin {
  late Future<List<ListWord>> _listWordsFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 tab: Của tôi, Đang học, Khám phá
    _refreshListWords();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Vẫn giữ logic reload khi quay lại từ CreateDeckScreen
    // Dùng addPostFrameCallback để tránh lỗi setState trong didChangeDependencies
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

  // Reload danh sách bộ thẻ
  void _refreshListWords() {
    setState(() {
      _listWordsFuture = FlashcardService().getListWords();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra đăng nhập
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
            // Thanh điều hướng Tab Bar (thay thế cho AppBar)
            _buildTabBar(context),
            // Banner thông báo
            _buildInfoBanner(),
            // Phần thân của từng tab
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyListsTab(context), // Tab "List từ của tôi"
                  _buildLearningTab(),      // Tab "Đang học"
                  _buildExploreTab(),       // Tab "Khám phá"
                ],
              ),
            ),
          ],
        ),
      ),
      // Bỏ BottomNavigationBar
    );
  }

  // Xây dựng thanh TabBar
  Widget _buildTabBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
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

  // Xây dựng Banner thông báo
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

  // Xây dựng nội dung Tab "List từ của tôi" (My Lists)
  Widget _buildMyListsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'List từ đã tạo:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
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

  // Xây dựng nội dung Tab "Đang học" (Learning)
  Widget _buildLearningTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đang học:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16.0),
          Center(
            child: Column(
              children: [
                const Text(
                  'Bạn chưa học list từ nào.',
                  style: TextStyle(fontSize: 16),
                ),
                TextButton(
                  onPressed: () {
                    _tabController.animateTo(2); // Chuyển sang tab Khám phá
                    // Hoặc thêm logic điều hướng khác
                  },
                  child: const Text(
                    'Khám phá ngay',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Text(
                  'hoặc bắt đầu tạo các list từ mới.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Xây dựng nội dung Tab "Khám phá" (Explore) - Để trống hoặc thêm nội dung tương ứng
  Widget _buildExploreTab() {
    return const Center(child: Text('Nội dung khám phá'));
  }

  // Xây dựng dạng Grid cho các bộ thẻ
  Widget _buildDeckGrid(BuildContext context, List<ListWord> lists) {
    // Thêm list tạo bộ thẻ mới vào đầu danh sách
    List<Widget> deckCards = [
      // Card "Tạo list từ"
      _buildCreateDeckCard(context),
      // Danh sách các bộ thẻ đã tạo
      ...lists.map((list) => _buildDeckItemCard(context, list)).toList(),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // Để cuộn cùng với SingleChildScrollView
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 cột
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 1.0, // Tỉ lệ gần giống hình vuông
      ),
      itemCount: deckCards.length,
      itemBuilder: (context, index) => deckCards[index],
    );
  }

  // Widget Card "Tạo list từ"
  Widget _buildCreateDeckCard(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateDeckScreen()),
        );
        _refreshListWords(); // Reload khi quay lại
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
              Text(
                'Tạo list từ',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget Card hiển thị thông tin bộ thẻ
  Widget _buildDeckItemCard(BuildContext context, ListWord list) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewSessionScreen(list: list),
        ),
      ),
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
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
              // Số lượng từ và trạng thái
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bookmark_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      // Logic này giờ sẽ hiển thị đúng số lượng từ
                      Text('${list.wordCount ?? 0} từ', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Learning', // Giả định trạng thái
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              // Người tạo/Chia sẻ
              Row(
                children: [
                  const CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.grey,
                    child: Text('Q', style: TextStyle(fontSize: 8, color: Colors.white)),
                  ),
                  const SizedBox(width: 4),
                  // Cần lấy thông tin người tạo thực tế, giả định là 'quybi190804'
                  Text(
                    list.creatorId?.substring(0, 8) ?? 'Unknown',
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

