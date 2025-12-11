import 'package:flutter/material.dart';
import '../../models/lesson_course.dart';
import '../../services/course/lesson_course_service.dart';

class LessonCardWidget extends StatelessWidget {
  final LessonCourse lesson;
  final VoidCallback onTap;
  final _lessonService = LessonCourseService();

  LessonCardWidget({
    required this.lesson,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: lesson.isLocked ? Colors.grey.shade300 : Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ✅ Icon lesson type
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lesson.isLocked
                      ? Colors.grey.shade200
                      : Colors.blue.shade100,
                ),
                child: Icon(
                  _lessonService.getLessonIcon(lesson.lessonType),
                  color: lesson.isLocked
                      ? Colors.grey.shade400
                      : Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // ✅ Lesson info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.lessonName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: lesson.isLocked
                            ? Colors.grey.shade500
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _lessonService.getLessonTypeName(lesson.lessonType),
                          style: TextStyle(
                            fontSize: 12,
                            color: lesson.isLocked
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                        if (lesson.targetScore > 0) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Yêu cầu: ${lesson.targetScore.toStringAsFixed(0)} điểm',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ✅ Lock icon or arrow
              Icon(
                lesson.isLocked ? Icons.lock : Icons.arrow_forward_ios,
                size: 16,
                color: lesson.isLocked
                    ? Colors.red.shade400
                    : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}