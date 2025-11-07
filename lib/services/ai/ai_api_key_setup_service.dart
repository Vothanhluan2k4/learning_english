import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/config/ai_config.dart';
import 'ai_api_key_service.dart';

class AiApiKeySetupService {
  final _apiKeyService = AiApiKeyService();
  final _supabase = SupabaseConfig.client;

  /// Lấy user ID từ auth
  Future<String?> getCurrentUserId() async {
    try {
      final authId = _supabase.auth.currentUser?.id;
      if (authId == null) return null;

      final response = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', authId)
          .single();

      return response['id'] as String;
    } catch (e) {
      print('❌ Error getting current user ID: $e');
      return null;
    }
  }

  /// Load existing keys với provider info
  Future<List<Map<String, dynamic>>> loadExistingKeys() async {
    final userId = await getCurrentUserId();
    if (userId == null) return [];

    final keys = await _apiKeyService.getAllApiKeys(userId);

    // Enrich với provider info
    return keys.map((key) {
      final provider = key['provider'] as String;
      final info = AiConfig.getProviderInfo(provider);

      return {
        ...key,
        'provider_name': info['name'],
        'provider_color': info['color'],
        'provider_icon': info['icon'],
      };
    }).toList();
  }

  /// Save API key với validation
  Future<void> saveApiKey(String provider, String apiKey) async {
    // Validate format
    if (!AiConfig.validateApiKeyFormat(provider, apiKey)) {
      throw Exception('API key không đúng định dạng cho $provider');
    }

    final userId = await getCurrentUserId();
    if (userId == null) throw Exception('Chưa đăng nhập');

    await _apiKeyService.upsertApiKey(
      userId: userId,
      provider: provider,
      apiKey: apiKey,
    );
  }

  /// Delete API key
  Future<void> deleteApiKey(String provider) async {
    final userId = await getCurrentUserId();
    if (userId == null) throw Exception('Chưa đăng nhập');

    await _apiKeyService.deleteApiKey(userId, provider);
  }

  /// Get provider info list
  List<Map<String, dynamic>> getAvailableProviders() {
    return ['groq', 'gemini'].map((provider) {
      return AiConfig.getProviderInfo(provider);
    }).toList();
  }

  /// Format last used date
  String formatLastUsedDate(DateTime? date) {
    if (date == null) return 'Chưa sử dụng';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';

    return '${date.day}/${date.month}/${date.year}';
  }

  /// Get provider display color
  int getProviderColor(String provider) {
    final info = AiConfig.getProviderInfo(provider);
    return info['color'] as int? ?? 0xFF757575;
  }

  /// Get provider icon name
  String getProviderIcon(String provider) {
    final info = AiConfig.getProviderInfo(provider);
    return info['icon'] as String? ?? 'vpn_key';
  }
}