import 'package:flutter/material.dart';

/// Widget hiển thị thẻ tiến độ học tập
Widget buildProgressCard({
  required String title,
  required String value,
  required Color color,
  required IconData icon,
}) {
  return Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// Widget hiển thị thông tin người dùng (icon + text)
Widget buildInfoTile({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  bool showArrow = true,
}) {
  return ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: const Color(0xFF2196F3), size: 20),
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 16),
    ),
    trailing: showArrow ? Icon(Icons.chevron_right, color: Colors.grey[400]) : null,
    onTap: onTap,
  );
}

/// Widget hiển thị thống kê đơn giản
Widget buildStatCard({
  required String title,
  required String value,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

/// Widget hiển thị một tùy chọn trong danh sách cài đặt
Widget buildSettingTile({
  required IconData icon,
  required String title,
  Color? iconColor,
  Color? textColor,
  required VoidCallback onTap,
}) {
  return ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (iconColor ?? const Color(0xFF2196F3)).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: iconColor ?? const Color(0xFF2196F3),
        size: 20,
      ),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        color: textColor,
      ),
    ),
    trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
    onTap: onTap,
  );
}
