import '../config/ai_config.dart';

/// Validators for user input
class Validators {
  /// Validate API key format
  static String? validateApiKey(String? value, String provider) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập API key';
    }

    if (!AiConfig.validateApiKeyFormat(provider, value)) {
      final info = AiConfig.getProviderInfo(provider);
      return 'API key không hợp lệ cho ${info['name']}';
    }

    return null;
  }

  /// Validate email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập email';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email không hợp lệ';
    }

    return null;
  }

  /// Validate question count
  static String? validateQuestionCount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập số lượng câu hỏi';
    }

    final count = int.tryParse(value);
    if (count == null) {
      return 'Phải là số nguyên';
    }

    if (count < AiConfig.minQuestionCount || count > AiConfig.maxQuestionCount) {
      return 'Từ ${AiConfig.minQuestionCount} đến ${AiConfig.maxQuestionCount} câu';
    }

    return null;
  }

  /// Validate not empty
  static String? validateNotEmpty(String? value, {String fieldName = 'Trường này'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName không được để trống';
    }
    return null;
  }

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }

    if (value.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự';
    }

    return null;
  }
}