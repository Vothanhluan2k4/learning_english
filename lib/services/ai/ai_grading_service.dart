import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../core/config/ai_config.dart';

class AiGradingService {
  /// Grade writing using AI (Groq or Gemini)
  Future<Map<String, dynamic>> gradeWriting({
    required String questionText,
    required String userAnswer,
    int? minWords,
    int? maxWords,
    String? guideline,
    String provider = 'groq', // 'groq' or 'gemini'
  }) async {
    final startTime = DateTime.now();

    try {
      debugPrint('🤖 Sending to $provider AI for grading...');

      // Build prompt
      final prompt = AiConfig.writingGradingPromptTemplate
          .replaceAll('{question}', questionText)
          .replaceAll('{answer}', userAnswer)
          .replaceAll('{min_words}', minWords?.toString() ?? 'Không giới hạn')
          .replaceAll('{max_words}', maxWords?.toString() ?? 'Không giới hạn')
          .replaceAll('{guideline}', guideline != null ? '- Guideline: $guideline' : '');

      Map<String, dynamic> result;

      if (provider.toLowerCase() == 'groq') {
        result = await _gradeWithGroq(prompt);
      } else if (provider.toLowerCase() == 'gemini') {
        result = await _gradeWithGemini(prompt);
      } else {
        throw UnsupportedError('Provider $provider không được hỗ trợ');
      }

      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('✅ AI grading completed in ${responseTime}ms');

      return {
        ...result,
        'provider': provider,
        'model': AiConfig.getDefaultModel(provider),
        'grading_time_ms': responseTime,
      };
    } catch (e) {
      debugPrint('❌ AI grading error: $e');
      rethrow;
    }
  }

