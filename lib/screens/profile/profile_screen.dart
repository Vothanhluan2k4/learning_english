import 'package:flutter/material.dart';
import 'package:learning_english/service/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:learning_english/service/google_auth_service.dart';
import 'package:learning_english/service/auth_service.dart';
import 'package:learning_english/service/user_service.dart';
import 'package:learning_english/service/user_prefs.dart';
import 'package:learning_english/widgets/profile_widet.dart';
import 'package:learning_english/screens/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  final _userService = UserService();
  final _googleAuthService = GoogleAuthService();

  // Biến lưu thông tin user
  bool isLoggedIn = false;
  String? _fullName;
  String? _email;
  String? _avatarUrl;
  bool _isLoading = true;

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isDarkMode = false; // Thêm state cho dark mode

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  Future<void> _logout() async {
    try {
      final isGoogleUser = _googleAuthService.isSignedIn && _googleAuthService.googleAccount != null;

      if(isGoogleUser){
        await _googleAuthService.signOut();
      }else{
        await _authService.signOut();
        await UserPrefs.clearUser();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Đăng xuất thành công!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.of(context).pushNamedAndRemoveUntil(
          '/signIn',
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Text('Lỗi: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  //Check login status
  Future<void> _checkLoginStatus() async {
    final user = await UserPrefs.getUser();
    setState(() {
      isLoggedIn = user['isLoggedIn'] == true; // đảm bảo boolean đúng
      _fullName = user['full_name'] ?? 'User';
      _email = user['email'] ?? 'No email';
      _avatarUrl = user['avatar_url'];
      _isLoading = false;
    });
  }

  //Change date
  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'Chưa cập nhật';
    try {
      final parsedDate = DateTime.parse(date);
      return '${parsedDate.day.toString().padLeft(2, '0')}/'
          '${parsedDate.month.toString().padLeft(2, '0')}/'
          '${parsedDate.year}';
    } catch (e) {
      return date; // fallback nếu lỗi
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase
            .from('users')
            .select()
            .eq('auth_id', user.id)
            .single();

        setState(() {
          userData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with gradient background
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2196F3),
                    Color(0xFF64B5F6),
                  ],
                ),
              ),
              child: Column(
                children: [
                  SizedBox(height: 20),

                  // Avatar + nút chỉnh sửa
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: userData?['avatar_url'] != null
                              ? NetworkImage(userData!['avatar_url'])
                              : null,
                          child: userData?['avatar_url'] == null
                              ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                              : null,
                        ),
                      ),

                      // Nút ở góc phải
                      Positioned(
                        bottom: 4,
                        right: 6,
                        child: GestureDetector(
                          onTap: () async {
                            final imageService = ProfileService();
                            final newUrl = await imageService.pickCropAndUploadImage(context);
                            if (newUrl != null) {
                              setState(() {
                                userData?['avatar_url'] = newUrl;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content:
                                Text('Cập nhật ảnh đại diện thành công!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    backgroundColor: Colors.green,
                                  ),
                                ),
                                ),
                              );
                            }
                          },

                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),


                  SizedBox(height: 16),

                  // Name
                  Text(
                    userData?['full_name'] ?? 'Người dùng',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 8),

                  // Email
                  Text(
                    userData?['email'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),

                  SizedBox(height: 30),
                ],
              ),
            ),

            // Personal Info Section
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'THÔNG TIN CÁ NHÂN',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/inforUser');
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text("Chỉnh sửa"),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ======= Các dòng thông tin =======
                  buildInfoTile(
                    icon: Icons.calendar_today,
                    title: _formatDate(userData?['date_of_birth']) ,
                    showArrow: false,
                    onTap: () {},
                  ),
                  buildInfoTile(
                    icon: Icons.phone,
                    title: userData?['phone'] ?? 'Chưa cập nhật',
                    showArrow: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // Learning Progress Section (Modern Design)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, const Color(0xFFF7F9FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TIẾN ĐỘ HỌC TẬP',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      buildProgressCard(
                        title: 'Đề đã luyện',
                        value: '3',
                        color: const Color(0xFF4CAF50),
                        icon: Icons.assignment_turned_in,
                      ),
                      buildProgressCard(
                        title: 'Từ đã học',
                        value: '40',
                        color: const Color(0xFF2196F3),
                        icon: Icons.menu_book_rounded,
                      ),
                      buildProgressCard(
                        title: 'Điểm TB',
                        value: '8.5',
                        color: const Color(0xFFFF9800),
                        icon: Icons.star_rate_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Settings Section
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'CÀI ĐẶT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  buildSettingTile(
                    icon: Icons.language,
                    title: 'Thay đổi ngôn ngữ',
                    onTap: () {
                    },
                  ),

                  _buildDarkModeToggle(),

                  buildSettingTile(
                    icon: Icons.notifications,
                    title: 'Thông báo',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Actions Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'HÀNH ĐỘNG',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                buildSettingTile(
                  icon: Icons.logout,
                  title: 'Đăng xuất',
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Row(
                            children: const [
                              Icon(Icons.logout, color: Colors.red, size: 24),
                              SizedBox(width: 12),
                              Text('Đăng xuất'),
                            ],
                          ),
                          content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Hủy', style: TextStyle(color: Colors.black)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirm == true) {
                      await _supabase.auth.signOut();
                      if (mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/signIn',
                              (route) => false,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),


          SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // Widget riêng cho Dark Mode toggle - iOS style
  Widget _buildDarkModeToggle() {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFF2196F3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: Colors.blue,
          size: 20,
        ),
      ),
      title: Text(
        'Chế độ tối',
        style: TextStyle(fontSize: 16),
      ),
      trailing: GestureDetector(
        onTap: () {
          setState(() {
            isDarkMode = !isDarkMode;
          });
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 51,
          height: 31,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.5),
            color: isDarkMode ? Colors.blue : Color(0xFFE5E5EA),
          ),
          padding: EdgeInsets.all(2),
          child: AnimatedAlign(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                size: 14,
                color: isDarkMode ? Colors.blue : Colors.grey[400],
              ),
            ),
          ),
        ),
      ),
    );
  }


}