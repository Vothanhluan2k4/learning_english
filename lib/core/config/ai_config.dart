/// AI Provider Configuration
class AiConfig {
  // ==================== FREE API KEYS ====================
  // ⚠️ LƯU Ý: Đây là free tier API, giới hạn 3 lần/ngày cho mỗi user
  // Production app nên dùng server-side proxy để bảo vệ API key
  static const String groqApiKey = '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';  
  
  // ✅ ADD: Gemini API key (Get from https://makersuite.google.com/app/apikey)
  static const String geminiApiKey = 'AIzaSyB6Pu9kqSZJhPDHBjYhPL3dN93DRzd8OFQ'; 
  
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
  static const String geminiDefaultModel = 'gemini-2.5-flash';

  static const List<String> geminiAvailableModels = [
    'gemini-2.5-flash',
    'gemini-1.5-flash',    
    'gemini-1.5-pro',      
    'gemini-2.0-flash-exp',
];



  static const int geminiMaxTokensPerMinute = 32000;
  static const int geminiMaxRequestsPerMinute = 15;

  // ==================== GENERAL ====================
  static const int defaultQuestionCount = 5;
  static const int maxQuestionCount = 20;
  static const int minQuestionCount = 1;

  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 2000;

  // ==================== USAGE LIMITS ====================
  static const int freeDailyUsageLimit = 3; 
  
  // ✅ NEW: Unlimited types
  static const List<String> unlimitedRequestTypes = [
    'writing_grading',
    'speaking_grading',
  ];

  static bool isUnlimitedType(String requestType) {
    return unlimitedRequestTypes.contains(requestType);
  }

  static String getUsageDescription(String requestType) {
    switch (requestType) {
      case 'practice_questions':
        return 'Giới hạn $freeDailyUsageLimit câu hỏi/ngày';
      case 'writing_grading':
        return 'Không giới hạn số lần chấm bài';
      case 'speaking_grading':
        return 'Không giới hạn số lần chấm nói';
      default:
        return 'Không rõ giới hạn';
    }
  }

  static const Duration apiTimeout = Duration(seconds: 30);

  static const String encryptionKey = "12345678901234567890123456789012";

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

  // ==================== WRITING GRADING ====================
  static const String writingGradingPromptTemplate = '''
You are an English writing teacher. Grade the following student essay.

**Topic/Question:**
{question}

**Student's Answer:**
{answer}

**Requirements:**
- Minimum words: {min_words}
- Maximum words: {max_words}
{guideline}

**Grading Criteria:**
1. Grammar & Vocabulary (30 points)
2. Content & Ideas (30 points)
3. Organization & Structure (20 points)
4. Task Achievement (20 points)

**Response Format (JSON only):**
{{
  "total_score": <number 0-100>,
  "grammar_score": <number 0-30>,
  "content_score": <number 0-30>,
  "organization_score": <number 0-20>,
  "task_score": <number 0-20>,
  "word_count": <number>,
  "strengths": ["strength 1", "strength 2"],
  "weaknesses": ["weakness 1", "weakness 2"],
  "suggestions": ["suggestion 1", "suggestion 2"],
  "detailed_feedback": "<detailed feedback in Vietnamese>"
}}
''';

  // ✅ NEW: Get API key for provider
  static String getApiKey(String provider) {
    switch (provider.toLowerCase()) {
      case 'groq':
        return groqApiKey;
      case 'gemini':
        return geminiApiKey;
      default:
        throw UnsupportedError('Provider $provider không được hỗ trợ');
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