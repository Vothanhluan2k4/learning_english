import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.metadata,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // ✅ Thêm debug để xem dữ liệu
    debugPrint('📦 Parsing notification JSON: $json');
    
    final type = json['type'] as String? ?? 'he_thong'; // ✅ Default type
    
    return NotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Thông báo',
      message: json['message'] as String? ?? '',
      type: type,
      relatedId: json['related_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      readAt: json['read_at'] != null 
          ? DateTime.parse(json['read_at'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'NotificationModel(id: $id, title: $title, type: $type, isRead: $isRead)';
}

// ✅ NOTIFICATION METADATA
class NotificationMetadata {
  final double score;
  final String testId;
  final int attempts;
  final String lessonId;
  final String testName;
  final String testType;
  final String courseName;
  final String lessonName;
  final String moduleName;
  final String passStatus;
  final double targetScore;
  final int correctAnswers;
  final int totalQuestions;
  final int targetCorrectAnswers;

  NotificationMetadata({
    required this.score,
    required this.testId,
    required this.attempts,
    required this.lessonId,
    required this.testName,
    required this.testType,
    required this.courseName,
    required this.lessonName,
    required this.moduleName,
    required this.passStatus,
    required this.targetScore,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.targetCorrectAnswers,
  });

  factory NotificationMetadata.fromJson(Map<String, dynamic> json) {
    return NotificationMetadata(
      score: (json['score'] as num?)?.toDouble() ?? 0,
      testId: json['test_id'] ?? '',
      attempts: json['attempts'] ?? 0,
      lessonId: json['lesson_id'] ?? '',
      testName: json['test_name'] ?? 'Unknown',
      testType: json['test_type'] ?? 'lesson',
      courseName: json['course_name'] ?? 'Unknown',
      lessonName: json['lesson_name'] ?? 'Unknown',
      moduleName: json['module_name'] ?? 'Unknown',
      passStatus: json['pass_status'] ?? 'unknown',
      targetScore: (json['target_score'] as num?)?.toDouble() ?? 0,
      correctAnswers: json['correct_answers'] ?? 0,
      totalQuestions: json['total_questions'] ?? 0,
      targetCorrectAnswers: json['target_correct_answers'] ?? 0,
    );
  }

  bool get isPassed => passStatus == 'passed';
}

// ✅ NOTIFICATION
class Notification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final NotificationMetadata? metadata;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.metadata,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      message: json['message'],
      type: json['type'],
      relatedId: json['related_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      metadata: json['metadata'] != null
          ? NotificationMetadata.fromJson(json['metadata'])
          : null,
    );
  }
}

// ✅ COMMUNITY NOTIFICATION
class CommunityNotification {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String title;
  final String message;
  final DateTime createdAt;
  final NotificationMetadata metadata;

  CommunityNotification({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.metadata,
  });

  factory CommunityNotification.fromJson(Map<String, dynamic> json) {
    debugPrint('🔍 Parsing community notification: $json');
    
    // ✅ Handle multiple possible user field names
    final userData = json['users'] ?? 
                     json['users!notifications_user_id_fkey'] ??
                     json['users!fk_user_id'];
    
    debugPrint('👤 User data: $userData');
    
    return CommunityNotification(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: userData?['full_name'] ?? 'Unknown User',
      userAvatar: userData?['avatar_url'],
      title: json['title'] ?? 'No title',
      message: json['message'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      metadata: json['metadata'] != null
          ? NotificationMetadata.fromJson(json['metadata'])
          : NotificationMetadata(
              score: 0,
              testId: '',
              attempts: 0,
              lessonId: '',
              testName: '',
              testType: '',
              courseName: '',
              lessonName: '',
              moduleName: '',
              passStatus: 'unknown',
              targetScore: 0,
              correctAnswers: 0,
              totalQuestions: 0,
              targetCorrectAnswers: 0,
            ),
    );
  }
}

// ✅ USER INFO
class UserInfo {
  final String id;
  final String authId;
  final String fullName;
  final String? avatarUrl;
  final String email;

  UserInfo({
    required this.id,
    required this.authId,
    required this.fullName,
    this.avatarUrl,
    required this.email,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'],
      authId: json['auth_id'],
      fullName: json['full_name'] ?? 'User',
      avatarUrl: json['avatar_url'],
      email: json['email'] ?? '',
    );
  }
}