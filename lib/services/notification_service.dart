import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/notification.dart';

class NotificationService {
  final SupabaseClient supabase;

  NotificationService({required this.supabase});

  // ✅ Get user info
  Future<UserInfo?> getUserInfo(String userId) async {
    try {
      debugPrint('🔍 Getting user info for auth_id: $userId');
      
      final response = await supabase
          .from('users')
          .select()
          .eq('auth_id', userId)
          .maybeSingle();

      if (response != null) {
        debugPrint('✅ User found: ${response['full_name']}');
        return UserInfo.fromJson(response);
      }
      debugPrint('⚠️ User not found in database');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user info: $e');
      return null;
    }
  }


  // ✅ Get community notifications (FINAL TEST ONLY)
  Future<List<CommunityNotification>> getCommunityNotifications({
    int limit = 10,
  }) async {
    try {
      debugPrint('📡 Loading community notifications (final tests only, score > 70)...');

      final response = await supabase
          .from('notifications')
          .select(
            '''
            id,
            user_id,
            title,
            message,
            metadata,
            created_at,
            users!notifications_user_id_fkey(full_name, avatar_url)
            '''
          )
          .eq('type', 'ket_qua_test')
          .eq('metadata->>test_type', 'final_test') // ✅ FILTER: chỉ final_test
          .gte('metadata->score', 70)
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint('✅ Found ${response.length} community final test notifications');

      return (response as List)
          .map((n) => CommunityNotification.fromJson(n))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting community notifications: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  // ✅ Get ALL community notifications (FINAL TEST ONLY)
  Future<List<CommunityNotification>> getAllCommunityNotifications() async {
    try {
      debugPrint('📡 Loading ALL community final test notifications...');
      
      final response = await supabase
          .from('notifications')
          .select(
            '''
            id,
            user_id,
            title,
            message,
            metadata,
            created_at,
            users!notifications_user_id_fkey(full_name, avatar_url)
            '''
          )
          .eq('type', 'ket_qua_test')
          .eq('metadata->>test_type', 'final_test') // ✅ FILTER: chỉ final_test
          .gte('metadata->score', 70)
          .order('created_at', ascending: false);

      debugPrint('✅ Found ${response.length} total final test notifications');

      return (response as List)
          .map((n) => CommunityNotification.fromJson(n))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting all community notifications: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  // ✅ Get unread count
  Future<int> getUnreadCount(String currentUserId) async {
    try {
      final userInfo = await getUserInfo(currentUserId);
      if (userInfo == null) return 0;

      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userInfo.id)
          .eq('is_read', false);

      debugPrint('📊 Unread count: ${response.length}');
      return (response as List).length;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // ✅ Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      debugPrint('✅ Notification marked as read');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  // ✅ Mark all notifications as read
  Future<void> markAllAsRead(String currentUserId) async {
    try {
      final userInfo = await getUserInfo(currentUserId);
      if (userInfo == null) return;

      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userInfo.id)
          .eq('is_read', false);

      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }
  
}