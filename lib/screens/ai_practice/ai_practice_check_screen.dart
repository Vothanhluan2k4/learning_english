import 'package:flutter/material.dart';
import '../../services/ai/ai_api_key_service.dart';
import '../../services/ai/ai_api_key_setup_service.dart';
import 'ai_api_key_setup_screen.dart';
import 'ai_practice_loading_screen.dart';

class AiPracticeCheckScreen extends StatefulWidget {
  final String topic;
  final int mistakeCount;

  const AiPracticeCheckScreen({
    super.key,
    required this.topic,
    this.mistakeCount = 0,
  });

  @override
  State<AiPracticeCheckScreen> createState() => _AiPracticeCheckScreenState();
}

class _AiPracticeCheckScreenState extends State<AiPracticeCheckScreen> {
  final _apiKeyService = AiApiKeyService();
  final _setupService = AiApiKeySetupService();

  bool _isLoading = true;
  int _remainingUses = 0;
  bool _hasOwnApi = false;
  List<Map<String, dynamic>> _availableKeys = [];
  String? _selectedApiKeyId;
  
  // Mode selection: 'free' hoặc 'own'
  String _selectedMode = 'free';
  
  // 🔥 NEW: Số câu hỏi (mặc định 5)
  int _questionCount = 5;

  @override
  void initState() {
    super.initState();
    _checkUsage();
  }

