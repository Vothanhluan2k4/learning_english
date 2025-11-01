import 'package:flutter/material.dart';
import 'package:learning_english/screens/all_community_notifications_screen.dart';
import 'package:learning_english/screens/drawer_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/notification.dart';
import 'package:learning_english/services/notification_service.dart';
import 'package:learning_english/utils/date_formatter.dart';
import 'package:learning_english/screens/community_notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late NotificationService _notificationService;
  late String userId;

  UserInfo? userInfo;
  NotificationModel? personalNotification;
  List<CommunityNotification> communityNotifications = [];
  int unreadCount = 0;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadData();
  }

  void _initializeService() {
    final supabase = Supabase.instance.client;
    _notificationService = NotificationService(supabase: supabase);
    userId = supabase.auth.currentUser?.id ?? '';
  }

  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);

      // 1. Lấy thông tin user hiện tại
      userInfo = await _notificationService.getUserInfo(userId);
      // 2. Lấy thông báo CỘNG ĐỒNG (tất cả users có điểm > 70)
      communityNotifications =
          await _notificationService.getCommunityNotifications(limit: 10);
      
      // 3. Đếm thông báo chưa đọc (chỉ của user hiện tại)
      unreadCount = await _notificationService.getUnreadCount(userId);

      debugPrint('📊 Personal: ${personalNotification != null ? 1 : 0}, Community: ${communityNotifications.length}');

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),
                      
                      // GREETING
                      _buildGreetingSection(),
                                 
                      SizedBox(height: 24),

                      // ACTION CARDS
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hành động',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            SizedBox(height: 16),
                            _buildActionCardsNew(),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // CHALLENGE CARD
                      // Padding(
                      //   padding: EdgeInsets.symmetric(horizontal: 16),
                      //   child: Column(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     children: [
                      //       Text(
                      //         'Hoạt động nổi bật',
                      //         style: TextStyle(
                      //           fontSize: 20,
                      //           fontWeight: FontWeight.bold,
                      //           color: Color(0xFF1A1A1A),
                      //         ),
                      //       ),
                      //       SizedBox(height: 16),
                      //       _buildChallengeCard(),
                      //     ],
                      //   ),
                      // ),

                      // SizedBox(height: 24),

                      // // LEARNING TIP
                      // Padding(
                      //   padding: EdgeInsets.symmetric(horizontal: 16),
                      //   child: _buildLearningTipCard(),
                      // ),

                      // SizedBox(height: 24),

                      // NOTIFICATIONS
                      // ...existing code...

                    // NOTIFICATIONS SECTION - FIX XEM THÊM BUTTON
                    if (personalNotification != null || communityNotifications.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Thông báo mới nhất',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                // ✅ XEM THÊM BUTTON - ALWAYS SHOW IF THERE ARE COMMUNITY NOTIFICATIONS
                                if (communityNotifications.isNotEmpty)
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AllCommunityNotificationsScreen(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      backgroundColor: Color(0xFFE3F2FD),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Xem thêm',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2196F3),
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 12,
                                          color: Color(0xFF2196F3),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 16),
                            _buildNotificationsSection(),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // GREETING SECTION - MODERN DESIGN
  Widget _buildGreetingSection() {
    final greeting = DateFormatter.getGreeting();
    final userName = userInfo?.fullName ?? 'User';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF2196F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2196F3).withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '👋',
                style: TextStyle(fontSize: 28),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ACTION CARDS - IMPROVED DESIGN
  Widget _buildActionCardsNew() {
    final cards = [
      {
        'title': 'Luyện đề',
        'icon': Icons.trending_up,
        'color': Color(0xFFFF9800),
        'route': 'courses',
      },
      {
        'title': 'Flashcards',
        'icon': Icons.style,
        'color': Color(0xFF9C27B0),
        'route': 'flashcard',
      },
      {
        'title': 'Ngữ pháp',
        'icon': Icons.menu_book,
        'color': Color(0xFF2196F3),
        'route': 'grammar',
      },
    ];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: cards
            .map((card) => _buildActionCardItem(
                  title: card['title'] as String,
                  icon: card['icon'] as IconData,
                  color: card['color'] as Color,
                  route: card['route'] as String,
                ))
            .toList(),
      ),
    );
  }

  // ACTION CARD ITEM
  Widget _buildActionCardItem({
    required String title,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return GestureDetector(
      onTap: () {
        int drawerIndex;
        switch (route) {
          case 'courses':
            drawerIndex = 1; // Luyện đề
            break;
          case 'flashcard':
            drawerIndex = 3; // FlashCards
            break;
          case 'grammar':
            drawerIndex = 2; // Ngữ pháp
            break;
          default:
            drawerIndex = 0;
        }
        Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DrawerScreen(initialIndex: drawerIndex),
        ),
      );
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 30,
              color: color,
            ),
          ),
          SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  // CHALLENGE CARD - ENHANCED
  Widget _buildChallengeCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF7043), Color(0xFFFF5722)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF5722).withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.emoji_events,
              size: 36,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuộc thi 30 ngày',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '"Quizz" - Chiến nào!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: Colors.white,
            size: 20,
          ),
        ],
      ),
    );
  }

  // LEARNING TIP - REFINED
  Widget _buildLearningTipCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF90CAF9),
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Color(0xFF2196F3).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.tips_and_updates,
              size: 28,
              color: Color(0xFF1976D2),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gợi ý học tập',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Bạn làm sai 3 câu về thì quá khứ – hãy ôn lại chủ đề Past Simple nhé!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1565C0),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    debugPrint('View lesson');
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Xem bài học',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NOTIFICATIONS SECTION
  Widget _buildNotificationsSection() {
    return Column(
      children: [
        if (personalNotification != null) ...[
          _buildPersonalNotificationItem(),
          SizedBox(height: 12),
        ],
        ...communityNotifications
            .take(2)
            .map((notif) => Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _buildCommunityNotificationItem(notif),
                ))
            .toList(),
      ],
    );
  }

  // PERSONAL NOTIFICATION
  Widget _buildPersonalNotificationItem() {
    if (personalNotification == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF81C784),
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  personalNotification!.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  personalNotification!.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF388E3C),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // COMMUNITY NOTIFICATION
  Widget _buildCommunityNotificationItem(CommunityNotification notif) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF64B5F6), Color(0xFF2196F3)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      notif.userName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF81C784), Color(0xFF66BB6A)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${notif.metadata.score.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  DateFormatter.formatTimeAgo(notif.createdAt.toIso8601String()),
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF999999),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  notif.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Color(0xFF4CAF50),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '${notif.metadata.correctAnswers}/${notif.metadata.totalQuestions} câu đúng',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}