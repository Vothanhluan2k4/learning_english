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

      // ✅ Dùng RPC để lấy modules với lock status
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
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
            appBar: AppBar(
              title: const Text('Lỗi'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text('Lỗi: ${snapshot.error}'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dataFuture = _loadData();
                      });
                    },
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
                      Icon(
                        Icons.inbox,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: modules.length,
                  itemBuilder: (context, index) {
                    final module = modules[index];
                    return _buildModuleCard(context, module, index + 1);
                  },
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
              ? null // ✅ Disable tap nếu locked
              : () {
                  // Navigate nếu unlocked
                  Navigator.pushNamed(
                    context,
                    '/courseLessons',
                    arguments: {'moduleId': module.id},
                  );
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
                      Icon(
                        Icons.lock,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    const Spacer(),
                    // ✅ Unlock button cho module đầu tiên nếu bị khóa
                    if (isLocked && moduleNumber == 1)
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            debugPrint('🔓 Unlocking first module...');

                            // Show loading
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            await _moduleService.unlockCourseForUser(widget.courseId);

                            if (mounted) {
                              Navigator.pop(context); // Close loading

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Đã mở khóa module đầu tiên!'),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // Reload data
                              setState(() {
                                _dataFuture = _loadData();
                              });
                            }
                          } catch (e) {
                            debugPrint('❌ Error unlocking: $e');
                            if (mounted) {
                              Navigator.pop(context); // Close loading
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
                // ✅ Progress bar (chỉ hiện khi unlocked)
                if (!isLocked) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${module.completedLessonCount}/${module.lessonCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
                // ✅ Hint text cho locked modules
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