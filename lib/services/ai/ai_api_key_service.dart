import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/encryption_helper.dart';
import '../../core/errors/ai_exceptions.dart';

class AiApiKeyService {
  final _supabase = SupabaseConfig.client;

  /// Lấy API key của user (ưu tiên provider nào có)
  Future<Map<String, dynamic>?> getUserApiKey(String userId) async {
    try {
      final response = await _supabase
          .from('user_api_keys')
          .select('id, provider, api_key_encrypted, last_used_at')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('last_used_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      // Decrypt API key
      final decryptedKey = EncryptionHelper.decrypt(response['api_key_encrypted']);

      return {
        'id': response['id'],
        'provider': response['provider'],
        'api_key': decryptedKey,
        'last_used_at': response['last_used_at'],
      };
    } catch (e) {
      print('❌ Error getting user API key: $e');
      throw AiApiKeyException('Không thể lấy API key: $e');
    }
  }

  /// Lấy API key theo provider cụ thể
  Future<Map<String, dynamic>?> getApiKeyByProvider(String userId, String provider) async {
    try {
      final response = await _supabase
          .from('user_api_keys')
          .select('id, provider, api_key_encrypted, last_used_at')
          .eq('user_id', userId)
          .eq('provider', provider)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;

      final decryptedKey = EncryptionHelper.decrypt(response['api_key_encrypted']);

      return {
        'id': response['id'],
        'provider': response['provider'],
        'api_key': decryptedKey,
        'last_used_at': response['last_used_at'],
      };
    } catch (e) {
      print('❌ Error getting API key by provider: $e');
      throw AiApiKeyException('Không thể lấy API key cho $provider: $e');
    }
  }

  /// ✅ NEW: Get API key by specific ID
  Future<Map<String, dynamic>?> getApiKeyById(String apiKeyId) async {
    try {
      final response = await _supabase
          .from('user_api_keys')
          .select('id, provider, api_key_encrypted, last_used_at')
          .eq('id', apiKeyId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;

      final decryptedKey = EncryptionHelper.decrypt(response['api_key_encrypted']);

      debugPrint('✅ Got API key for provider: ${response['provider']}');

      return {
        'id': response['id'],
        'provider': response['provider'],
        'api_key': decryptedKey,
        'last_used_at': response['last_used_at'],
      };
    } catch (e) {
      debugPrint('❌ Error getting API key by ID: $e');
      throw AiApiKeyException('Không thể lấy API key: $e');
    }
  }

  /// Kiểm tra user có API key không
  Future<bool> hasApiKey(String userId) async {
    try {
      final response = await _supabase
          .from('user_api_keys')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ Error checking API key: $e');
      return false;
    }
  }

  /// Lưu/Cập nhật API key
  Future<void> upsertApiKey({
    required String userId,
    required String provider,
    required String apiKey,
  }) async {
    try {
      // Encrypt API key trước khi lưu
      final encryptedKey = EncryptionHelper.encrypt(apiKey);

      // Gọi Supabase function (hoặc dùng INSERT ON CONFLICT)
      final existingKey = await _supabase
          .from('user_api_keys')
          .select('id')
          .eq('user_id', userId)
          .eq('provider', provider)
          .maybeSingle();

      if (existingKey != null) {
        // UPDATE
        await _supabase
            .from('user_api_keys')
            .update({
              'api_key_encrypted': encryptedKey,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('provider', provider);
      } else {
        // INSERT
        await _supabase.from('user_api_keys').insert({
          'user_id': userId,
          'provider': provider,
          'api_key_encrypted': encryptedKey,
        });
      }

      print('✅ API key saved for provider: $provider');
    } catch (e) {
      print('❌ Error saving API key: $e');
      throw AiApiKeyException('Không thể lưu API key: $e');
    }
  }

  /// Xóa API key
  Future<void> deleteApiKey(String userId, String provider) async {
    try {
      await _supabase
          .from('user_api_keys')
          .delete()
          .eq('user_id', userId)
          .eq('provider', provider);

      print('✅ API key deleted: $provider');
    } catch (e) {
      print('❌ Error deleting API key: $e');
      throw AiApiKeyException('Không thể xóa API key: $e');
    }
  }

  /// Kiểm tra còn lượt sử dụng miễn phí không (3 lần/ngày)
  Future<Map<String, dynamic>> checkDailyUsage(String userId) async {
    try {
      // Đếm số lần dùng hôm nay
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final response = await _supabase
          .from('ai_practice_usage')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', '$today 00:00:00')
          .lte('created_at', '$today 23:59:59')
          .eq('used_own_api', false);

      final totalToday = response.length;
      final remainingUses = 3 - totalToday;

      final hasOwnApi = await hasApiKey(userId);

      return {
        'remaining_uses': remainingUses > 0 ? remainingUses : 0,
        'total_today': totalToday,
        'has_own_api': hasOwnApi,
      };
    } catch (e) {
      print('❌ Error checking daily usage: $e');
      return {
        'remaining_uses': 0,
        'total_today': 0,
        'has_own_api': false,
      };
    }
  }

  /// Lấy danh sách tất cả API keys của user
  Future<List<Map<String, dynamic>>> getAllApiKeys(String userId) async {
    try {
      final response = await _supabase
          .from('user_api_keys')
          .select('id, provider, last_used_at, added_at, is_active')
          .eq('user_id', userId)
          .order('added_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting all API keys: $e');
      return [];
    }
  }
}