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