import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserPref();

    // Sau 3 giây chuyển hướng
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/homedrawer');
    });
  }

  Future<void> _loadUserPref() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('full_name');
    final googleName = prefs.getString('name');

    setState(() {
      _userName = fullName ?? googleName ?? 'User';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// Ảnh nền
          Image.asset(
            'assets/welcome_User.png',
            fit: BoxFit.cover,
          ),

          /// Lớp phủ làm mờ nhẹ (nếu muốn)
          Container(
            color: Colors.white.withOpacity(0.05),
          ),

          /// Nội dung trung tâm
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Text(
                'Xin chào',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black
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
          ),
        ],
      ),
    );
  }
}
