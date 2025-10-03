import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // LẤY THÔNG TIN USER
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await _supabase
        .from('users')
        .select()
        .eq('auth_id', userId)
        .single();

    return response;
  }

  // CẬP NHẬT PROFILE
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    DateTime? dateOfBirth,
    String? level,
  }) async {
    final updates = <String, dynamic>{};

    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (dateOfBirth != null) updates['date_of_birth'] = dateOfBirth.toIso8601String();
    if (level != null) updates['level'] = level;

    await _supabase
        .from('users')
        .update(updates)
        .eq('auth_id', userId);
  }

  // UPLOAD AVATAR
  Future<String> uploadAvatar(File imageFile) async {
    final userId = _supabase.auth.currentUser!.id;
    final fileName = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Upload file
    await _supabase.storage
        .from('avatars')
        .upload(fileName, imageFile, fileOptions: const FileOptions(upsert: true));

    // Lấy public URL
    final avatarUrl = _supabase.storage
        .from('avatars')
        .getPublicUrl(fileName);

    // Cập nhật vào database
    await _supabase
        .from('users')
        .update({'avatar_url': avatarUrl})
        .eq('auth_id', userId);

    return avatarUrl;
  }

  // XÓA AVATAR
  Future<void> deleteAvatar(String avatarUrl) async {
    final fileName = avatarUrl.split('/avatars/').last;

    await _supabase.storage
        .from('avatars')
        .remove([fileName]);

    // Xóa URL trong database
    final userId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('users')
        .update({'avatar_url': null})
        .eq('auth_id', userId);
  }

  // CẬP NHẬT ĐIỂM & STREAK
  Future<void> updateProgress({
    required String userId,
    int? points,
    int? currentStreak,
    int? lessonsCompleted,
    int? exercisesCompleted,
    int? studyTimeMinutes,
  }) async {
    final updates = <String, dynamic>{};

    if (points != null) updates['total_points'] = points;
    if (currentStreak != null) {
      updates['current_streak'] = currentStreak;
      // Cập nhật longest_streak nếu cần
      final user = await getUserProfile(userId);
      if (user != null && currentStreak > (user['longest_streak'] ?? 0)) {
        updates['longest_streak'] = currentStreak;
      }
    }
    if (lessonsCompleted != null) updates['total_lessons_completed'] = lessonsCompleted;
    if (exercisesCompleted != null) updates['total_exercises_completed'] = exercisesCompleted;
    if (studyTimeMinutes != null) updates['total_study_time_minutes'] = studyTimeMinutes;

    await _supabase
        .from('users')
        .update(updates)
        .eq('auth_id', userId);
  }
}