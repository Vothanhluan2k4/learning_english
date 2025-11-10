/// AI Provider Configuration
class AiConfig {
  // ==================== FREE API KEYS (cho app) ====================
  // ⚠️ LƯU Ý: Đây là free tier API, giới hạn 3 lần/ngày cho mỗi user
  // Production app nên dùng server-side proxy để bảo vệ API key
  static const String groqApiKey = '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'; // TODO: Replace với key thật
  
  // ==================== GROQ ====================
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String groqDefaultModel = 'llama-3.3-70b-versatile';
  
  static const List<String> groqAvailableModels = [
    'llama-3.3-70b-versatile',
    'llama-3.1-70b-versatile',
    'mixtral-8x7b-32768',
    'gemma2-9b-it',
  ];

  static const int groqMaxTokensPerMinute = 30000;
  static const int groqMaxRequestsPerMinute = 30;

  // ==================== GEMINI ====================
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const String geminiDefaultModel = 'gemini-1.5-flash';
  
  static const List<String> geminiAvailableModels = [
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-pro',
  ];

  static const int geminiMaxTokensPerMinute = 32000;
  static const int geminiMaxRequestsPerMinute = 15;

  // ==================== GENERAL ====================
  static const int defaultQuestionCount = 5;
  static const int maxQuestionCount = 10;
  static const int minQuestionCount = 1;

  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 2000;

  static const int freeDailyUsageLimit = 3;
  static const Duration apiTimeout = Duration(seconds: 30);

  static const String encryptionKey = "learning-english-2025-app-key!!!";

  // ==================== HELPERS ====================
  
  static String getEndpoint(String provider, {String? apiKey}) {
    switch (provider.toLowerCase()) {
      case 'groq':
        return groqBaseUrl;
      case 'gemini':
        return '$geminiBaseUrl/$geminiDefaultModel:generateContent?key=$apiKey';
      default:
        throw UnsupportedError('Provider $provider không được hỗ trợ');
    }
  }

  static String getDefaultModel(String provider) {
    switch (provider.toLowerCase()) {
      case 'groq':
        return groqDefaultModel;
      case 'gemini':
        return geminiDefaultModel;
      default:
        return '';
    }
  }

  static List<String> getAvailableModels(String provider) {
    switch (provider.toLowerCase()) {
      case 'groq':
        return groqAvailableModels;
      case 'gemini':
        return geminiAvailableModels;
      default:
        return [];
    }
  }

  static bool isProviderSupported(String provider) {
    return ['groq', 'gemini'].contains(provider.toLowerCase());
  }

  static bool validateApiKeyFormat(String provider, String apiKey) {
    switch (provider.toLowerCase()) {
      case 'groq':
        return apiKey.startsWith('gsk_') && apiKey.length > 20;
      case 'gemini':
        return apiKey.startsWith('AIza') && apiKey.length > 20;
      default:
        return false;
    }
  }

  static Map<String, dynamic> getProviderInfo(String provider) {
    switch (provider.toLowerCase()) {
      case 'groq':
        return {
          'name': 'Groq',
          'icon': 'flash_on',
          'color': 0xFFFF6B6B,
          'description': 'Siêu nhanh với Llama 3.3',
          'free_tier': 'Miễn phí 30 requests/phút',
          'get_key_url': 'https://console.groq.com/keys',
          'docs_url': 'https://console.groq.com/docs',
        };
      case 'gemini':
        return {
          'name': 'Google Gemini',
          'icon': 'auto_awesome',
          'color': 0xFF4285F4,
          'description': 'AI mạnh mẽ từ Google',
          'free_tier': 'Miễn phí 15 requests/phút',
          'get_key_url': 'https://makersuite.google.com/app/apikey',
          'docs_url': 'https://ai.google.dev/docs',
        };
      default:
        return {};
    }
  }
}

enum AiProvider {
  groq,
  gemini;

  String get value => name.toLowerCase();

  static AiProvider fromString(String provider) {
    switch (provider.toLowerCase()) {
      case 'groq':
        return AiProvider.groq;
      case 'gemini':
        return AiProvider.gemini;
      default:
        throw ArgumentError('Unknown provider: $provider');
    }
  }
}