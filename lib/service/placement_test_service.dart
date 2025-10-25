import 'package:supabase_flutter/supabase_flutter.dart';

class PlacementTestService {
  final supabase = Supabase.instance.client;

  /// Kiểm tra người dùng đã làm test hay skip chưa
  Future<bool> shouldShowPlacementTest(String userId) async {
    final data = await supabase
        .from('user_placement_summary')
        .select('is_skipped, latest_result_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return true; // Chưa có record → chưa test
    final skipped = data['is_skipped'] ?? false;
    final done = data['latest_result_id'] != null;
    return !(skipped || done); // Chỉ hiển thị nếu chưa skip và chưa test
  }

  /// Ghi nhận bỏ qua test
  Future<void> skipPlacementTest(String userId) async {
    await supabase.from('user_placement_summary').upsert({
      'user_id': userId,
      'is_skipped': true,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }





}
