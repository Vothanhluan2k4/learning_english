import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';

class NotificationService {
  final supabase = Supabase.instance.client;

  /// Lấy user_id từ bảng users dựa trên auth_id
  Future<String?> getUserIdFromAuthId(String authId) async {
    try {
      debugPrint('🔍 Querying user with authId: $authId');
      
      final data = await supabase
          .from('users')
          .select('id, auth_id, email')
          .eq('auth_id', authId)
          .maybeSingle();

      debugPrint('📦 Query result: $data');
      
      if (data == null) {
        debugPrint('❌ No user found for authId: $authId');
        return null;
      }
      
      final userId = data['id'] as String;
      debugPrint('✅ Found userId: $userId');
      return userId;
    } catch (e) {
      debugPrint('❌ Error getting user id: $e');
      return null;
    }
  }

  /// Lấy danh sách tất cả thông báo từ bảng notifications
  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      debugPrint('🎯 Fetching all notifications for userId: $userId');
      
      final data = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      debugPrint('📋 Raw notifications data: $data');
      debugPrint('📋 Notifications count: ${data.length}');
      
      final notifications = (data as List)
          .map((e) {
            debugPrint('🔍 Processing notification: $e');
            return NotificationModel.fromJson(e as Map<String, dynamic>);
          })
          .toList();
      
      debugPrint('✅ Parsed ${notifications.length} notifications');
      return notifications;
    } catch (e) {
      debugPrint('❌ Error getting notifications: $e');
      return [];
    }
  }

  /// Lấy số lượng thông báo chưa đọc
  Future<int> getUnreadCount(String userId) async {
    try {
      debugPrint('🔔 Counting unread notifications for userId: $userId');
      
      final data = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      // ✅ Sửa: Sử dụng length thay vì count
      final count = (data as List).length;
      debugPrint('✅ Unread count: $count');
      return count;
    } catch (e) {
      debugPrint('❌ Error counting unread: $e');
      return 0;
    }
  }

  /// Lấy thông báo chưa đọc mới nhất
  Future<NotificationModel?> getLatestUnreadNotification(String userId) async {
    try {
      debugPrint('🎯 Fetching latest unread notification for userId: $userId');
      
      final data = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false)
          .maybeSingle();

      debugPrint('📋 Latest notification data: $data');
      
      if (data == null) {
        debugPrint('❌ No unread notification found');
        return null;
      }
      
      debugPrint('✅ Latest notification found');
      return NotificationModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ Error getting latest notification: $e');
      return null;
    }
  }

  /// Kiểm tra có thông báo chưa đọc không
  Future<bool> hasNewNotification(String userId) async {
    try {
      debugPrint('🔔 Checking unread notification for userId: $userId');
      
      final data = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      // ✅ Sửa: Sử dụng length thay vì count
      final count = (data as List).length;
      debugPrint('✅ Has unread: $count > 0');
      
      return count > 0;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  /// Đánh dấu thông báo là đã đọc
  Future<bool> markAsRead(String notificationId) async {
    try {
      debugPrint('📝 Marking notification as read: $notificationId');
      
      await supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      debugPrint('✅ Marked as read');
      return true;
    } catch (e) {
      debugPrint('❌ Error marking as read: $e');
      return false;
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  Future<bool> markAllAsRead(String userId) async {
    try {
      debugPrint('📝 Marking all notifications as read for userId: $userId');
      
      await supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);

      debugPrint('✅ Marked all as read');
      return true;
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
      return false;
    }
  }

  /// Xóa thông báo
  Future<bool> deleteNotification(String notificationId) async {
    try {
      debugPrint('🗑️ Deleting notification: $notificationId');
      
      await supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      debugPrint('✅ Deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting: $e');
      return false;
    }
  }

  /// Lấy icon theo type
  IconData getIconByType(String type) {
    switch (type) {
      case 'nhac_hoc':
        return Icons.notifications_active;
      case 'tien_do':
        return Icons.trending_up;
      case 'huy_hieu':
        return Icons.emoji_events;
      case 'bai_hoc_moi':
        return Icons.school;
      case 'goi_y':
        return Icons.lightbulb;
      case 'su_kien':
        return Icons.event;
      case 'he_thong':
        return Icons.info;
      case 'uu_dai':
        return Icons.local_offer;
      case 'ket_qua_test':
        return Icons.assessment;
      case 'cong_dong':
        return Icons.people;
      case 'tai_khoan':
        return Icons.account_circle;
      case 'truyen_cam_hung':
        return Icons.favorite;
      default:
        return Icons.notifications;
    }
  }

  /// Lấy màu theo type
  Color getColorByType(String type) {
    switch (type) {
      case 'nhac_hoc':
        return Colors.orange;
      case 'tien_do':
        return Colors.green;
      case 'huy_hieu':
        return Colors.purple;
      case 'bai_hoc_moi':
        return Colors.blue;
      case 'goi_y':
        return Colors.amber;
      case 'su_kien':
        return Colors.red;
      case 'he_thong':
        return Colors.grey;
      case 'uu_dai':
        return Colors.pink;
      case 'ket_qua_test':
        return Colors.indigo;
      case 'cong_dong':
        return Colors.teal;
      case 'tai_khoan':
        return Colors.cyan;
      case 'truyen_cam_hung':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  /// Định dạng thời gian
  String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Không có thông tin';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}