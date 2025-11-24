import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/ai/ai_api_key_setup_service.dart';
import '../../core/config/ai_config.dart';

class AiApiKeySetupScreen extends StatefulWidget {
  const AiApiKeySetupScreen({super.key});

  @override
  State<AiApiKeySetupScreen> createState() => _AiApiKeySetupScreenState();
}

class _AiApiKeySetupScreenState extends State<AiApiKeySetupScreen> {
  final _setupService = AiApiKeySetupService();
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  
  String _selectedProvider = 'groq';
  bool _isLoading = false;
  bool _obscureApiKey = true;
  List<Map<String, dynamic>> _existingKeys = [];

  bool _hasChanges = false; // Track nếu có thay đổi

  @override
  void initState() {
    super.initState();
    _loadExistingKeys();
  }

  Future<void> _loadExistingKeys() async {
    final keys = await _setupService.loadExistingKeys();
    if (mounted) {
      setState(() => _existingKeys = keys);
    }
  }

  Future<void> _saveApiKey() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _setupService.saveApiKey(
        _selectedProvider,
        _apiKeyController.text.trim(),
      );

      if (mounted) {
        // 🔥 MARK: Có thay đổi nhưng KHÔNG tự động quay lại
        _hasChanges = true;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lưu API key thành công!'),
            backgroundColor: Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Clear form sau khi lưu thành công
        _apiKeyController.clear();
        
        // Reload danh sách để hiển thị key mới
        await _loadExistingKeys();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: $e'),
            backgroundColor: Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteApiKey(String provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa API key cho $provider?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _setupService.deleteApiKey(provider);
      
      if (mounted) {
        // 🔥 MARK: Có thay đổi
        _hasChanges = true;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Đã xóa API key'),
            backgroundColor: Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Reload danh sách
        await _loadExistingKeys();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: $e'),
            backgroundColor: Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // THÊM: Function mở URL
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Mở trong browser
        );
      } else {
        throw 'Không thể mở URL: $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Không thể mở link: $e'),
            backgroundColor: Color(0xFFEF5350),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // 🔥 INTERCEPT: Khi user nhấn back, return true nếu có thay đổi
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
          title: Text(
            'Cài đặt API Key',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.bold,
            ),
          ),
          // 🔥 ADD: Badge nếu có thay đổi
          
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(),
              SizedBox(height: 24),

              if (_existingKeys.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'API Keys hiện có',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    // 🔥 ADD: Count badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_existingKeys.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                ..._existingKeys.map((key) => _buildExistingKeyCard(key)),
                SizedBox(height: 24),
              ],

              Text(
                'Thêm API Key mới',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 16),

              _buildForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
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
              Icon(Icons.info_outline, color: Color(0xFF1976D2), size: 24),
              SizedBox(width: 12),
              Text(
                'Tại sao cần API Key?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildBullet('Luyện tập không giới hạn (app free chỉ 3 lần/ngày)'),
          _buildBullet('AI tạo bài tập riêng cho bạn'),
          _buildBullet('Tốc độ nhanh hơn, không phải chờ đợi'),
          SizedBox(height: 12),
          InkWell(
            onTap: () => _showProviderGuide(),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.help_outline, size: 16, color: Color(0xFF1976D2)),
                  SizedBox(width: 8),
                  Text(
                    'Hướng dẫn lấy API Key',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingKeyCard(Map<String, dynamic> key) {
    final provider = key['provider'] as String;
    final lastUsed = key['last_used_at'];
    final isActive = key['is_active'] as bool;
    final color = Color(_setupService.getProviderColor(provider));

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Color(0xFF4CAF50) : Color(0xFFE0E0E0),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getIconData(_setupService.getProviderIcon(provider)),
              color: color,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _setupService.formatLastUsedDate(
                    lastUsed != null ? DateTime.parse(lastUsed) : null,
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Active',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Color(0xFFEF5350)),
            onPressed: () => _deleteApiKey(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chọn Provider',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildProviderChip('groq', 'Groq', 'flash_on'),
              SizedBox(width: 12),
              _buildProviderChip('gemini', 'Gemini', 'auto_awesome'),
            ],
          ),
          SizedBox(height: 20),

          Text(
            'API Key',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            decoration: InputDecoration(
              hintText: 'Nhập API key của bạn',
              prefixIcon: Icon(Icons.vpn_key),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _obscureApiKey = !_obscureApiKey);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.content_paste),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _apiKeyController.text = data!.text!;
                      }
                    },
                  ),
                ],
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập API key';
              }
              if (!AiConfig.validateApiKeyFormat(_selectedProvider, value)) {
                return 'API key không đúng định dạng cho $_selectedProvider';
              }
              return null;
            },
          ),
          SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveApiKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2196F3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Lưu API Key',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderChip(String provider, String label, String iconName) {
    final isSelected = _selectedProvider == provider;
    final color = Color(_setupService.getProviderColor(provider));
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedProvider = provider),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Color(0xFFE0E0E0),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIconData(iconName),
                color: isSelected ? Colors.white : color,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Color(0xFF424242),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(0xFF1976D2),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Color(0xFF424242)),
            ),
          ),
        ],
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

  void _showProviderGuide() {
    final providers = _setupService.getAvailableProviders();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // HEADER
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Color(0xFFFF9800), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hướng dẫn lấy API Key',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // CONTENT
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.all(24),
                itemCount: providers.length,
                separatorBuilder: (_, __) => SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final provider = providers[index];
                  return _buildGuideSection(provider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection(Map<String, dynamic> provider) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(provider['color']).withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(provider['color']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getIconData(provider['icon']),
                  color: Color(provider['color']),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider['name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      provider['free_tier'],
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // STEPS
          _buildGuideStep('1', 'Truy cập trang lấy API key', hasLink: true, url: provider['get_key_url']),
          _buildGuideStep('2', 'Đăng ký/Đăng nhập tài khoản'),
          _buildGuideStep('3', 'Tạo API Key mới'),
          _buildGuideStep('4', 'Copy và paste vào app'),
          
          SizedBox(height: 16),
          
          // ACTION BUTTONS
          Row(
            children: [
              // OPEN LINK BUTTON
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchUrl(provider['get_key_url']),
                  icon: Icon(Icons.open_in_new, size: 16),
                  label: Text(
                    'Lấy API Key',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(provider['color']),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              SizedBox(width: 12),
              
              // DOCS BUTTON
              OutlinedButton.icon(
                onPressed: () => _launchUrl(provider['docs_url']),
                icon: Icon(Icons.description, size: 16),
                label: Text(
                  'Docs',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(provider['color']),
                  side: BorderSide(color: Color(provider['color'])),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String number, String text, {bool hasLink = false, String? url}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF424242),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (hasLink && url != null) ...[
                  SizedBox(height: 6),
                  InkWell(
                    onTap: () => _launchUrl(url),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Color(0xFF2196F3).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.link,
                            size: 14,
                            color: Color(0xFF2196F3),
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              url,
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2196F3),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new,
                            size: 12,
                            color: Color(0xFF2196F3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}