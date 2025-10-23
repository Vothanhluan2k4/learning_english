import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../service/placement_test_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _userName = 'User';
  final PlacementTestService _placementService = PlacementTestService();

  @override
  void initState() {
    super.initState();
    _loadUserPref();
    _handleRedirect();
  }

  Future<void> _loadUserPref() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('full_name');
    final googleName = prefs.getString('name');
    setState(() {
      _userName = fullName ?? googleName ?? 'User';
    });
  }

  Future<void> _handleRedirect() async {
    await Future.delayed(const Duration(seconds: 3)); // Hiển thị màn hình welcome 3s

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('auth_id');

      if (userId == null) {
        Navigator.pushReplacementNamed(context, '/signIn');
        return;
      }

      // Sử dụng service để kiểm tra có cần làm bài test không
      final shouldShowTest = await _placementService.shouldShowPlacementTest(userId);

      print('🧭 User ID: $userId, cần làm test đầu tiên: $shouldShowTest');

      if (shouldShowTest) {
        Navigator.pushReplacementNamed(context, '/chooseCourse');
      } else {
        Navigator.pushReplacementNamed(context, '/homedrawer');
      }
    } catch (e) {
      print('⚠️ Lỗi khi kiểm tra placement test: $e');
      // fallback: về home nếu lỗi mạng
      Navigator.pushReplacementNamed(context, '/homedrawer');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/welcome_User.png', fit: BoxFit.cover),
          Container(color: Colors.white.withOpacity(0.05)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Xin chào',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              const SizedBox(height: 5),
              Text(
                _userName,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              const SizedBox(height: 10),
              const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
            ],
          ),
        ],
      ),
    );
  }
}
