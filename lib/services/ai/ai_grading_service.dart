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

      // ✅ Check if user wrote in Vietnamese
      if (_containsVietnamese(userAnswer)) {
        debugPrint('⚠️ Detected Vietnamese text in answer');
        return {
          'total_score': 0,
          'grammar_score': 0,
          'content_score': 0,
          'organization_score': 0,
          'vocabulary_score': 0,
          'word_count': countWords(userAnswer),
          'strengths': [],
          'weaknesses': ['Bài viết được viết bằng tiếng Việt'],
          'suggestions': ['Vui lòng viết bài bằng tiếng Anh'],
          'detailed_feedback': '⚠️ Yêu cầu viết bằng tiếng Anh. Bài làm của bạn có chứa tiếng Việt nên không được chấm điểm. Hãy thử lại bằng tiếng Anh nhé!',
          'provider': provider,
          'model': AiConfig.getDefaultModel(provider),
          'grading_time_ms': DateTime.now().difference(startTime).inMilliseconds,
        };
      }

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

      // ✅ Validate and fix result
      result = _validateAndFixGradingResult(result);

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
            'content': 'You are an English writing teacher. Always respond with valid JSON only. Do NOT wrap JSON in markdown code blocks.',
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
              {
                'text': '$prompt\n\n**IMPORTANT:** Return ONLY valid JSON. Do NOT wrap in markdown code blocks (```json). Do NOT include any text before or after the JSON object.'
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 4096, // ✅ Increase to prevent truncation
          'topP': 0.95,
          'topK': 40,
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
    
    final content = data['candidates'][0]['content']['parts'][0]['text'] as String;
    
    debugPrint('📥 Raw Gemini response length: ${content.length} chars');
    debugPrint('📄 First 500 chars: ${content.substring(0, content.length > 500 ? 500 : content.length)}');

    // ✅ IMPROVED: Parse JSON from text
    return _parseJsonFromText(content);
  }

  /// ✅ NEW: Parse JSON from text (handles markdown, truncation, etc.)
  Map<String, dynamic> _parseJsonFromText(String text) {
    String cleaned = text.trim();

    // 1. Remove markdown code blocks
    if (cleaned.contains('```json')) {
      final match = RegExp(r'```json\s*([\s\S]*?)\s*```', multiLine: true).firstMatch(cleaned);
      if (match != null) {
        cleaned = match.group(1)!.trim();
      }
    } else if (cleaned.contains('```')) {
      final match = RegExp(r'```\s*([\s\S]*?)\s*```', multiLine: true).firstMatch(cleaned);
      if (match != null) {
        cleaned = match.group(1)!.trim();
      }
    }

    // 2. Extract JSON object
    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');

    if (jsonStart == -1 || jsonEnd == -1 || jsonEnd < jsonStart) {
      throw Exception('No valid JSON object found in response');
    }

    cleaned = cleaned.substring(jsonStart, jsonEnd + 1);

    // 3. Try to parse
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ JSON parse error: $e');
      debugPrint('📄 Cleaned text: $cleaned');
      
      // 4. Last resort: Try to fix common issues
      try {
        // Remove trailing commas
        cleaned = cleaned.replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
        // Fix unescaped quotes in strings
        cleaned = cleaned.replaceAll(RegExp(r'(?<!\\)"(?=\s*[^"]*":)'), '\\"');
        
        return jsonDecode(cleaned) as Map<String, dynamic>;
      } catch (e2) {
        throw Exception('Cannot parse JSON even after cleanup: $e2\nOriginal text: ${text.substring(0, text.length > 200 ? 200 : text.length)}...');
      }
    }
  }

  /// ✅ NEW: Validate and fix grading result
  Map<String, dynamic> _validateAndFixGradingResult(Map<String, dynamic> result) {
    // Fix: Replace task_score with vocabulary_score
    if (result.containsKey('task_score') && !result.containsKey('vocabulary_score')) {
      result['vocabulary_score'] = result['task_score'];
      result.remove('task_score');
      debugPrint('⚠️ Converted task_score to vocabulary_score');
    }

    // Validate required fields
    final requiredFields = [
      'grammar_score',
      'content_score',
      'organization_score',
      'vocabulary_score',
      'total_score',
    ];

    for (final field in requiredFields) {
      if (!result.containsKey(field)) {
        throw Exception('Missing required field: $field');
      }
    }

    // Validate score ranges
    final grammarScore = (result['grammar_score'] as num).toInt();
    final contentScore = (result['content_score'] as num).toInt();
    final organizationScore = (result['organization_score'] as num).toInt();
    final vocabularyScore = (result['vocabulary_score'] as num).toInt();
    
    if (grammarScore < 0 || grammarScore > 30) {
      throw Exception('Invalid grammar_score: $grammarScore (must be 0-30)');
    }
    if (contentScore < 0 || contentScore > 30) {
      throw Exception('Invalid content_score: $contentScore (must be 0-30)');
    }
    if (organizationScore < 0 || organizationScore > 20) {
      throw Exception('Invalid organization_score: $organizationScore (must be 0-20)');
    }
    if (vocabularyScore < 0 || vocabularyScore > 20) {
      throw Exception('Invalid vocabulary_score: $vocabularyScore (must be 0-20)');
    }

    // Fix total score if needed
    final expectedTotal = grammarScore + contentScore + organizationScore + vocabularyScore;
    final totalScore = (result['total_score'] as num).toInt();
    
    if ((totalScore - expectedTotal).abs() > 1) {
      debugPrint('⚠️ Total score mismatch. Expected: $expectedTotal, Got: $totalScore. Fixing...');
      result['total_score'] = expectedTotal;
    }

    // Ensure arrays exist
    result['strengths'] ??= [];
    result['weaknesses'] ??= [];
    result['suggestions'] ??= [];
    result['detailed_feedback'] ??= 'Không có nhận xét chi tiết';

    return result;
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

      result = _validateAndFixGradingResult(result);

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

**IMPORTANT:** Return ONLY valid JSON. Do NOT wrap in markdown code blocks.
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

**IMPORTANT:** Return ONLY valid JSON. Do NOT wrap in markdown code blocks.
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

**IMPORTANT:** Return ONLY valid JSON. Do NOT wrap in markdown code blocks.
''';
  }

  /// ✅ Check if text contains Vietnamese characters
  bool _containsVietnamese(String text) {
    // Vietnamese specific characters (with diacritics)
    final vietnamesePattern = RegExp(
      r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
      r'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ]'
    );
    
    // Check if text has Vietnamese characters
    final hasVietnameseChars = vietnamesePattern.hasMatch(text);
    
    // Common Vietnamese words (lowercase)
    final vietnameseWords = {
      'và', 'của', 'cho', 'với', 'trong', 'được', 'có', 'là', 'một', 'không',
      'để', 'các', 'khi', 'như', 'đã', 'từ', 'bởi', 'này', 'đó', 'những',
      'tôi', 'bạn', 'chúng', 'họ', 'mình', 'việc', 'người', 'thì', 'hay', 'sẽ',
      'cũng', 'rất', 'đang', 'làm', 'nếu', 'nhưng', 'hoặc', 'vì', 'đến', 'về',
      'cần', 'phải', 'theo', 'nên', 'còn', 'hơn', 'giữa', 'sau', 'trước', 'theo',
    };
    
    // Split text into words and check
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    int vietnameseWordCount = 0;
    
    for (final word in words) {
      if (vietnameseWords.contains(word.trim())) {
        vietnameseWordCount++;
      }
    }
    
    return hasVietnameseChars || vietnameseWordCount >= 3;
  }
}