import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/ai/ai_practice_service.dart';
import '../../services/ai/ai_api_key_service.dart';
import '../../services/ai/ai_question_generator_service.dart';
import '../../core/config/ai_config.dart';
import '../../core/config/supabase_config.dart';
import 'ai_practice_quiz_screen.dart';

class AiPracticeLoadingScreen extends StatefulWidget {
  final String topic;
  final String? apiKeyId;
  final int questionCount;

  const AiPracticeLoadingScreen({
    super.key,
    required this.topic,
    this.apiKeyId,
    this.questionCount = 5,
  });

  @override
  State<AiPracticeLoadingScreen> createState() => _AiPracticeLoadingScreenState();
}

class _AiPracticeLoadingScreenState extends State<AiPracticeLoadingScreen>
    with SingleTickerProviderStateMixin {
  final _practiceService = AiPracticeService();
  final _apiKeyService = AiApiKeyService();
  final _generatorService = AiQuestionGeneratorService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _currentStatus = 'Đang khởi tạo...';
  double _progress = 0.0;
  bool _hasError = false;
  String? _errorMessage;

  final List<String> _loadingMessages = [
    'Đang kết nối với AI...',
    'AI đang phân tích chủ đề...',
    'Đang tạo câu hỏi phù hợp...',
    'Đang kiểm tra chất lượng...',
    'Hoàn tất! Chuẩn bị bài tập...',
  ];

  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startLoadingMessages();
    _generateQuestions();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _startLoadingMessages() {
    Timer.periodic(Duration(milliseconds: 1500), (timer) {
      if (!mounted || _hasError) {
        timer.cancel();
        return;
      }

      if (_messageIndex < _loadingMessages.length - 1) {
        setState(() {
          _messageIndex++;
          _currentStatus = _loadingMessages[_messageIndex];
          _progress = (_messageIndex + 1) / _loadingMessages.length;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _generateQuestions() async {
    try {
      // STEP 1: Get current user ID
      setState(() {
        _currentStatus = 'Đang xác thực...';
        _progress = 0.1;
      });

      final authId = SupabaseConfig.client.auth.currentUser?.id;
      if (authId == null) throw Exception('Chưa đăng nhập');

      final userResponse = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('auth_id', authId)
          .single();

      final userId = userResponse['id'] as String;

      // STEP 2: Create session
      setState(() {
        _currentStatus = 'Đang tạo phiên học...';
        _progress = 0.2;
      });

      final sessionId = await _practiceService.createSession(
        userId: userId,
        topic: widget.topic,
        questionCount: widget.questionCount,
        apiKeyId: widget.apiKeyId,
      );

      // STEP 3: Get API key
      setState(() {
        _currentStatus = 'Đang kết nối AI...';
        _progress = 0.3;
      });

      String apiKey;
      String provider;

      if (widget.apiKeyId != null) {
        // ✅ FIX: Use user's selected API key BY ID
        debugPrint('🔑 Using user API key ID: ${widget.apiKeyId}');
        
        final keyData = await _apiKeyService.getApiKeyById(widget.apiKeyId!);
        if (keyData == null) {
          throw Exception('Không tìm thấy API key đã chọn');
        }
        
        apiKey = keyData['api_key'];
        provider = keyData['provider'];
        
        debugPrint('✅ Using provider: $provider');
      } else {
        // Use free API key from config
        debugPrint('🆓 Using free API key');
        
        apiKey = AiConfig.groqApiKey;
        provider = 'groq';
        
        // Validate free API key
        if (apiKey.isEmpty || apiKey.contains('YOUR_')) {
          throw Exception(
            'Chưa cấu hình API key miễn phí. '
            'Vui lòng thêm API key của bạn hoặc liên hệ admin.'
          );
        }
        
        debugPrint('✅ Using free provider: $provider');
      }

      // STEP 4: Generate questions
      setState(() {
        _currentStatus = 'AI đang tạo câu hỏi...';
        _progress = 0.5;
      });

      final questions = await _generatorService.generateQuestions(
        provider: provider,
        apiKey: apiKey,
        topic: widget.topic,
        questionCount: widget.questionCount,
      );

      if (questions.isEmpty) {
        throw Exception('Không thể tạo câu hỏi. Vui lòng thử lại.');
      }

      // STEP 5: Convert questions to format for Quiz screen
      setState(() {
        _currentStatus = 'Đang chuẩn bị bài tập...';
        _progress = 0.8;
      });

      // 🔥 FIX: Convert to format có 'id' field cho Quiz screen
      final questionsForQuiz = questions
          .asMap()
          .entries
          .map((entry) {
            final question = entry.value;
            return {
              'id': question.id, // ✅ Có 'id'
              'question': question.question,
              'options': question.options,
              'correct_answer': question.correctAnswer,
              'explanation': question.explanation,
              'order_index': entry.key,
            };
          })
          .toList();

      // Convert to Supabase format để save
      final questionsForDb = questions
          .asMap()
          .entries
          .map((entry) => entry.value.toSupabaseJson(
                sessionId: sessionId,
                orderIndex: entry.key,
              ))
          .toList();

      await _practiceService.updateSessionQuestions(
        sessionId: sessionId,
        questions: questionsForDb,
      );

      // STEP 6: Navigate to quiz
      setState(() {
        _currentStatus = 'Hoàn tất!';
        _progress = 1.0;
      });

      await Future.delayed(Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AiPracticeQuizScreen(
              sessionId: sessionId,
              questions: questionsForQuiz, // ✅ Dùng format có 'id'
              topic: widget.topic,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error generating questions: $e');
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _getErrorMessage(e);
        });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();
    
    if (errorStr.contains('API key')) {
      return 'API key không hợp lệ. Vui lòng kiểm tra lại.';
    } else if (errorStr.contains('quota') || errorStr.contains('limit')) {
      return 'Đã vượt quá giới hạn. Vui lòng thử lại sau.';
    } else if (errorStr.contains('timeout')) {
      return 'Kết nối quá chậm. Vui lòng kiểm tra mạng.';
    } else if (errorStr.contains('parse') || errorStr.contains('JSON')) {
      return 'AI trả về dữ liệu không hợp lệ. Vui lòng thử lại.';
    } else if (errorStr.contains('Chưa cấu hình')) {
      return errorStr.replaceAll('Exception: ', '');
    }
    
    return 'Có lỗi xảy ra: $errorStr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: SafeArea(
        child: _hasError ? _buildErrorView() : _buildLoadingView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ANIMATED ICON
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF2196F3).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.psychology,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 48),

            // TITLE
            Text(
              'AI đang làm việc',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 12),

            // STATUS TEXT
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: Text(
                _currentStatus,
                key: ValueKey(_currentStatus),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF757575),
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: 32),

            // PROGRESS BAR
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                height: 8,
                color: Color(0xFFE0E0E0),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: MediaQuery.of(context).size.width * _progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),

            // PROGRESS PERCENTAGE
            Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
            SizedBox(height: 48),

            // TOPIC INFO
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFE0E0E0)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.topic,
                    color: Color(0xFF2196F3),
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chủ đề',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF757575),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          widget.topic,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.questionCount} câu',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ERROR ICON
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
                border: Border.all(color: Color(0xFFEF5350), width: 3),
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: Color(0xFFEF5350),
              ),
            ),
            SizedBox(height: 32),

            // ERROR TITLE
            Text(
              'Oops! Có lỗi xảy ra',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 12),

            // ERROR MESSAGE
            Text(
              _errorMessage ?? 'Không thể tạo bài tập',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),

            // RETRY BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = null;
                    _messageIndex = 0;
                    _progress = 0.0;
                  });
                  _startLoadingMessages();
                  _generateQuestions();
                },
                icon: Icon(Icons.refresh),
                label: Text(
                  'Thử lại',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            SizedBox(height: 12),

            // BACK BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back),
                label: Text(
                  'Quay lại',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF757575),
                  side: BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}