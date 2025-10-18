import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _supabase = Supabase.instance.client;
  String _userName = 'User';
  bool _isLoading = true;
  bool _shouldShowTestPrompt = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserPref();
    await _checkPlacementTestStatus();
  }

  Future<void> _loadUserPref() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('full_name');
    final googleName = prefs.getString('name');

    setState(() {
      _userName = fullName ?? googleName ?? 'User';
    });
  }

  Future<void> _checkPlacementTestStatus() async {
    try {
      final authId = _supabase.auth.currentUser?.id;
      if (authId == null) {
        _navigateToHome();
        return;
      }

      final response = await _supabase
          .from('user_placement_summary')
          .select('id')
          .eq('auth_id', authId)
          .maybeSingle();

      if (response == null) {
        // chưa có record => hiện màn test
        setState(() {
          _shouldShowTestPrompt = true;
          _isLoading = false;
        });
      } else {
        final isSkipped = response['is_skipped'] as bool? ?? false;
        final score = response['score'];
        final level = response['level'];

        if (isSkipped || (score != null && level != null)) {
          _navigateToHome();
        } else {
          setState(() {
            _shouldShowTestPrompt = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error checking placement test: $e');
      _navigateToHome();
    }
  }


  void _navigateToHome() {
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/homedrawer');
      }
    });
  }

  Future<void> _skipTest() async {
    try {
      final authId = _supabase.auth.currentUser?.id;
      if (authId == null) return;

      final userRecord = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', authId)
          .maybeSingle();

      final userId = userRecord?['id'];

      await _supabase.from('user_placement_summary').upsert({
        'user_id': userId,
        'is_skipped': true,
        'updated_at': DateTime.now().toIso8601String(),
      });


      if (mounted) {
        Navigator.pushReplacementNamed(context, '/homedrawer');
      }
    } catch (e) {
      print('Error skipping test: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }



  void _startTest() {
    // TODO: Navigate to Placement Test Screen
    Navigator.pushReplacementNamed(context, '/placementTest');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/welcome_User.png',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.white.withOpacity(0.05),
          ),

          // Content
          if (_isLoading)
            _buildLoadingState()
          else if (_shouldShowTestPrompt)
            _buildTestPrompt()
          else
            _buildLoadingState(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Xin chào',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _userName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      ],
    );
  }

  Widget _buildTestPrompt() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.assessment_outlined,
                size: 64,
                color: Color(0xFF6C63FF),
              ),
            ),

            const SizedBox(height: 32),

            // Title
            const Text(
              'Kiểm tra trình độ',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              'Làm bài test ngắn để chúng tôi đề xuất khóa học phù hợp với bạn',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // Button Làm bài test
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Làm bài test ngay',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Button Bỏ qua
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _skipTest,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: const BorderSide(
                    color: Color(0xFF6C63FF),
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Bỏ qua, khám phá app',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Note
            Text(
              'Bạn có thể làm test sau trong phần "Lộ trình học"',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}