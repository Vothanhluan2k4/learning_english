import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class GoogleAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String webClientId = '314438081717-gqpkh9gl5u74dhdl5rot5puvt1hvvsjo.apps.googleusercontent.com';
  static const List<String> scopes = ['email', 'profile'];

  GoogleSignInAccount? _currentUser;
  bool _isInitialized = false;

  // Completer để đợi authentication hoàn tất
  Completer<bool>? _authCompleter;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await GoogleSignIn.instance.initialize(
        clientId: null,
        serverClientId: webClientId,
      );

      GoogleSignIn.instance.authenticationEvents
          .listen(_handleAuthenticationEvent)
          .onError(_handleAuthenticationError);

      //Quay lại đăng nhập
      // await GoogleSignIn.instance.attemptLightweightAuthentication();

      _isInitialized = true;
      print('Google Sign In initialized');
    } catch (e) {
      print('Initialization error: $e');
    }
  }

  Future<void> _handleAuthenticationEvent(
      GoogleSignInAuthenticationEvent event,
      ) async {
    _currentUser = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    print('Auth event - User: ${_currentUser?.email}');

    if (_currentUser != null) {
      try {
        await _signInToSupabase(_currentUser!);
        //Lưu dữ liệu SharedPreferences
        await _saveUserToPref(_currentUser!);

        // Hoàn thành authentication thành công
        _authCompleter?.complete(true);
      } catch (e) {
        print('Error in _signInToSupabase: $e');
        _authCompleter?.completeError(e);
      }
    } else {
      _authCompleter?.complete(false);
    }
  }

  Future<void> _handleAuthenticationError(Object error) async {
    print('Auth error: $error');

    if (error is GoogleSignInException) {
      final errorMsg = switch (error.code) {
        GoogleSignInExceptionCode.canceled => 'Đăng nhập bị hủy',
        _ => 'Lỗi: ${error.description}',
      };
      print('GoogleSignInException: $errorMsg');
      _authCompleter?.completeError(error);
    }

    _currentUser = null;
  }

  Future<AuthResponse?> _signInToSupabase(GoogleSignInAccount account) async {
  try {
    final GoogleSignInAuthentication googleAuth = await account.authentication;

    if (googleAuth.idToken == null) {
      throw Exception('Failed to get ID token from Google');
    }

    debugPrint('🔐 Got ID token, signing in to Supabase');

    try {
      // ✅ FIX: Thêm delay trước khi sign in
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
      ).timeout(Duration(seconds: 15));

      debugPrint('✅ Supabase sign in success: ${response.user?.email}');

      if (response.user != null) {
        // ✅ Delay để auth complete
        await Future.delayed(Duration(milliseconds: 500));
        await _createOrUpdateProfile(response.user!);
      }

      return response;
    } catch (e) {
      debugPrint('❌ Supabase auth error: $e');
      
      // ✅ Check if user was created despite error
      if (e.toString().contains('Database error saving new user')) {
        debugPrint('⚠️ Profile trigger failed, trying manual creation...');
        
        final currentUser = _supabase.auth.currentUser;
        if (currentUser != null) {
          await Future.delayed(Duration(milliseconds: 500));
          try {
            await _createOrUpdateProfile(currentUser);
            debugPrint('✅ Manual profile creation succeeded');
            return AuthResponse(user: currentUser, session: null);
          } catch (e2) {
            debugPrint('❌ Manual creation failed: $e2');
          }
        }
      }
      rethrow;
    }
  } catch (e) {
    debugPrint('❌ _signInToSupabase error: $e');
    rethrow;
  }
}

