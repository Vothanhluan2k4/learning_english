import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:learning_english/screens/profile/profile_screen.dart';
import 'package:learning_english/screens/setting_screen.dart';
import 'package:learning_english/screens/flashcards_screen.dart';
import 'package:learning_english/screens/course/course_screen.dart';
import 'package:learning_english/screens/grammar_screen.dart';
import 'package:learning_english/screens/home_screen.dart';
import 'package:learning_english/services/google_auth_service.dart';
import 'package:learning_english/services/auth_service.dart';
import 'package:learning_english/services/user_service.dart';
import 'package:learning_english/widgets/notification_bell.dart';
import '../services/user_prefs.dart';

class DrawerScreen extends StatefulWidget {
  final int? initialIndex;
  const DrawerScreen({super.key, this.initialIndex});

  @override
  State<DrawerScreen> createState() => _DrawerScreenState();
}

class _DrawerScreenState extends State<DrawerScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _googleAuthService = GoogleAuthService();
  int _selectedItem = 0;

  bool isLoggedIn = false;
  String? _fullName;
  String? _email;
  String? _avatarUrl;
  bool _isLoading = true;
  String? _userId;

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    CourseScreen(),
    GrammarScreen(),
    FlashcardsScreen(),
    ProfileScreen(),
    SettingScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initialIndex ?? 0;
    _loadUserData();
    _checkLoginStatus();
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = _authService.currentUser;

      if (currentUser != null) {
        _userId = currentUser.id;
        final userProfile = await _userService.getUserProfile(currentUser.id);

        setState(() {
          _fullName = userProfile?['full_name'] ?? 'User';
          _email = userProfile?['email'] ?? currentUser.email;
          _avatarUrl = userProfile?['avatar_url'];
          _isLoading = false;
        });
      } else {
        Navigator.of(context).pushReplacementNamed('/signIn');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
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
      final isGoogleUser = _googleAuthService.isSignedIn && 
          _googleAuthService.googleAccount != null;

      if (isGoogleUser) {
        await _googleAuthService.signOut();
      } else {
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

  Future<void> _checkLoginStatus() async {
    final user = await UserPrefs.getUser();
    setState(() {
      isLoggedIn = user['isLoggedIn'] == true;
      _fullName = user['full_name'] ?? 'User';
      _email = user['email'] ?? 'No email';
      _avatarUrl = user['avatar_url'];
      _isLoading = false;
    });
  }

  String _getTitleForScreen(int index) {
    switch (index) {
      case 0:
        return 'Trang chủ';
      case 1:
        return 'Luyện đề';
      case 2:
        return 'Ngữ pháp';
      case 3:
        return 'FashCard';
      case 4:
        return 'Hồ sơ cá nhân';
      case 5:
        return 'Setting';
      default:
        return 'Learning English';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getTitleForScreen(_selectedItem),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[600],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
        // Truyền authId thay vì userId
        if (_userId != null)
          NotificationBell(authId: _userId!),
      ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedItem),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _isLoading
                ? UserAccountsDrawerHeader(
                    accountName: Text('Loading...',
                        style: TextStyle(fontSize: 18, color: Colors.white)),
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
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
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
                              _fullName?.substring(0, 1).toUpperCase() ?? 'Name',
                              style: TextStyle(
                                  fontSize: 32,
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.bold),
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
              leading: const Icon(FontAwesomeIcons.userCircle),
              title: const Text('Hồ sơ cá nhân'),
              onTap: () => _onItemTapped(4),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Cài đặt'),
              onTap: () => _onItemTapped(5),
            ),
            Divider(),
            isLoggedIn
                ? ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Đăng xuất',
                        style: TextStyle(color: Colors.red)),
                    onTap: _showLogoutDialog,
                  )
                : ListTile(
                    leading: const Icon(Icons.login, color: Colors.green),
                    title: const Text('Đăng nhập',
                        style: TextStyle(color: Colors.green)),
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