  Future<void> _checkUsage() async {
    try {
      final userId = await _setupService.getCurrentUserId();
      if (userId == null) throw Exception('Chưa đăng nhập');

      // Check daily usage
      final usage = await _apiKeyService.checkDailyUsage(userId);
      
      // Load available API keys
      final keys = await _setupService.loadExistingKeys();

      if (mounted) {
        setState(() {
          _remainingUses = usage['remaining_uses'] as int;
          _hasOwnApi = usage['has_own_api'] as bool;
          _availableKeys = keys.where((k) => k['is_active'] == true ).toList();
          _isLoading = false;
          
          // Auto select mode based on availability
          if (_remainingUses == 0 && _hasOwnApi) {
            _selectedMode = 'own';
            if (_availableKeys.isNotEmpty) {
              _selectedApiKeyId = _availableKeys.first['id'];
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: $e'),
            backgroundColor: Color(0xFFEF5350),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startPractice() {
    final useFreeApi = _selectedMode == 'free';
    
    // ✅ ADD DEBUG
    debugPrint('🎯 Starting practice:');
    debugPrint('   Mode: $_selectedMode');
    debugPrint('   API Key ID: ${useFreeApi ? 'FREE' : _selectedApiKeyId}');
    debugPrint('   Question count: $_questionCount');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiPracticeLoadingScreen(
          topic: widget.topic,
          apiKeyId: useFreeApi ? null : _selectedApiKeyId, // ✅ Pass correct ID
          questionCount: _questionCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Luyện tập AI',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkUsage();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOPIC INFO
              _buildTopicCard(),
              SizedBox(height: 24),

              // USAGE STATUS với Quick Link
              _buildUsageStatusCard(),
              SizedBox(height: 24),

              // MODE SELECTOR (Free vs Own API)
              _buildModeSelector(),
              SizedBox(height: 24),

              // SELECTED MODE CONTENT
              if (_selectedMode == 'free')
                _buildFreeApiContent()
              else
                _buildOwnApiContent(),
              
              SizedBox(height: 24),

              // 🔥 NEW: QUESTION COUNT SELECTOR
              _buildQuestionCountSelector(),
              SizedBox(height: 24),

              // START BUTTON
              _buildStartButton(),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 NEW: Question Count Selector
  Widget _buildQuestionCountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.quiz, color: Color(0xFF2196F3), size: 20),
            SizedBox(width: 8),
            Text(
              'Số câu hỏi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_questionCount câu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        // SLIDER
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFE0E0E0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickSelectButton(5),
                  _buildQuickSelectButton(10),
                  _buildQuickSelectButton(15),
                  _buildQuickSelectButton(20),
                ],
              ),
              SizedBox(height: 12),
              
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Color(0xFF2196F3),
                  inactiveTrackColor: Color(0xFFE3F2FD),
                  thumbColor: Color(0xFF2196F3),
                  overlayColor: Color(0xFF2196F3).withOpacity(0.2),
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
                  trackHeight: 6,
                ),
                child: Slider(
                  value: _questionCount.toDouble(),
                  min: 5,
                  max: 20,
                  divisions: 15, // 5,6,7...20
                  label: '$_questionCount câu',
                  onChanged: (value) {
                    setState(() => _questionCount = value.round());
                  },
                ),
              ),
              
              // MIN-MAX LABELS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '5 câu',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '20 câu',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // INFO TEXT
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Color(0xFFFFB74D).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFFFF9800)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thời gian ước tính: ~${(_questionCount * 1.5).toInt()} phút',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5D4037),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSelectButton(int count) {
    final isSelected = _questionCount == count;
    
    return GestureDetector(
      onTap: () => setState(() => _questionCount = count),
      child: Container(
        width: 70,
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF2196F3) : Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Color(0xFF2196F3) : Color(0xFFE0E0E0),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Color(0xFF424242),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'câu',
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white.withOpacity(0.9) : Color(0xFF757575),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2196F3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF2196F3).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.psychology,
                  color: Color(0xFF1976D2),
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chủ đề luyện tập',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    _buildTopicLines(widget.topic),
                  ],
                ),
              ),
            ],
          ),
          if (widget.mistakeCount > 0) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_down, color: Color(0xFFEF5350), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Đã sai ${widget.mistakeCount} câu trong 7 ngày qua',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF424242),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🔥 UPDATED: Tách topic string - KHÔNG tách nếu comma trong ngoặc
  Widget _buildTopicLines(String topicString) {
    final topics = _smartSplitTopics(topicString);

    if (topics.isEmpty) {
      return Text(
        topicString,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D47A1),
          height: 1.4,
        ),
      );
    }

    // If single topic (no comma outside parentheses), display normally
    if (topics.length == 1) {
      return Text(
        topics.first,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D47A1),
          height: 1.4,
        ),
      );
    }

    // Multiple topics - display each on new line
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: topics.asMap().entries.map((entry) {
        final index = entry.key;
        final topic = entry.value;
        final isLast = index == topics.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
          child: Text(
            topic + (isLast ? '' : ','), // Add comma except last item
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D47A1),
              height: 1.4,
            ),
          ),
        );
      }).toList(),
    );
  }

  // 🔥 NEW: Smart split function - ignore commas inside parentheses
  List<String> _smartSplitTopics(String text) {
    List<String> result = [];
    StringBuffer current = StringBuffer();
    int parenthesesDepth = 0;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == '(') {
        parenthesesDepth++;
        current.write(char);
      } else if (char == ')') {
        parenthesesDepth--;
        current.write(char);
      } else if (char == ',' && parenthesesDepth == 0) {
        // Split only if comma is OUTSIDE parentheses
        final trimmed = current.toString().trim();
        if (trimmed.isNotEmpty) {
          result.add(trimmed);
        }
        current.clear();
      } else {
        current.write(char);
      }
    }

    // Add last part
    final trimmed = current.toString().trim();
    if (trimmed.isNotEmpty) {
      result.add(trimmed);
    }

    return result;
  }

  Widget _buildUsageStatusCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _remainingUses > 0 ? Color(0xFFF1F8E9) : Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _remainingUses > 0 ? Color(0xFF8BC34A) : Color(0xFFEF5350),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _remainingUses > 0 ? Icons.check_circle : Icons.info_outline,
                color: _remainingUses > 0 ? Color(0xFF689F38) : Color(0xFFD32F2F),
                size: 32,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lượt dùng miễn phí hôm nay',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$_remainingUses',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _remainingUses > 0
                                ? Color(0xFF689F38)
                                : Color(0xFFD32F2F),
                          ),
                        ),
                        Text(
                          ' / 3 lượt',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // QUICK ACTION BUTTON
              InkWell(
                onTap: () async {
                  // 🔥 FIX: Chỉ reload khi có thay đổi
                  final hasChanges = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AiApiKeySetupScreen(),
                    ),
                  );
                  
                  // Reload nếu có thay đổi
                  if (hasChanges == true && mounted) {
                    setState(() => _isLoading = true);
                    await _checkUsage();
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFF9C27B0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'API Key',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // HINT TEXT (nếu hết lượt)
          if (_remainingUses == 0) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFFF9800)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thêm API key để luyện tập không giới hạn',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chọn cách thực hành',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            // FREE MODE
            Expanded(
              child: _buildModeChip(
                mode: 'free',
                label: 'API miễn phí',
                icon: Icons.auto_awesome,
                color: Color(0xFF8BC34A),
                isEnabled: _remainingUses > 0,
              ),
            ),
            SizedBox(width: 12),
            // OWN API MODE
            Expanded(
              child: _buildModeChip(
                mode: 'own',
                label: 'API của tôi',
                icon: Icons.vpn_key,
                color: Color(0xFF9C27B0),
                isEnabled: _hasOwnApi,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeChip({
    required String mode,
    required String label,
    required IconData icon,
    required Color color,
    required bool isEnabled,
  }) {
    final isSelected = _selectedMode == mode;
    
    return GestureDetector(
      onTap: isEnabled
          ? () => setState(() => _selectedMode = mode)
          : () {
              // Show message nếu không available
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    mode == 'free'
                        ? 'Bạn đã hết lượt miễn phí hôm nay'
                        : 'Bạn chưa có API key riêng',
                  ),
                  backgroundColor: Color(0xFFFF9800),
                  duration: Duration(seconds: 2),
                ),
              );
            },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isEnabled
              ? (isSelected ? color : Colors.white)
              : Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? (isSelected ? color : Color(0xFFE0E0E0))
                : Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isEnabled
                  ? (isSelected ? Colors.white : color)
                  : Color(0xFFBDBDBD),
              size: 28,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isEnabled
                    ? (isSelected ? Colors.white : Color(0xFF424242))
                    : Color(0xFFBDBDBD),
              ),
            ),
            if (!isEnabled) ...[
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Không khả dụng',
                  style: TextStyle(
                    fontSize: 8,
                    color: Color(0xFFEF5350),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFreeApiContent() {
    if (_remainingUses == 0) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFFFB74D)),
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 40),
            SizedBox(height: 12),
            Text(
              'Đã hết lượt miễn phí',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE65100),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Vui lòng chọn "API của tôi" hoặc quay lại vào ngày mai',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF1F8E9), Color(0xFFDCEDC8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF8BC34A), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF8BC34A).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome, color: Color(0xFF689F38), size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dùng API miễn phí',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF558B2F),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Còn $_remainingUses lượt hôm nay',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFFFF9800),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'FREE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildBulletPoint('Tạo câu hỏi ngẫu nhiên'),
          _buildBulletPoint('Độ khó phù hợp với bạn'),
          _buildBulletPoint('Reset hàng ngày lúc 00:00'),
        ],
      ),
    );
  }

  Widget _buildOwnApiContent() {
    if (!_hasOwnApi || _availableKeys.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF9C27B0)),
        ),
        child: Column(
          children: [
            Icon(Icons.vpn_key_off, color: Color(0xFF9C27B0), size: 40),
            SizedBox(height: 12),
            Text(
              'Chưa có API key',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A1B9A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Thêm API key để luyện tập không giới hạn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF757575),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // 🔥 FIX: Chỉ reload khi có thay đổi
                  final hasChanges = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AiApiKeySetupScreen(),
                    ),
                  );
                  
                  if (hasChanges == true && mounted) {
                    setState(() => _isLoading = true);
                    await _checkUsage();
                  }
                },
                icon: Icon(Icons.add, size: 18),
                label: Text('Thêm API Key'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF9C27B0),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF9C27B0), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFAB47BC), Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.vpn_key, color: Colors.white, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dùng API của tôi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_availableKeys.length} API key khả dụng',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'UNLIMITED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // API KEY SELECTOR
          Text(
            'Chọn API key:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          SizedBox(height: 8),
          ..._availableKeys.map((key) => _buildApiKeyRadio(key)),
        ],
      ),
    );
  }

  Widget _buildApiKeyRadio(Map<String, dynamic> key) {
    final isSelected = _selectedApiKeyId == key['id'];
    final color = Color(_setupService.getProviderColor(key['provider']));

    return GestureDetector(
      onTap: () {
        setState(() => _selectedApiKeyId = key['id']);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? color : Color(0xFFBDBDBD),
              size: 20,
            ),
            SizedBox(width: 12),
            Icon(
              _getIconData(_setupService.getProviderIcon(key['provider'])),
              color: color,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              key['provider'].toString().toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF424242),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(0xFF689F38),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF424242),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    final canStart = (_selectedMode == 'free' && _remainingUses > 0) ||
        (_selectedMode == 'own' && _selectedApiKeyId != null);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canStart ? _startPractice : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedMode == 'free'
              ? Color(0xFF8BC34A)
              : Color(0xFF9C27B0),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Color(0xFFE0E0E0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow, size: 24),
            SizedBox(width: 12),
            Text(
              'Bắt đầu luyện tập ($_questionCount câu)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'flash_on':
        return Icons.flash_on;
      case 'auto_awesome':
        return Icons.auto_awesome;
      default:
        return Icons.vpn_key;
    }
  }
}