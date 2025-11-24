import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config/ai_config.dart';
import '../../models/ai_question.dart';

class AiQuestionGeneratorService {
  /// Generate questions using AI
  Future<List<AiQuestion>> generateQuestions({
    required String provider,
    required String apiKey,
    required String topic,
    required int questionCount,
  }) async {
    try {
      print('🤖 Generating $questionCount questions for topic: $topic using $provider');

      final response = await _callAiApi(
        provider: provider,
        apiKey: apiKey,
        topic: topic,
        questionCount: questionCount,
      );

      print('✅ AI Response received');

      final questions = _parseResponse(response, provider);
      
      if (questions.isEmpty) {
        throw AiException('Không thể tạo câu hỏi. Vui lòng thử lại.');
      }

      print('✅ Parsed ${questions.length} questions');
      return questions;
    } catch (e) {
      print('❌ Error generating questions: $e');
      rethrow;
    }
  }

  Future<String> _callAiApi({
    required String provider,
    required String apiKey,
    required String topic,
    required int questionCount,
  }) async {
    final prompt = _buildPrompt(topic, questionCount);
    
    switch (provider.toLowerCase()) {
      case 'groq':
        return await _callGroqApi(apiKey, prompt);
      case 'gemini':
        return await _callGeminiApi(apiKey, prompt);
      default:
        throw AiException('Provider không được hỗ trợ: $provider');
    }
  }

  String _buildPrompt(String topic, int questionCount) {
    return '''
Tạo $questionCount câu hỏi trắc nghiệm về chủ đề: "$topic"

YÊU CẦU QUAN TRỌNG:
1. Mỗi câu hỏi phải có ĐÚNG 4 đáp án
2. correct_answer PHẢI LÀ MỘT TRONG 4 đáp án trong options
3. KHÔNG ĐƯỢC tạo correct_answer khác với các đáp án trong options
4. Độ khó: vừa phải, phù hợp học viên trung cấp
5. Đa dạng dạng bài: điền từ, chọn thì, ngữ pháp, từ vựng

ĐỊNH DẠNG JSON (BẮT BUỘC):
[
  {
    "id": "q1",
    "question": "Câu hỏi ở đây",
    "options": ["đáp án A", "đáp án B", "đáp án C", "đáp án D"],
    "correct_answer": "phải giống CHÍNH XÁC một trong 4 đáp án trên",
    "explanation": "Giải thích ngắn gọn"
  }
]

VÍ DỤ ĐÚNG:
{
  "question": "She ___ to school yesterday.",
  "options": ["go", "goes", "went", "going"],
  "correct_answer": "went",
  "explanation": "Past Simple cho hành động đã xảy ra"
}

VÍ DỤ SAI (TUYỆT ĐỐI TRÁNH):
{
  "question": "By the time I arrived, they ___ their homework.",
  "options": ["finish", "finished", "finishing", "finishes"],
  "correct_answer": "had finished", ❌ SAI: không có trong options!
}

Chỉ trả về JSON array, không thêm text nào khác.
''';
  }

