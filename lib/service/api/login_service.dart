import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.0.2.2:5093/api";

  // API đăng nhập
  static Future<bool> login(String username, String password) async {
    final url = Uri.parse("$baseUrl/ApiAccount/login");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": "luandangnhap@gmail.com",
          "password": password,
          "fullName": "Võ Thành Luận",
          "rememberMe": true,
          "returnUrl": "/"
        }),
      );

      if (response.statusCode == 200) {
        print(" Đăng nhập thành công: ${response.body}");
        return true;
      } else {
        print(" Lỗi đăng nhập: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print(" Lỗi kết nối API: $e");
      return false;
    }
  }
}
