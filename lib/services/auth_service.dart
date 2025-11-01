import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService{
  final SupabaseClient  _supabase = Supabase.instance.client;

  //Get current user
  User? get currentUser => _supabase.auth.currentUser;

  //Track login status
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Lấy user_id từ auth_id
  Future<String?> getUserIdFromAuthId(String authId) async {
    try {

      final response = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', authId)
          .single();

      final userId = response['id'] as String?;
      return userId;
    } catch (e) {
      return null;
    }
  }

  //SignUp
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
    String? phone,
    String? date_of_birth,
  }) async {
    User? createdUser;

    try {
      // Kiểm tra email trong Auth trước
      try {
        final existingAuthUser = await _supabase.auth.admin.listUsers();
        // Note: admin API không available ở client, nên bỏ qua
      } catch (e) {
        // Ignore, sẽ check bằng cách khác
      }

      // Kiểm tra email trong bảng users
      final existingEmail = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (existingEmail != null) {
        throw Exception('Email đã được sử dụng, vui lòng nhập email khác!');
      }

      //Kiểm tra phone trong bảng users
      if (phone != null && phone.isNotEmpty) {
        final existingPhone = await _supabase
            .from('users')
            .select()
            .eq('phone', phone)
            .maybeSingle();

        if (existingPhone != null) {
          throw Exception('Số điện thoại đã được sử dụng!');
        }
      }

      // Tạo Auth user
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'date_of_birth': date_of_birth,
        },
      );

      if (response.user == null) {
        throw Exception('Không thể tạo tài khoản');
      }

      createdUser = response.user;

      // Insert vào bảng users (QUAN TRỌNG)
      try {
        await _supabase.from('users').insert({
          'auth_id': response.user!.id,
          'email': email,
          'full_name': fullName,
          'phone': phone,
          'date_of_birth': date_of_birth,
        });
      } catch (insertError) {
        // NẾU INSERT THẤT BẠI → XÓA USER KHỎI AUTH
        print('Insert failed, deleting auth user...');

        try {
          // Xóa user vừa tạo trong Auth
          await _supabase.auth.admin.deleteUser(response.user!.id);
        } catch (deleteError) {
          print(' Could not delete auth user: $deleteError');
          // Fallback: Sign out user
          await _supabase.auth.signOut();
        }

        // Throw lỗi chi tiết
        if (insertError.toString().contains('duplicate key')) {
          if (insertError.toString().contains('email')) {
            throw Exception('Email đã được sử dụng!');
          } else if (insertError.toString().contains('phone')) {
            throw Exception('Số điện thoại đã được sử dụng!');
          }
        }
        throw Exception('Lỗi tạo tài khoản: $insertError');
      }

      return response;

    } on AuthException catch (e) {
      // Xử lý lỗi Auth
      if (e.message.contains('already registered') ||
          e.message.contains('User already registered')) {
        throw Exception('Email đã được đăng ký!');
      }
      throw Exception('Lỗi đăng ký: ${e.message}');
    } catch (e) {
      // Nếu có lỗi và đã tạo user, xóa user đó
      if (createdUser != null) {
        try {
          await _supabase.auth.signOut();
        } catch (_) {}
      }
      rethrow;
    }
  }

  //Get user
  Future<Map<String, dynamic>> getUserData(String authId) async {
    final response = await _supabase
        .from('users')
        .select()
        .eq('auth_id', authId)
        .maybeSingle();

    if (response == null) throw Exception('Không tìm thấy thông tin người dùng');
    return Map<String, dynamic>.from(response);
  }


  //signIn
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  })async{
    final response = await _supabase.auth.signInWithPassword(
      email: email, 
      password: password
    );
    
    // Update last_time_login
    if(response.user != null){
      await _supabase
          .from('users')
          .update({'last_login_at': DateTime.now().toIso8601String()})
          .eq('auth_id', response.user!.id);
    }
    return response;
  }

  //SignOut
  Future<void> signOut() async{
    await _supabase.auth.signOut();
  }


  //Check Login Expiry
  Future<bool> checkLoginExpiry() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) return false;

      // Lấy thông tin last_login_at từ bảng users
      final response = await _supabase
          .from('users')
          .select('last_login_at')
          .eq('auth_id', user.id)
          .single();

      if (response['last_login_at'] != null) {
        final lastLogin = DateTime.parse(response['last_login_at']);
        final now = DateTime.now();
        final difference = now.difference(lastLogin);

        // Nếu quá 7 ngày thì đăng xuất
        if (difference.inDays > 7) {
          await _supabase.auth.signOut();
          return true; // Đã logout
        }
      }

      return false; // Chưa hết hạn
    } catch (e) {
      print('Error checking login expiry: $e');
      return false;
    }
  }
}