  Future<String> _callGroqApi(String apiKey, String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse(AiConfig.groqBaseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': AiConfig.groqDefaultModel,
              'messages': [
                {
                  'role': 'system',
                  'content': 'You are an English teaching assistant. '
                      'Generate multiple choice questions in JSON format. '
                      'IMPORTANT: correct_answer MUST be exactly one of the options.',
                },
                {
                  'role': 'user',
                  'content': prompt,
                },
              ],
              'temperature': 0.7,
              'max_tokens': 2000,
            }),
          )
          .timeout(AiConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim();
      } else {
        throw AiException(
          'Groq API error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw AiException('Lỗi kết nối Groq: $e');
    }
  }
  Future<String> _callGeminiApi(String apiKey, String prompt) async {
  // ✅ FIXED: Endpoint phải có model name
  const model = 'gemini-2.5-flash';
  final endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
  
  try {
    final response = await http.post(
      Uri.parse('$endpoint?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 8000,
        },
        // ✅ ADDED: Safety settings để tránh bị block
        "safetySettings": [
          {
            "category": "HARM_CATEGORY_HARASSMENT",
            "threshold": "BLOCK_NONE"
          },
          {
            "category": "HARM_CATEGORY_HATE_SPEECH",
            "threshold": "BLOCK_NONE"
          },
          {
            "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "threshold": "BLOCK_NONE"
          },
          {
            "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
            "threshold": "BLOCK_NONE"
          }
        ],
      }),
    ).timeout(const Duration(seconds: 30));

    debugPrint("✅ Gemini Status: ${response.statusCode}");

    if (response.statusCode != 200) {
      debugPrint("❌ Gemini Error Body: ${response.body}");
      throw AiException(
          "Gemini API error: ${response.statusCode} - ${response.body}");
    }

    final data = jsonDecode(response.body);
    
    // ✅ VALIDATE: Check candidates exist
    if (data["candidates"] == null || data["candidates"].isEmpty) {
      throw AiException("Gemini returned empty response");
    }
    
    final text = data["candidates"][0]["content"]["parts"][0]["text"] as String;
    return text.trim();
    
  } catch (e) {
    debugPrint("❌ Gemini API call failed: $e");
    throw AiException("Lỗi kết nối Gemini: $e");
  }
}

  List<AiQuestion> _parseResponse(String response, String provider) {
    try {
      // Clean response
      String cleaned = response.trim();
      
      // Remove markdown code blocks
      cleaned = cleaned.replaceAll(RegExp(r'```json\s*'), '');
      cleaned = cleaned.replaceAll(RegExp(r'```\s*'), '');
      
      // Find JSON array
      final startIdx = cleaned.indexOf('[');
      final endIdx = cleaned.lastIndexOf(']');
      
      if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) {
        print('❌ No valid JSON array found in response');
        throw AiException('Response không chứa JSON array hợp lệ');
      }
      
      final jsonStr = cleaned.substring(startIdx, endIdx + 1);
      print('📝 Parsing JSON: ${jsonStr.substring(0, 200)}...');
      
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      
      final questions = <AiQuestion>[];
      final errors = <String>[];
      
      for (int i = 0; i < jsonList.length; i++) {
        try {
          final item = jsonList[i] as Map<String, dynamic>;
          
          // 🔥 VALIDATE: correct_answer phải trong options
          final options = List<String>.from(item['options'] ?? []);
          final correctAnswer = item['correct_answer']?.toString().trim() ?? '';
          
          if (!options.contains(correctAnswer)) {
            // 🔥 AUTO-FIX: Tìm đáp án gần nhất
            final fixedAnswer = _findClosestOption(correctAnswer, options);
            
            if (fixedAnswer != null) {
              print('⚠️ Auto-fixed Q${i + 1}: "$correctAnswer" → "$fixedAnswer"');
              item['correct_answer'] = fixedAnswer;
            } else {
              errors.add('Q${i + 1}: correct_answer "$correctAnswer" không có trong options ${options}');
              continue; // Skip câu hỏi lỗi
            }
          }
          
          final question = AiQuestion.fromJson(item);
          questions.add(question);
          
        } catch (e) {
          errors.add('Q${i + 1}: $e');
        }
      }
      
      if (errors.isNotEmpty) {
        print('⚠️ Parsing errors:\n${errors.join('\n')}');
      }
      
      if (questions.isEmpty) {
        throw AiException(
          'Không có câu hỏi hợp lệ. Lỗi:\n${errors.join('\n')}'
        );
      }
      
      print('✅ Successfully parsed ${questions.length}/${jsonList.length} questions');
      return questions;
      
    } catch (e) {
      print('❌ Parse error. Content: $response');
      throw AiException('Không thể parse response từ AI: $e');
    }
  }

  /// 🔥 AUTO-FIX: Tìm option gần giống nhất
  String? _findClosestOption(String correctAnswer, List<String> options) {
    if (options.isEmpty) return null;
    
    final lower = correctAnswer.toLowerCase().trim();
    
    // 1. Tìm exact match (ignore case)
    for (var option in options) {
      if (option.toLowerCase().trim() == lower) {
        return option;
      }
    }
    
    // 2. Tìm option chứa correct_answer
    for (var option in options) {
      if (option.toLowerCase().contains(lower)) {
        return option;
      }
    }
    
    // 3. Tìm correct_answer chứa option
    for (var option in options) {
      if (lower.contains(option.toLowerCase())) {
        return option;
      }
    }
    
    // 4. Nếu correct_answer là cụm từ, tìm option chứa từ cuối
    final words = lower.split(' ');
    if (words.length > 1) {
      final lastWord = words.last;
      for (var option in options) {
        if (option.toLowerCase().trim() == lastWord) {
          return option;
        }
      }
    }
    
    // 5. Không tìm thấy → return null
    return null;
  }
}

/// Custom exception for AI-related errors
class AiException implements Exception {
  final String message;
  AiException(this.message);

  @override
  String toString() => 'AiException: $message';
}