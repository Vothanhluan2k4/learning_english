import 'package:flutter/material.dart';
import '../services/notification_appBar_service.dart';
import '../models/notification.dart';

class NotificationBell extends StatefulWidget {
  final String authId;

  const NotificationBell({
    super.key,
    required this.authId,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _notificationService = NotificationService();
  bool _hasNotification = false;
  int _unreadCount = 0;
  NotificationModel? _latestNotification;
  bool _isLoading = true;
  String? _userId;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    debugPrint('🔔 NotificationBell initialized with authId: ${widget.authId}');
    _loadNotification();
  }

  @override
  void didUpdateWidget(NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authId != widget.authId) {
      debugPrint('🔄 authId changed, reloading notification');
      _loadNotification();
    }
  }

  Future<void> _loadNotification() async {
    try {
      setState(() => _isLoading = true);
      debugPrint('🔄 Loading notification for authId: ${widget.authId}');

      final userId = await _notificationService.getUserIdFromAuthId(widget.authId);
      
      if (userId == null || userId.isEmpty) {
        debugPrint('❌ User ID is null or empty');
        setState(() => _isLoading = false);
        return;
      }

      _userId = userId;

      final hasNew = await _notificationService.hasNewNotification(userId);
      final unreadCount = await _notificationService.getUnreadCount(userId);
      final latestNotification = await _notificationService.getLatestUnreadNotification(userId);
      final notifications = await _notificationService.getNotifications(userId);

      if (mounted) {
        setState(() {
          _hasNotification = hasNew;
          _unreadCount = unreadCount;
          _latestNotification = latestNotification;
          _notifications = notifications;
          _isLoading = false;
        });
      }
      
      debugPrint('✅ Notification state updated: unreadCount=$_unreadCount');
    } catch (e) {
      debugPrint('❌ Error loading notification: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showNotificationsBox() {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy thông tin người dùng'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Thông báo${_unreadCount > 0 ? ' ($_unreadCount mới)' : ''}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Notifications List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                        ),
                      )
                    : _notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Không có thông báo nào',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notification = _notifications[index];
                              
                              // ✅ Thêm safety checks
                              final notificationType = notification.type.isEmpty ? 'he_thong' : notification.type;
                              final icon = _notificationService.getIconByType(notificationType);
                              final color = _notificationService.getColorByType(notificationType);
                              final isRead = notification.isRead;
                              
                              debugPrint('🎨 Rendering notification: type=$notificationType, title=${notification.title}');

                              return GestureDetector(
                                onTap: () async {
                                  // Đánh dấu là đã đọc
                                  if (!isRead) {
                                    await _notificationService.markAsRead(notification.id);
                                    await _loadNotification();
                                  }
                                  
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _showNotificationDetail(notification);
                                  }
                                },
                                child: Card(
                                  margin: EdgeInsets.symmetric(vertical: 8),
                                  elevation: isRead ? 0 : 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: isRead
                                        ? BorderSide.none
                                        : BorderSide(color: color, width: 1.5),
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: isRead ? Colors.grey[50] : Colors.white,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Icon
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: color.withOpacity(0.1),
                                          ),
                                          child: Center(
                                            child: Icon(icon, color: color, size: 24),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        // Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      notification.title.isEmpty ? 'Thông báo' : notification.title,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: isRead
                                                            ? FontWeight.normal
                                                            : FontWeight.bold,
                                                        color: Colors.blueGrey[800],
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (!isRead)
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: color,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              SizedBox(height: 6),
                                              Text(
                                                notification.message.isEmpty ? 'Bạn có thông báo mới' : notification.message,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.schedule,
                                                    size: 11,
                                                    color: Colors.grey[500],
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    _notificationService.formatDateTime(
                                                      notification.createdAt,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Refresh badge khi đóng box
      _loadNotification();
    });
  }

  void _showNotificationDetail(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              _notificationService.getIconByType(notification.type),
              color: _notificationService.getColorByType(notification.type),
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(child: Text(notification.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _notificationService.getColorByType(notification.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _notificationService.getColorByType(notification.type).withOpacity(0.3),
                ),
              ),
              child: Text(
                notification.message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blueGrey[800],
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Thời gian: ${_notificationService.formatDateTime(notification.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            // ✅ Sửa: Kiểm tra metadata trước
            if (notification.metadata != null) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final metadata = notification.metadata;
                  
                  // ✅ Kiểm tra null trước khi access
                  final score = metadata?['score'] ?? 0;
                  final correct = metadata?['correct_answers'] ?? 0;
                  final total = metadata?['total_questions'] ?? 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiết:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• Điểm: ${(score is num ? score : 0).toStringAsFixed(2)}/100',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Số câu đúng: $correct / $total câu',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            _hasNotification
                ? Icons.notifications_active
                : Icons.notifications_none,
            size: 28,
            color: Colors.white,
          ),
          onPressed: _showNotificationsBox,
        ),
        if (_unreadCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}