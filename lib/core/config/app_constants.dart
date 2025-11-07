/// App-wide constants
class AppConstants {
  // App info
  static const String appName = 'Learning English';
  static const String appVersion = '1.0.0';

  // Routes
  static const String routeHome = '/';
  static const String routeLogin = '/login';
  static const String routeChooseLearning = '/chooseLearning';
  static const String routeAiPractice = '/aiPractice';
  static const String routeAiApiKeySetup = '/aiApiKeySetup';

  // Storage keys (SharedPreferences / SecureStorage)
  static const String storageKeyUserId = 'user_id';
  static const String storageKeyAuthToken = 'auth_token';
  static const String storageKeyTheme = 'theme';
  static const String storageKeyLanguage = 'language';

  // UI Constants
  static const double defaultPadding = 20.0;
  static const double defaultBorderRadius = 12.0;
  static const double defaultElevation = 4.0;

  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Colors
  static const int primaryColorValue = 0xFF2196F3;
  static const int secondaryColorValue = 0xFF9C27B0;
  static const int errorColorValue = 0xFFEF5350;
  static const int successColorValue = 0xFF4CAF50;
  static const int warningColorValue = 0xFFFF9800;

  // Error messages
  static const String errorGeneric = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
  static const String errorNetwork = 'Không có kết nối internet.';
  static const String errorTimeout = 'Kết nối quá chậm. Vui lòng thử lại.';
  static const String errorUnauthorized = 'Bạn cần đăng nhập để tiếp tục.';
  static const String errorNotFound = 'Không tìm thấy dữ liệu.';

  // Success messages
  static const String successSaved = 'Đã lưu thành công!';
  static const String successDeleted = 'Đã xóa thành công!';
  static const String successUpdated = 'Đã cập nhật thành công!';
}