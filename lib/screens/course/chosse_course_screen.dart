import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/placement_test_args.dart'; // 👈 import model

class ChoosePathScreen extends StatefulWidget {
  const ChoosePathScreen({super.key});

  @override
  State<ChoosePathScreen> createState() => _ChoosePathScreenState();
}

class _ChoosePathScreenState extends State<ChoosePathScreen> {
  bool _isProcessing = false;

  Future<void> _onSelectPath(BuildContext context, String pathType) async {
    final supabase = Supabase.instance.client;
    final courseMap = {
      'basic': 'uuid-course-basic',
      'exam': 'uuid-course-toeic',
    };
    final courseId = courseMap[pathType];

    if (courseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lộ trình không hợp lệ.')),
      );
      return;
    }

    final test = await supabase
        .from('tests')
        .select('id')
        .eq('test_type', 'placement')
        .eq('course_id', courseId)
        .maybeSingle();

    final testId = test?['id'] as String?;

    if (testId != null) {
      final args = PlacementTestArgs(testId: testId,);
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/placementTest',
          arguments: args.toMap(),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy bài test đầu vào.')),
      );
    }
  }

  Future<void> _onSkipTest(BuildContext context) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập lại.')),
      );
      return;
    }

    try {
      // Kiểm tra xem user_id đã tồn tại trong bảng users chưa
      final existingUser = await supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existingUser == null) {
        // Tạo bản ghi mặc định trong bảng users nếu chưa có
        await supabase.from('users').insert({
          'id': user.id,
          'email': user.email ?? '',
        });
      }

      // Thêm bản ghi vào user_placement_summary
      await supabase.from('user_placement_summary').upsert({
        'user_id': user.id,
        'placement_test_id': null,
        'latest_result_id': null,
        'score': null,
        'level': null,
        'recommended_course_id': null,
        'is_skipped': true,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/homedrawer', (route) => false);
      }
    } catch (e) {
      print('Error skipping test: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể bỏ qua test: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn Lộ Trình Học'),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : () => _onSkipTest(context),
            child: const Text(
              'Bỏ qua',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Hãy chọn lộ trình học phù hợp với bạn để thực hiện bài kiểm tra đầu vào:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.school),
              label: const Text('Lộ trình Cơ bản'),
              onPressed: () => _onSelectPath(context, 'basic'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.book_online),
              label: const Text('Luyện thi TOEIC / IELTS'),
              onPressed: () => _onSelectPath(context, 'exam'),
            ),
          ],
        ),
      ),
    );
  }
}