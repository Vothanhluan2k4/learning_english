import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AI Provider Configuration
class AiConfig {
  // ==================== API KEYS FROM ENV ====================
  // ⚠️ LƯU Ý: API keys được load từ file .env
  // File .env không được commit lên git để bảo mật
  static String get groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';  
  
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? ''; 
  
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

    **IMPORTANT GRADING INSTRUCTIONS:**
    1. **FOLLOW THE GUIDELINE**: If a guideline is provided above, grade the answer based on whether it meets the guideline requirements
    2. **Count words accurately**: Split by spaces only, count EXACTLY as written
    3. **Respond in VIETNAMESE**: All feedback fields must be in Vietnamese

    **Grading Criteria:**
    1. Grammar (30 points) - Ngữ pháp chính xác
    2. Content & Ideas (30 points) - Nội dung đáp ứng yêu cầu và guideline
    3. Organization & Structure (20 points) - Bố cục, mạch lạc
    4. Vocabulary (20 points) - Từ vựng phù hợp

    **Response Format (JSON only):**
    {{
      "total_score": <number 0-100>,
      "grammar_score": <number 0-30>,
      "content_score": <number 0-30>,
      "organization_score": <number 0-20>,
      "vocabulary_score": <number 0-20>,
      "word_count": <exact number of words in answer>,
      "strengths": ["<điểm mạnh bằng tiếng Việt>", "<điểm mạnh 2>"],
      "weaknesses": ["<điểm yếu bằng tiếng Việt>", "<điểm yếu 2>"],
      "suggestions": ["<gợi ý cải thiện bằng tiếng Việt>", "<gợi ý 2>"],
      "detailed_feedback": "<Nhận xét tổng quan bằng tiếng Việt, viết thành ĐOẠN VĂN liền mạch (KHÔNG dùng bullet points hay dấu gạch đầu dòng). Bao gồm: điểm mạnh, điểm yếu, và hướng cải thiện.>"
    }}

    **CRITICAL:**
    - ALL text in strengths, weaknesses, suggestions, detailed_feedback MUST be in VIETNAMESE
    - detailed_feedback must be a PARAGRAPH (not bullet points)
    - Grade based on the guideline if provided
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
