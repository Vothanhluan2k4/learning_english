import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/screens/profile/edit_user_infor_screen.dart';
import 'package:learning_english/service/auth_service.dart';
import 'package:learning_english/service/user_service.dart';
import 'package:learning_english/service/user_prefs.dart';
import 'package:url_launcher/url_launcher.dart';

class InforUserScreen extends StatefulWidget {
  const InforUserScreen({super.key});

  @override
  State<InforUserScreen> createState() => _InforUserScreenState();
}

class _InforUserScreenState extends State<InforUserScreen> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  final _userService = UserService();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('users')
          .select()
          .eq('auth_id', userId)
          .single();

      setState(() {
        _userData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải thông tin: $e')),
        );
      }
    }
  }
  // Navigate to edit screen
  Future<void> _navigateToEdit(String fieldName, String currentValue) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditUserInfoScreen(
          fieldName: fieldName,
          currentValue: currentValue,
          userId: userId,
        ),
      ),
    );

    // Reload data if changes were saved
    if (result == true) {
      await _loadUserData();
      _hasChanges = true; //  Đánh dấu có thay đổi
    }
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

  Future<void> _changePassword() async {
    // Điều hướng đến màn hình đổi mật khẩu hoặc hiển thị dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thay đổi mật khẩu'),
        content: const Text('Chức năng đang được phát triển'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return  WillPopScope(
        onWillPop: () async {
          // Trả về true để báo hiệu có thay đổi
          Navigator.pop(context, true);
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: Colors.blue,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                // Trả về true khi nhấn nút back
                Navigator.pop(context, true);
              },
            ),
        title: const Text(
          'Thông tin cá nhân',
          style: TextStyle(color: Colors.white, fontSize: 18,fontWeight: FontWeight.w600,),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            // Header với thông báo liên hệ email
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: GestureDetector(
                onTap: () {
                  // Mở ứng dụng email khi nhấn vào
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'luandangnhap@gmail.com',
                  );
                  launchUrl(emailLaunchUri); // Sử dụng package url_launcher để mở email
                },
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Liên hệ ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: 'luandangnhap@gmail.com',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red, // Màu đỏ cho email
                          decoration: TextDecoration.underline, // Thêm gạch chân để trông như link
                        ),
                      ),
                      TextSpan(
                        text: ' nếu cần hỗ trợ.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Họ và tên
            _buildInfoCard(
              label: 'Họ và tên',
              value: _userData?['full_name'] ?? '',
              hasArrow: true,
              onTap: () {
                _navigateToEdit(
                  'full_name',
                  _userData?['full_name'] ?? '',
                );
              },
            ),

            // DateofBirth
            _buildInfoCard(
              label: 'Ngày sinh',
              value: _formatDate(_userData?['date_of_birth']) ?? '',
              hasArrow: true,
              onTap: () {
                _navigateToEdit(
                  'date_of_birth',
                  _userData?['date_of_birth'] ?? '',
                );
              },
            ),

            // Số điện thoại
            _buildInfoCard(
              label: 'Số điện thoại',
              value: _userData?['phone'] ?? '',
              hasArrow: true,
              onTap: () {
                _navigateToEdit(
                  'phone',
                  _userData?['phone'] ?? '',
                );
              },
            ),

            // Email
            _buildInfoCard(
              label: 'Email',
              value: _userData?['email'] ?? '',
              hasArrow: false,

            ),

            const SizedBox(height: 20),

            // Nút Thay đổi mật khẩu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9FE8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Thay đổi mật khẩu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
        ),
    );
  }


  Widget _buildInfoCard({
    required String label,
    required String value,
    required bool hasArrow,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasArrow ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value.isEmpty ? '-' : value,
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF0D9FE8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasArrow)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

