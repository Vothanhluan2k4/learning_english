import 'package:flutter/material.dart';
import '../../models/course.dart';

class CourseCardWidget extends StatelessWidget {
  final Course course;
  final bool isRecommended;
  final bool isUnlocked;
  final String prerequisiteName;
  final VoidCallback onTap;

  const CourseCardWidget({
    required this.course,
    required this.isRecommended,
    required this.isUnlocked,
    required this.prerequisiteName,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isRecommended
            ? const BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      elevation: isRecommended ? 4 : 2,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          course.courseName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            // ✅ Màu xám nếu bị khóa
                            color: isUnlocked ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                      if (isRecommended)
                        Chip(
                          label: const Text('Đề xuất'),
                          backgroundColor: Colors.blue[50],
                          labelStyle: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ✅ Hiển thị trạng thái khóa
                  if (!isUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            size: 14,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hoàn thành "$prerequisiteName" để mở khóa',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ✅ Icon khóa
          if (!isUnlocked)
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.shade400,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}