import 'package:flutter/material.dart';
import '../../models/course.dart';
import '../../models/course_module.dart';
import '../../services/course_service.dart';
import '../../services/course_module_service.dart';

class CourseModulesScreen extends StatefulWidget {
  final String courseId;

  const CourseModulesScreen({
    required this.courseId,
    super.key,
  });

  @override
  State<CourseModulesScreen> createState() => _CourseModulesScreenState();
}

class _CourseModulesScreenState extends State<CourseModulesScreen> {
  final _moduleService = CourseModuleService();
  final _courseService = CourseService();

  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 CourseModulesScreen init with courseId: ${widget.courseId}');
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    try {
      debugPrint('🔍 Loading data for course: ${widget.courseId}');

      final course = await _courseService.getCourseById(widget.courseId);
      debugPrint('🔍 Course loaded: ${course?.courseName}');

      final modules = await _moduleService.fetchModulesByCourse(widget.courseId);
      debugPrint('🔍 Modules loaded: ${modules.length}');

      return {
        'course': course,
        'modules': modules,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading data: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // 🔥 NEW: Reload data method
  Future<void> _reloadData() async {
    debugPrint('🔄 Reloading course modules data...');
    setState(() {
      _dataFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            appBar: AppBar(
              title: const Text('Đang tải...'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            appBar: AppBar(
              title: const Text('Lỗi'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Lỗi: ${snapshot.error}'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _reloadData,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data;
        final course = data?['course'] as Course?;
        final modules = (data?['modules'] as List<CourseModule>?) ?? [];

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          appBar: AppBar(
            title: Text(course?.courseName ?? 'Lộ trình học'),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            
          ),
          body: modules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Không có module nào',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  // 🔥 NEW: Pull-to-refresh
                  onRefresh: _reloadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: modules.length,
                    itemBuilder: (context, index) {
                      final module = modules[index];
                      return _buildModuleCard(context, module, index + 1);
                    },
                  ),
                ),
        );
      },
    );
  }

  Widget _buildModuleCard(
    BuildContext context,
    CourseModule module,
    int moduleNumber,
  ) {
    final isLocked = module.isLocked;
    final progress = module.lessonCount > 0
        ? (module.completedLessonCount / module.lessonCount)
        : 0.0;

    return Opacity(
      opacity: isLocked ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: InkWell(
          onTap: isLocked
              ? null
              : () async {
                  // 🔥 UPDATED: Await result and reload if needed
                  final result = await Navigator.pushNamed(
                    context,
                    '/courseLessons',
                    arguments: {'moduleId': module.id},
                  );

                  // 🔥 NEW: Reload data when returning
                  if (mounted) {
                    debugPrint('🔄 Returned from lessons, reloading modules...');
                    await _reloadData();
                  }
                },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isLocked
                            ? Colors.grey.shade200
                            : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Module $moduleNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isLocked
                              ? Colors.grey.shade600
                              : Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLocked)
                      Icon(Icons.lock, size: 16, color: Colors.grey.shade400),
                    const Spacer(),
                    if (isLocked && moduleNumber == 1)
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            debugPrint('🔓 Unlocking first module...');

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            await _moduleService.unlockCourseForUser(widget.courseId);

                            if (mounted) {
                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Đã mở khóa module đầu tiên!'),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // 🔥 UPDATED: Use reload method
                              await _reloadData();
                            }
                          } catch (e) {
                            debugPrint('❌ Error unlocking: $e');
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ Lỗi: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.lock_open, size: 16),
                        label: const Text('Mở khóa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      )
                    else if (!isLocked)
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  module.moduleName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isLocked ? Colors.grey.shade600 : Colors.black,
                  ),
                ),
                if (module.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    module.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // ✅ Progress bar (updated with animation)
                if (!isLocked) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: TweenAnimationBuilder<double>(
                            // 🔥 NEW: Animated progress bar
                            tween: Tween(begin: 0.0, end: progress),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  value >= 1.0
                                      ? Colors.green.shade600
                                      : Colors.blue.shade600,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: progress >= 1.0
                              ? Colors.green.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: progress >= 1.0
                                ? Colors.green.shade200
                                : Colors.blue.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (progress >= 1.0)
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.green.shade700,
                              )
                            else
                              Icon(
                                Icons.timer,
                                size: 14,
                                color: Colors.blue.shade700,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              '${module.completedLessonCount}/${module.lessonCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: progress >= 1.0
                                    ? Colors.green.shade700
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (isLocked && moduleNumber > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Hoàn thành module trước để mở khóa',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}