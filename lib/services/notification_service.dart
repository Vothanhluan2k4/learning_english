import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/notification.dart';

class NotificationService {
  final SupabaseClient supabase;

  NotificationService({required this.supabase});

  /// Get user info
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

  /// ✅ FIXED: Get ALL community notifications - Filter in Dart, not SQL
  Future<List<CommunityNotification>> getAllCommunityNotifications() async {
    try {
      debugPrint('📡 Loading ALL community notifications...');
      
      // ✅ Get ALL ket_qua_test notifications without score filter
      final response = await supabase
          .from('notifications')
          .select('''
            id,
            user_id,
            title,
            message,
            metadata,
            created_at,
            users!notifications_user_id_fkey (
              id,
              full_name,
              avatar_url,
              email
            )
          ''')
          .eq('type', 'ket_qua_test')
          .order('created_at', ascending: false);

      debugPrint('✅ Found ${(response as List).length} raw notifications');

      // ✅ Filter in Dart to handle numeric comparison correctly
      final validNotifications = <CommunityNotification>[];
      
      for (var json in response as List) {
        try {
          final metadata = json['metadata'] as Map<String, dynamic>?;
          
          if (metadata == null) {
            debugPrint('⚠️ Skipping notification with null metadata: ${json['id']}');
            continue;
          }

          // ✅ Parse test_type
          final testType = metadata['test_type']?.toString() ?? '';
          
          // ✅ Parse score (handle string "100.0", int 100, double 100.0)
          final scoreRaw = metadata['score'];
          double? score;
          
          if (scoreRaw is num) {
            score = scoreRaw.toDouble();
          } else if (scoreRaw is String) {
            score = double.tryParse(scoreRaw);
          }

          final id = (json['id'] as String).substring(0, 8);
          debugPrint('🔍 [$id] test_type=$testType, score=$score (raw: $scoreRaw)');

          // ✅ Filter: test_type == 'final_test' AND score >= 70
          if (testType == 'final_test' && score != null && score >= 70.0) {
            final notification = CommunityNotification.fromJson(json);
            validNotifications.add(notification);
            debugPrint('   ✅ INCLUDED - ${notification.userName}: $score%');
          } else {
            debugPrint('   ❌ FILTERED OUT');
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing notification: $e');
        }
      }

      debugPrint('✅ Filtered to ${validNotifications.length} valid notifications');

      // ✅ Sort by score (highest first), then by created_at
      validNotifications.sort((a, b) {
        final scoreCompare = b.metadata.score.compareTo(a.metadata.score);
        if (scoreCompare != 0) return scoreCompare;
        return b.createdAt.compareTo(a.createdAt);
      });

      return validNotifications;

    } catch (e, stackTrace) {
      debugPrint('❌ Error getting all community notifications: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// ✅ FIXED: Get community notifications - Top N
  Future<List<CommunityNotification>> getCommunityNotifications({
    int limit = 10,
  }) async {
    try {
      debugPrint('📡 Loading top $limit community notifications...');
      
      final allNotifications = await getAllCommunityNotifications();
      
      return allNotifications.take(limit).toList();

    } catch (e, stackTrace) {
      debugPrint('❌ Error getting community notifications: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get unread count
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

  /// Mark notification as read
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

  /// Mark all notifications as read
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