import 'package:flutter/material.dart';
import 'package:learning_english/services/auth/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:learning_english/services/auth/google_auth_service.dart';
import 'package:learning_english/services/auth/auth_service.dart';
import 'package:learning_english/services/auth/user_service.dart';
import 'package:learning_english/services/user_prefs.dart';
import 'package:learning_english/widgets/profile_widet.dart';
import 'package:learning_english/screens/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_english/helpers/notification_helper.dart';

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
  
  final _notificationHelper = NotificationHelper();
  
  // Biến lưu thông tin user
  bool isLoggedIn = false;
  String? _fullName;
  String? _email;
  String? _avatarUrl;
  bool _isLoading = true;

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isDarkMode = false; // Thêm state cho dark mode

  bool _notificationEnabled = false;
  int _notificationHour = 9;
  int _notificationMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNotificationSettings(); // ✅ Add this
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

  // ✅ Load notification settings
  Future<void> _loadNotificationSettings() async {
    final savedTime = await _notificationHelper.getSavedTime();
    setState(() {
      _notificationEnabled = savedTime['enabled'];
      _notificationHour = savedTime['hour'];
      _notificationMinute = savedTime['minute'];
    });
  }

  // ✅ Show time picker dialog
  Future<void> _showNotificationDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int tempHour = _notificationHour;
        int tempMinute = _notificationMinute;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: const [
                  Icon(Icons.notifications_active, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('Cài đặt thông báo'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Chọn giờ nhận thông báo học tiếng Anh hàng ngày',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  
                  // Time Picker
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hour
                        _buildTimePicker(
                          value: tempHour,
                          max: 23,
                          onChanged: (val) => setState(() => tempHour = val),
                        ),
                        const Text(' : ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                        // Minute
                        _buildTimePicker(
                          value: tempMinute,
                          max: 59,
                          onChanged: (val) => setState(() => tempMinute = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _notificationHelper.scheduleDailyNotification(
                      hour: tempHour,
                      minute: tempMinute,
                    );

                    this.setState(() {
                      _notificationHour = tempHour;
                      _notificationMinute = tempMinute;
                      _notificationEnabled = true;
                    });

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '⏰ Đã đặt thông báo lúc ${tempHour.toString().padLeft(2, '0')}:${tempMinute.toString().padLeft(2, '0')}',
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Lưu', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ Time picker widget
  Widget _buildTimePicker({
    required int value,
    required int max,
    required Function(int) onChanged,
  }) {
    return Container(
      width: 80,
      height: 100,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 40,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        controller: FixedExtentScrollController(initialItem: value),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            return Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: index == value ? FontWeight.bold : FontWeight.normal,
                  color: index == value ? Colors.blue : Colors.grey,
                ),
              ),
            );
          },
          childCount: max + 1,
        ),
      ),
    );
  }

  // ✅ Update notification tile
  Widget _buildNotificationTile() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.notifications, color: Colors.blue, size: 20),
      ),
      title: const Text('Thông báo', style: TextStyle(fontSize: 16)),
      subtitle: _notificationEnabled
          ? Text(
              'Hàng ngày lúc ${_notificationHour.toString().padLeft(2, '0')}:${_notificationMinute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
          : const Text('Tắt', style: TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Switch(
        value: _notificationEnabled,
        onChanged: (value) async {
          if (value) {
            _showNotificationDialog(); // ✅ Show dialog when turn on
          } else {
            await _notificationHelper.toggleNotification(false);
            setState(() => _notificationEnabled = false);
          }
        },
        activeColor: Colors.blue,
      ),
    );
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
                              blurRadius: 15,
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
                                SnackBar(
                                  content: const Text(
                                    'Cập nhật ảnh đại diện thành công!',
                                    style: TextStyle(
                                      color: Colors.white, // ✅ Chỉ set màu chữ
                                    ),
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  margin: const EdgeInsets.all(16),
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
                          onPressed: () async {
                            // Chờ kết quả từ InforUserScreen
                            final result = await Navigator.pushNamed(context, '/inforUser');

                            // Nếu có thay đổi, reload lại data
                            if (result == true) {
                              await _loadUserData();
                            }
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

                  // buildSettingTile(
                  //   icon: Icons.language,
                  //   title: 'Thay đổi ngôn ngữ',
                  //   onTap: () {
                  //   },
                  // ),

                  // _buildDarkModeToggle(),

                  _buildNotificationTile(),
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