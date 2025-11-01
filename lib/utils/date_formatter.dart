import 'package:intl/intl.dart';

class DateFormatter {
  // ✅ Format time ago (e.g., "5m trước", "2h trước")
  static String formatTimeAgo(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Vừa xong';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m trước';
      if (difference.inHours < 24) return '${difference.inHours}h trước';
      if (difference.inDays < 7) return '${difference.inDays} ngày trước';

      return DateFormat('dd/MM').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  // ✅ Get greeting based on time
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Chào buổi sáng';
    } else if (hour < 17) {
      return 'Chào buổi chiều';
    } else {
      return 'Chào buổi tối';
    }
  }
}