import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../service/course_service.dart';
import '../../../service/placement_test_service.dart';
import '../../../models/course_group.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final courseService = CourseService();
  final placementService = PlacementTestService();
  bool _isLoading = true;
  bool _showPlacement = false;
  List<CourseGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final shouldShowTest = await placementService.shouldShowPlacementTest(userId);
    final groups = await courseService.fetchCourseGroups();

    setState(() {
      _showPlacement = shouldShowTest;
      _groups = groups;
      _isLoading = false;
    });

    if (_showPlacement) {
      _showPlacementDialog();
    }
  }

  void _showPlacementDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('Bài kiểm tra đầu vào'),
        content: Text('Bạn cần làm bài kiểm tra đầu vào để xác định lộ trình học.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/placementTest');
            },
            child: Text('Làm bài test'),
          ),
          TextButton(
            onPressed: () async {
              final userId = Supabase.instance.client.auth.currentUser!.id;
              await placementService.skipPlacementTest(userId);
              Navigator.pop(context);
              setState(() => _showPlacement = false);
            },
            child: Text('Bỏ qua'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    final visibleGroups = _showPlacement
        ? _groups.where((g) => g.groupName.toLowerCase().contains('test')).toList()
        : _groups.where((g) => !g.groupName.toLowerCase().contains('test')).toList();

    return Scaffold(
      appBar: AppBar(
          title: Text('Lộ trình học'),
        centerTitle: true ,
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: visibleGroups.length,
        itemBuilder: (context, index) {
          final group = visibleGroups[index];
          return ListTile(
            title: Text(group.groupName),
            subtitle: Text(group.description ?? ''),
            onTap: () {},
          );
        },
      ),
    );
  }
}
