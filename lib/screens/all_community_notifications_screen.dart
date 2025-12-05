import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/notification.dart';
import 'package:learning_english/services/notification_service.dart';
import 'package:learning_english/core/utils/date_formatter.dart';

class AllCommunityNotificationsScreen extends StatefulWidget {
  const AllCommunityNotificationsScreen({super.key});

  @override
  State<AllCommunityNotificationsScreen> createState() =>
      _AllCommunityNotificationsScreenState();
}

class _AllCommunityNotificationsScreenState
    extends State<AllCommunityNotificationsScreen> {
  late NotificationService _notificationService;
  List<CommunityNotification> allNotifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadAllNotifications();
  }

  void _initializeService() {
    final supabase = Supabase.instance.client;
    _notificationService = NotificationService(supabase: supabase);
  }

  Future<void> _loadAllNotifications() async {
    try {
      setState(() => isLoading = true);

      final notifications =
          await _notificationService.getAllCommunityNotifications();

      setState(() {
        allNotifications = notifications;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading all notifications: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông báo mới nhất',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            Text(
              '${allNotifications.length} kết quả',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : allNotifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAllNotifications,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: allNotifications.length,
                    itemBuilder: (context, index) {
                      return _buildCommunityNotificationCard(
                        allNotifications[index],
                        index,
                      );
                    },
                  ),
                ),
    );
  }

  // ✅ EMPTY STATE
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16),
          Text(
            'Chưa có thông báo nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Các kết quả xuất sắc sẽ hiển thị ở đây',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ COMMUNITY NOTIFICATION CARD
  Widget _buildCommunityNotificationCard(
      CommunityNotification notif, int index) {
    // ✅ SAFE: Check null values
    final userName = notif.userName ?? 'Người dùng';
    final userAvatar = notif.userAvatar;
    final score = notif.metadata?.score ?? 0.0;
    final correctAnswers = notif.metadata?.correctAnswers ?? 0;
    final totalQuestions = notif.metadata?.totalQuestions ?? 0;
    final attempts = notif.metadata?.attempts ?? 0;
    final courseName = notif.metadata?.courseName ?? '';
    final moduleName = notif.metadata?.moduleName ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              // Ranking badge
              if (index < 3)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: index == 0
                          ? [Color(0xFFFFD700), Color(0xFFFFA000)]
                          : index == 1
                              ? [Color(0xFFC0C0C0), Color(0xFF9E9E9E)]
                              : [Color(0xFFCD7F32), Color(0xFF8D6E63)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              SizedBox(width: index < 3 ? 12 : 0),

              // ✅ FIXED: Avatar with null check
              ClipOval(
                child: userAvatar != null && userAvatar.isNotEmpty
                    ? Image.network(
                        userAvatar,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultAvatar(userName);
                        },
                      )
                    : _buildDefaultAvatar(userName),
              ),
              SizedBox(width: 12),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      DateFormatter.formatTimeAgo(
                          notif.createdAt.toIso8601String()),
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),

              // Score badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: score >= 90
                        ? [Color(0xFF66BB6A), Color(0xFF4CAF50)]
                        : score >= 80
                            ? [Color(0xFF81C784), Color(0xFF66BB6A)]
                            : [Color(0xFFFDD835), Color(0xFFFBC02D)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      '${score.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // TITLE
          Text(
            notif.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
              height: 1.4,
            ),
          ),

          SizedBox(height: 8),

          // MESSAGE
          Text(
            notif.message,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: 12),

          // STATS ROW
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Correct answers
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.check_circle,
                    iconColor: Color(0xFF4CAF50),
                    value: '$correctAnswers/$totalQuestions',
                    label: 'Câu đúng',
                  ),
                ),

                // Attempts
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.repeat,
                    iconColor: Color(0xFF2196F3),
                    value: '$attempts',
                    label: 'Lần thử',
                  ),
                ),
              ],
            ),
          ),

          // COURSE INFO
          if (courseName.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.school, size: 14, color: Color(0xFF999999)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$courseName${moduleName.isNotEmpty ? " - $moduleName" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ✅ Helper: Default avatar
  Widget _buildDefaultAvatar(String name) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF64B5F6), Color(0xFF2196F3)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ✅ Helper: Stat item
  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
      ],
    );
  }
}