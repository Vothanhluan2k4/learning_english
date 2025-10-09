import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:learning_english/screens/setting_screen.dart';
import 'package:learning_english/screens/flashcards_screen.dart';
import 'package:learning_english/screens/course_screen.dart';
import 'package:learning_english/screens/grammar_screen.dart';
import 'package:learning_english/screens/home_screen.dart';
import 'package:learning_english/service/google_auth_service.dart';
import 'package:learning_english/service/auth_service.dart';
import 'package:learning_english/service/user_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../service/user_prefs.dart';

class DrawerScreen extends StatefulWidget {
  const DrawerScreen({super.key});

  @override
  State<DrawerScreen> createState() => _DrawerScreenState();
}

class _DrawerScreenState extends State<DrawerScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _googleAuthService = GoogleAuthService();
  int _selectedItem = 0;

  // Biến lưu thông tin user
  bool isLoggedIn = false;
  String? _fullName;
  String? _email;
  String? _avatarUrl;
  bool _isLoading = true;

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    CourseScreen(),
    GrammarScreen(),
    FlashcardsScreen(),
    SettingScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkLoginStatus();
  }

  // Hàm load dữ liệu user
  Future<void> _loadUserData() async {
    try {
      final currentUser = _authService.currentUser;

      if (currentUser != null) {
        // Lấy thông tin từ bảng users
        final userProfile = await _userService.getUserProfile(currentUser.id);

        setState(() {
          _fullName = userProfile?['full_name'] ?? 'User';
          _email = userProfile?['email'] ?? currentUser.email;
          _avatarUrl = userProfile?['avatar_url'];
          _isLoading = false;
        });
      } else {
        // Nếu không có user, chuyển về login
        Navigator.of(context).pushReplacementNamed('/signIn');
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _fullName = 'User';
        _email = 'No email';
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedItem = index;
    });
    Navigator.pop(context);
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 24),
              SizedBox(width: 12),
              Text('Đăng xuất'),
            ],
          ),
          content: Text('Bạn có chắc chắn muốn đăng xuất?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hủy', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Đăng xuất', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Learning English", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[600],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedItem),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Hiển thị loading hoặc user info
            _isLoading
                ? UserAccountsDrawerHeader(
              accountName: Text('Loading...', style: TextStyle(fontSize: 18, color: Colors.white)),
              accountEmail: null,
              currentAccountPicture: CircleAvatar(
                child: CircularProgressIndicator(color: Colors.white),
                backgroundColor: Colors.blue[300],
              ),
              decoration: BoxDecoration(color: Colors.lightBlue),
            )
                : UserAccountsDrawerHeader(
              accountName: Text(
                _fullName ?? 'User',
                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                _email ?? '',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              currentAccountPicture: _avatarUrl != null
                  ? CircleAvatar(
                backgroundImage: NetworkImage(_avatarUrl!),
                backgroundColor: Colors.white,
              )
                  : CircleAvatar(
                child: Text(
                  _fullName?.substring(0, 1).toUpperCase() ?? 'U',
                  style: TextStyle(fontSize: 32, color: Colors.blue[600], fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.white,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue[400]!, Colors.blue[600]!],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Trang chủ'),
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.laptop_chromebook_outlined),
              title: const Text('Luyện đề'),
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(FontAwesomeIcons.bookOpen),
              title: const Text('Ngữ pháp'),
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.note),
              title: const Text('FlashCards'),
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Cài đặt'),
              onTap: () => _onItemTapped(4),
            ),
            Divider(),
            //Swtich signIn and signOut
            isLoggedIn
                ? ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
              onTap: _showLogoutDialog,
            )
                : ListTile(
              leading: const Icon(Icons.login, color: Colors.green),
              title: const Text('Đăng nhập', style: TextStyle(color: Colors.green)),
              onTap: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/signIn',
                      (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}