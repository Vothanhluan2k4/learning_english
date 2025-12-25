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
    String? exampleAnswer, // ✅ NEW: Thêm example answer
    String provider = 'groq',
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

      // ✅ NEW: Detect if this is a sentence building exercise
      final isSentenceBuilding = _isSentenceBuildingExercise(
        questionText, 
        minWords, 
        maxWords, 
        guideline,
      );

      // Build appropriate prompt
      final prompt = isSentenceBuilding
          ? _buildSentenceBuildingPrompt(
              questionText, 
              userAnswer, 
              exampleAnswer, 
              guideline,
            )
          : AiConfig.writingGradingPromptTemplate
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

      // ✅ CRITICAL: Override AI's word_count with our own accurate count
      // AI often miscounts words, so we use our reliable countWords() method
      final actualWordCount = countWords(userAnswer);
      result['word_count'] = actualWordCount;
      debugPrint('📊 Overriding AI word_count (${result['word_count']}) with actual count: $actualWordCount');

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

  /// ✅ NEW: Check if this is a sentence building exercise
  bool _isSentenceBuildingExercise(
    String questionText,
    int? minWords,
    int? maxWords,
    String? guideline,
  ) {
    final lowerQuestion = questionText.toLowerCase();
    final lowerGuideline = guideline?.toLowerCase() ?? '';

    // Keywords indicating sentence building
    final sentenceBuildingKeywords = [
      'viết câu',
      'sắp xếp',
      'từ gợi ý',
      'hoàn chỉnh',
      'rearrange',
      'arrange',
      'words given',
      'write a sentence',
      'complete the sentence',
      'use the words',
    ];

    // Check if question/guideline contains keywords
    for (final keyword in sentenceBuildingKeywords) {
      if (lowerQuestion.contains(keyword) || lowerGuideline.contains(keyword)) {
        return true;
      }
    }

    // Check word count (sentence building usually has low word limit)
    if (maxWords != null && maxWords <= 20) {
      return true;
    }

    return false;
  }

  /// ✅ NEW: Build prompt for sentence building exercises
  String _buildSentenceBuildingPrompt(
    String questionText,
    String userAnswer,
    String? exampleAnswer,
    String? guideline,
  ) {
    return '''
You are an English grammar teacher grading a SENTENCE BUILDING exercise.

**Task:** $questionText

**Guidelines:** ${guideline ?? 'Build a grammatically correct sentence'}

**Expected Answer (Example):**
$exampleAnswer

**Student's Answer:**
$userAnswer

**IMPORTANT Grading Rules:**
1. This is a SENTENCE BUILDING exercise (NOT an essay)
2. Student only needs to write 1 correct sentence
3. DO NOT penalize for "lack of vocabulary variety" or "short length"
4. DO NOT suggest "expanding the sentence" or "using advanced words"
5. **MUST FOLLOW the Guidelines provided above** - grade based on what the guideline requires
6. Focus ONLY on:
   - Grammar correctness (verb tense, word order, articles, prepositions)
   - Matching the required meaning AND guideline requirements
   - Proper capitalization and punctuation
7. **ALL FEEDBACK MUST BE IN VIETNAMESE** (detailed_feedback, strengths, weaknesses, suggestions)

**Scoring:**
- grammar_score (0-30): Grammar correctness ONLY
- content_score (0-30): Does it express the correct meaning?
- organization_score (0-20): Capitalization, punctuation
- vocabulary_score (0-20): Word choice (only if words are clearly wrong)

**Response Format (JSON only):**
{
  "total_score": <0-100>,
  "grammar_score": <0-30>,
  "content_score": <0-30>,
  "organization_score": <0-20>,
  "vocabulary_score": <0-20>,
  "word_count": <number>,
  "strengths": ["<what's correct>"],
  "weaknesses": ["<only real errors, not suggestions>"],
  "suggestions": ["<only if there are grammar mistakes>"],
  "detailed_feedback": "<feedback in Vietnamese, focus on grammar errors ONLY>"
}

**Examples of GOOD feedback:**
✅ "Câu đúng ngữ pháp, diễn đạt rõ ý"
✅ "Thiếu giới từ 'to' trước 'school'"
✅ "Sai thì động từ: phải dùng 'goes' thay vì 'go'"

**Examples of BAD feedback (DO NOT do this):**
❌ "Từ vựng đơn giản" (This is a sentence building exercise!)
❌ "Nên mở rộng câu thêm" (Not required!)
❌ "Thiếu liên từ, từ nối" (It's just 1 sentence!)

**CRITICAL:**
1. Return ONLY valid JSON. Do NOT wrap in markdown code blocks.
2. ALL text in detailed_feedback, strengths, weaknesses, suggestions MUST be in VIETNAMESE
3. Grade according to the Guidelines provided above
4. detailed_feedback must be a PARAGRAPH (not bullet points)
''';
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
                'text': '$prompt\n\n**CRITICAL INSTRUCTIONS:**\n1. Return ONLY valid JSON (no markdown code blocks like ```json)\n2. ALL feedback fields (detailed_feedback, strengths, weaknesses, suggestions) MUST be in VIETNAMESE\n3. Follow ALL guidelines and requirements mentioned in the prompt\n4. Ensure JSON is complete and valid'
              }
            ]
          }
        ],
        'systemInstruction': {
          'parts': [
            {
              'text': 'Bạn là giáo viên tiếng Anh. LUÔN LUÔN phản hồi bằng TIẾNG VIỆT trong các trường detailed_feedback, strengths, weaknesses, suggestions. Chấm điểm CHÍNH XÁC theo yêu cầu và guideline được cung cấp. Trả về JSON hợp lệ.'
            }
          ]
        },
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 8192, // ✅ Increase to prevent truncation
          'topP': 0.95,
          'topK': 40,
          'responseMimeType': 'application/json', // ✅ Force JSON response
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

  /// Count words in text (improved accuracy)
  int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    
    // Remove extra whitespace, newlines, tabs
    String cleaned = text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces/newlines/tabs with single space
        .replaceAll(RegExp(r"[^\w\s'-]"), ' '); // Remove special chars except apostrophe, hyphen
    
    // Split by space and filter out empty strings
    final words = cleaned
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .toList();
    
    debugPrint('📊 Word count: ${words.length} words from "${text.substring(0, text.length > 100 ? 100 : text.length)}..."');
    
    return words.length;
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

    // ✅ Check min words
    if (minWords != null && wordCount < minWords) {
      return {
        'isValid': false,
        'wordCount': wordCount,
        'message': 'Bài viết cần ít nhất $minWords từ (hiện tại: $wordCount từ)',
      };
    }

    // ✅ Check max words with 5% tolerance
    if (maxWords != null) {
      final tolerance = (maxWords * 0.05).ceil(); // 5% tolerance: 80 → 84
      final effectiveMax = maxWords + tolerance;
      
      if (wordCount > effectiveMax) {
        return {
          'isValid': false,
          'wordCount': wordCount,
          'message': 'Bài viết không được vượt quá $maxWords từ (tối đa cho phép: $effectiveMax từ, hiện tại: $wordCount từ)',
        };
      }
    }

    // ✅ Success message
    String statusMessage = 'Bài viết hợp lệ ($wordCount từ)';
    
    if (minWords != null && maxWords != null) {
      statusMessage = 'Số từ: $wordCount/$minWords-$maxWords ✓';
    } else if (minWords != null) {
      statusMessage = 'Số từ: $wordCount (tối thiểu $minWords) ✓';
    } else if (maxWords != null) {
      statusMessage = 'Số từ: $wordCount (tối đa $maxWords) ✓';
    }

    return {
      'isValid': true,
      'wordCount': wordCount,
      'message': statusMessage,
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