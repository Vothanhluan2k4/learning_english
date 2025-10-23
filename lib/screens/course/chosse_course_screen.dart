import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../service/placement_test_service.dart';

class ChooseCourseScreen extends StatefulWidget {
  const ChooseCourseScreen({super.key});

  @override
  State<ChooseCourseScreen> createState() => _ChooseCourseScreenState();
}

class _ChooseCourseScreenState extends State<ChooseCourseScreen> {
  final supabase = Supabase.instance.client;
  PlacementTestService placementTestService = PlacementTestService();
  bool _isLoading = false;


  Future<void> _skipTest() async{
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await placementTestService.skipPlacementTest(userId);

    Navigator.pushNamed(context, '/homedrawer');
  }
  // 🔹 Hàm bắt đầu test
  Future<void> _startTest() async {
    // TODO: Chuyển sang trang làm test (bạn sẽ tạo sau)
    Navigator.pushNamed(context, '/placementTest');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Chọn lộ trình học của bạn'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Chào mừng bạn đến với lộ trình học tiếng Anh 🎯',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Để giúp chúng tôi xác định trình độ và lộ trình học phù hợp, '
                      'bạn có thể làm bài kiểm tra đầu vào hoặc bỏ qua nếu muốn tự khám phá.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 50),

                // 🔹 Nút bắt đầu test
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _startTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  label: const Text(
                    'Bắt đầu bài kiểm tra đầu vào',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),

                // 🔹 Nút bỏ qua test
                TextButton(
                  onPressed: _isLoading ? null : _skipTest,
                  child: const Text(
                    'Bỏ qua, tôi sẽ tự khám phá sau',
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