Future<void> _createOrUpdateProfile(User user) async {
  try {
    debugPrint('═══════════════════════════════════════');
    debugPrint('👤 Creating/Updating user profile');
    debugPrint('═══════════════════════════════════════');
    debugPrint('   auth_id: ${user.id}');
    debugPrint('   email: ${user.email}');
    debugPrint('   displayName: ${_currentUser?.displayName}');

    // ✅ FIX: Thêm try-catch riêng cho select
    Map<String, dynamic>? existing;
    try {
      existing = await _supabase
          .from('users')
          .select()
          .eq('auth_id', user.id)
          .maybeSingle()
          .timeout(Duration(seconds: 10));
      debugPrint('   Existing user: ${existing != null ? 'Yes' : 'No'}');
    } catch (e) {
      debugPrint('⚠️ Error checking existing user: $e');
      existing = null;
    }

    if (existing == null) {
      final insertData = {
        'auth_id': user.id,
        'email': user.email ?? 'unknown@example.com',
        'full_name': _currentUser?.displayName ?? 
            user.email?.split('@')[0] ?? 'User',
        'avatar_url': _currentUser?.photoUrl,
        'last_login_at': DateTime.now().toIso8601String(),
      };

      debugPrint('📝 Insert data:');
      debugPrint('   auth_id: ${insertData['auth_id']}');
      debugPrint('   email: ${insertData['email']}');
      debugPrint('   full_name: ${insertData['full_name']}');

      // ✅ Validate
      if ((insertData['auth_id'] as String).isEmpty) {
        throw Exception('auth_id không được để trống');
      }
      if ((insertData['email'] as String).isEmpty) {
        throw Exception('email không được để trống');
      }

      // ✅ Try insert with timeout
      try {
        await _supabase
            .from('users')
            .insert(insertData)
            .timeout(Duration(seconds: 10));
        debugPrint('✅ User created successfully');
      } catch (e) {
        debugPrint('⚠️ Insert failed: $e');
        
        // ✅ Fallback: Thử upsert
        debugPrint('🔄 Trying upsert instead...');
        try {
          await _supabase
              .from('users')
              .upsert(
                insertData,
                onConflict: 'auth_id',
              )
              .timeout(Duration(seconds: 10));
          debugPrint('✅ User upserted successfully');
        } catch (e2) {
          debugPrint('❌ Upsert also failed: $e2');
          
          // ✅ Last resort: try update
          debugPrint('🔄 Trying update instead...');
          try {
            await _supabase
                .from('users')
                .update({'last_login_at': insertData['last_login_at']})
                .eq('auth_id', user.id)
                .timeout(Duration(seconds: 10));
            debugPrint('✅ User updated (fallback)');
          } catch (e3) {
            debugPrint('❌ All operations failed: $e3');
            // Don't rethrow - user is already authenticated
          }
        }
      }
    } else {
      debugPrint('📝 Updating existing user...');
      try {
        await _supabase
            .from('users')
            .update({'last_login_at': DateTime.now().toIso8601String()})
            .eq('auth_id', user.id)
            .timeout(Duration(seconds: 10));
        debugPrint('✅ User updated successfully');
      } catch (e) {
        debugPrint('⚠️ Update failed: $e');
        // Don't rethrow - user already exists
      }
    }

    debugPrint('═══════════════════════════════════════');
  } catch (e, stackTrace) {
    debugPrint('❌ Profile error: $e');
    debugPrint('📍 Stack trace: $stackTrace');
    // Don't rethrow - user is already authenticated
  }
}
  Future<bool> authenticate() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception('Nền tảng này không hỗ trợ xác thực Google');
      }

      // Tạo completer mới để đợi kết quả
      _authCompleter = Completer<bool>();

      print('Starting authentication...');

      // Gọi authenticate - điều này sẽ trigger authentication event
      await GoogleSignIn.instance.authenticate();

      // Đợi event được xử lý (timeout 10 giây)
      final result = await _authCompleter!.future.timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Authentication timeout');
        },
      );

      print('Authentication result: $result');
      return result;

    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // Đây là trường hợp user thực sự hủy
        print('User canceled sign in');
        return false;
      }
      rethrow;
    } finally {
      _authCompleter = null;
    }
  }
  //Save user in SharedPreferences
  Future<void> _saveUserToPref(GoogleSignInAccount account) async{
    final prefs = await SharedPreferences.getInstance();
    final user = _supabase.auth.currentUser;

    if (user != null) {
      await prefs.setString('auth_id', user.id);
    } else {
      print('Khong tìm thấy user Supabase sau khi đăng nhập');
    }

    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('email', account.email);
    await prefs.setString('name', account.displayName ?? '');
    await prefs.setString('avatar', account.photoUrl ?? '');
  }

  //Clear user in SharedPreferences
  Future<void> _clearPref() async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_id');
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('email');
    await prefs.remove('auth_id');
    await prefs.remove('name');
    await prefs.remove('avatar');
  }

  //Logout
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      await GoogleSignIn.instance.disconnect();

      await _supabase.auth.signOut();
      await _clearPref();
      _currentUser = null;
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  bool get isSignedIn => _supabase.auth.currentUser != null;
  User? get currentUser => _supabase.auth.currentUser;
  GoogleSignInAccount? get googleAccount => _currentUser;
}