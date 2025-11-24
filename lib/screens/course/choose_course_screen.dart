import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/placement_test_service.dart';

class ChooseCourseScreen extends StatefulWidget {
  const ChooseCourseScreen({super.key});

  @override
  State<ChooseCourseScreen> createState() => _ChooseCourseScreenState();
}

class _ChooseCourseScreenState extends State<ChooseCourseScreen> {
  final supabase = Supabase.instance.client;
  PlacementTestService placementTestService = PlacementTestService();
  bool _isLoading = false;

  List<Map<String, dynamic>> _courseGroups = [];
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _fetchCourseGroups();
  }

  Future<void> _fetchCourseGroups() async {
    final response = await supabase.from('course_groups').select('id, group_name, description');
    setState(() {
      _courseGroups = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _skipTest() async {
    final authUserId = Supabase.instance.client.auth.currentUser!.id;
    await placementTestService.skipPlacementTest(authUserId);
    Navigator.pushNamed(context, '/homedrawer');
  }

  Future<void> _startTest() async {
    if (_selectedGroupId == null) return;

    setState(() => _isLoading = true);

    try {
      final testResponse = await supabase
          .from('tests')
          .select('id, test_name')
          .eq('test_type', 'placement')
          .eq('course_group_id', _selectedGroupId as String)
          .maybeSingle();

      if (testResponse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có bài kiểm tra cho nhóm này. Vui lòng chọn nhóm khác.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final String testId = testResponse['id'] as String;

      debugPrint('Bắt đầu bài test: $testId'); // Debug

      Navigator.pushNamed(
        context,
        '/placementTest',
        arguments: {'testId': testId},
      );
    } catch (e) {
      debugPrint('Lỗi: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Chọn lộ trình học của bạn', 
        style: TextStyle(color: Colors.white),),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                  'Chào mừng bạn đến với lộ trình học tiếng Anh ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 60),

                // 🔹 Dropdown chọn nhóm khóa học
                if (_courseGroups.isNotEmpty)
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelText: 'Chọn nhóm khóa học',
                    ),
                    value: _selectedGroupId,
                    items: _courseGroups.map((group) {
                      return DropdownMenuItem<String>(
                        value: group['id'],
                        child: Text(group['group_name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGroupId = value;
                      });
                    },
                  )
                else
                  const Center(child: CircularProgressIndicator()),

                const SizedBox(height: 40),

                // 🔹 Nút bắt đầu test (chỉ hiện khi đã chọn nhóm)
                if (_selectedGroupId != null)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _startTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent, 
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    label: const Text(
                      'Bắt đầu bài kiểm tra đầu vào',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),

                const SizedBox(height: 15),

                TextButton(
                  onPressed: _isLoading ? null : _skipTest,
                  child: const Text(
                    'Bỏ qua, tôi sẽ tự khám phá sau',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