  /// Grade with Groq
  Future<Map<String, dynamic>> _gradeWithGroq(String prompt) async {
    final response = await http.post(
      Uri.parse(AiConfig.groqBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AiConfig.groqApiKey}',
      },
      body: jsonEncode({
        'model': AiConfig.groqDefaultModel,
        'messages': [
          {
            'role': 'system',
            'content': 'You are an English writing teacher. Always respond with valid JSON only.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.7,
        'max_tokens': 2000,
        'response_format': {'type': 'json_object'},
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'];
    
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Grade with Gemini
  Future<Map<String, dynamic>> _gradeWithGemini(String prompt) async {
    final endpoint = '${AiConfig.geminiBaseUrl}/${AiConfig.geminiDefaultModel}:generateContent?key=${AiConfig.geminiApiKey}';
    
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 2000,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_NONE'
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_NONE'
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_NONE'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_NONE'
          },
        ],
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    
    if (data['candidates'] == null || data['candidates'].isEmpty) {
      throw Exception('Gemini returned empty response');
    }
    
    final content = data['candidates'][0]['content']['parts'][0]['text'];
    
    // Parse JSON from text
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      // Extract JSON from markdown
      final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(content);
      if (jsonMatch != null) {
        return jsonDecode(jsonMatch.group(1)!) as Map<String, dynamic>;
      }
      
      // Fallback: find any JSON object
      final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (objectMatch != null) {
        return jsonDecode(objectMatch.group(0)!) as Map<String, dynamic>;
      }
      
      throw Exception('Cannot parse JSON from Gemini response: $content');
    }
  }

  /// Count words in text
  int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Validate writing answer
  Map<String, dynamic> validateWriting({
    required String text,
    int? minWords,
    int? maxWords,
  }) {
    final wordCount = countWords(text);

    if (text.trim().isEmpty) {
      return {
        'isValid': false,
        'wordCount': 0,
        'message': 'Vui lòng nhập bài viết của bạn',
      };
    }

    if (minWords != null && wordCount < minWords) {
      return {
        'isValid': false,
        'wordCount': wordCount,
        'message': 'Bài viết cần ít nhất $minWords từ (hiện tại: $wordCount từ)',
      };
    }

    if (maxWords != null && wordCount > maxWords) {
      return {
        'isValid': false,
        'wordCount': wordCount,
        'message': 'Bài viết không được vượt quá $maxWords từ (hiện tại: $wordCount từ)',
      };
    }

    return {
      'isValid': true,
      'wordCount': wordCount,
      'message': 'Bài viết hợp lệ',
    };
  }

  /// Grade speaking (all 3 modes)
  Future<Map<String, dynamic>> gradeSpeaking({
    required String questionText,
    required String userAnswer,
    String? referenceText,
    String speakingMode = 'read_aloud',
    String? expectedAnswer,
    String? guideline,
    String provider = 'groq',
  }) async {
    try {
      debugPrint('🤖 Grading speaking [$speakingMode] with $provider...');

      String prompt;
      switch (speakingMode) {
        case 'read_aloud':
          prompt = _buildReadAloudPrompt(questionText, userAnswer, referenceText);
          break;
        case 'answer_prompt':
          prompt = _buildAnswerPromptPrompt(questionText, userAnswer, expectedAnswer, guideline);
          break;
        case 'free_speaking':
          prompt = _buildFreeSpeakingPrompt(questionText, userAnswer, expectedAnswer);
          break;
        default:
          throw ArgumentError('Invalid speaking mode: $speakingMode');
      }

      Map<String, dynamic> result;
      if (provider == 'groq') {
        result = await _gradeWithGroq(prompt);
      } else {
        result = await _gradeWithGemini(prompt);
      }

      return {
        ...result,
        'provider': provider,
        'speaking_mode': speakingMode,
      };
    } catch (e) {
      debugPrint('❌ Error grading speaking: $e');
      rethrow;
    }
  }

  String _buildReadAloudPrompt(String question, String userAnswer, String? referenceText) {
    return '''
You are an English speaking teacher. Grade this read-aloud performance.

**Task:** $question

**Reference Text:**
$referenceText

**Student's Spoken Text (from speech-to-text):**
$userAnswer

**Grading Criteria (JSON response only):**
{
  "total_score": <0-100>,
  "content_score": <0-30> (accuracy vs reference),
  "grammar_score": <0-30> (correct grammar),
  "vocabulary_score": <0-20> (word choice),
  "organization_score": <0-20> (completeness),
  "detailed_feedback": "<feedback in Vietnamese>",
  "mistakes": ["<specific errors>"],
  "strengths": ["<what was done well>"]
}
''';
  }

  String _buildAnswerPromptPrompt(String question, String userAnswer, String? expectedAnswer, String? guideline) {
    return '''
You are an English speaking teacher. Grade this guided speaking answer.

**Question:** $question

**Guidelines:**
${guideline ?? 'Answer the question naturally'}

**Expected Content:**
$expectedAnswer

**Student's Answer:**
$userAnswer

**Grading Criteria (JSON response only):**
{
  "total_score": <0-100>,
  "content_score": <0-30> (relevance & completeness),
  "grammar_score": <0-30> (correct grammar),
  "vocabulary_score": <0-20> (range & appropriateness),
  "organization_score": <0-20> (logical flow),
  "detailed_feedback": "<feedback in Vietnamese>",
  "mistakes": ["<grammar/vocab errors>"],
  "strengths": ["<good points>"],
  "suggestions": ["<improvement tips>"]
}
''';
  }

  String _buildFreeSpeakingPrompt(String question, String userAnswer, String? expectedAnswer) {
    return '''
You are an English speaking teacher. Grade this free speaking/role-play.

**Scenario:** $question

**Example Response:**
${expectedAnswer ?? 'N/A'}

**Student's Answer:**
$userAnswer

**Grading Criteria (JSON response only):**
{
  "total_score": <0-100>,
  "content_score": <0-30> (relevance to scenario),
  "grammar_score": <0-30> (grammar accuracy),
  "vocabulary_score": <0-20> (vocabulary usage),
  "organization_score": <0-20> (coherence & natural flow),
  "detailed_feedback": "<feedback in Vietnamese>",
  "mistakes": ["<errors>"],
  "strengths": ["<strengths>"],
  "suggestions": ["<tips for improvement>"]
}
''';
  }
}