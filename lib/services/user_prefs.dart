import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  static Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('auth_id', userData['auth_id'] ?? '');
    await prefs.setString('email', userData['email'] ?? '');
    await prefs.setString('full_name', userData['full_name'] ?? '');
    await prefs.setString('avatar_url', userData['avatar_url'] ?? '');
    await prefs.setString('phone', userData['phone'] ?? '');
    await prefs.setString('date_of_birth', userData['date_of_birth'] ?? '');
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('auth_id');
    await prefs.remove('email');
    await prefs.remove('full_name',);
    await prefs.remove('avatar_url');
    await prefs.remove('phone');
    await prefs.remove('date_of_birth');
  }

  static Future<Map<String, dynamic>> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isLoggedIn': prefs.getBool('isLoggedIn') ?? false,
      'auth_id': prefs.getString('auth_id'),
      'email': prefs.getString('email'),
      'full_name': prefs.getString('full_name'),
      'avatar_url': prefs.getString('avatar_url'),
      'phone': prefs.getString('phone'),
      'date_of_birth': prefs.getString('date_of_birth'),
    };
  }
}
