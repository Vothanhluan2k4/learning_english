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
    // ✅ FIX: Parse score from string/int/double
    final scoreRaw = json['score'];
    double score = 0.0;
    
    if (scoreRaw is num) {
      score = scoreRaw.toDouble();
    } else if (scoreRaw is String) {
      score = double.tryParse(scoreRaw) ?? 0.0;
    }
    
    return NotificationMetadata(
      score: score,
      testId: json['test_id']?.toString() ?? '',
      attempts: _parseInt(json['attempts']),
      lessonId: json['lesson_id']?.toString() ?? '',
      testName: json['test_name']?.toString() ?? 'Unknown',
      testType: json['test_type']?.toString() ?? 'lesson',
      courseName: json['course_name']?.toString() ?? 'Unknown',
      lessonName: json['lesson_name']?.toString() ?? 'Unknown',
      moduleName: json['module_name']?.toString() ?? 'Unknown',
      passStatus: json['pass_status']?.toString() ?? 'unknown',
      targetScore: _parseDouble(json['target_score']),
      correctAnswers: _parseInt(json['correct_answers']),
      totalQuestions: _parseInt(json['total_questions']),
      targetCorrectAnswers: _parseInt(json['target_correct_answers']),
    );
  }

  // ✅ Helper: Parse int from various types
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  // ✅ Helper: Parse double from various types
  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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
    
    // 🔥 FIX: Better user data extraction
    Map<String, dynamic>? userData;
    
    // Try different possible field names
    if (json['users'] != null) {
      userData = json['users'] is List 
          ? (json['users'] as List).isNotEmpty 
              ? json['users'][0] 
              : null
          : json['users'];
    }
    
    debugPrint('👤 Extracted user data: $userData');
    
    final userName = userData?['full_name'] as String? ?? 'Unknown User';
    final userAvatar = userData?['avatar_url'] as String?;
    
    debugPrint('✅ User name: $userName');
    debugPrint('✅ User avatar: $userAvatar');
    
    return CommunityNotification(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: userName,
      userAvatar: userAvatar,
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