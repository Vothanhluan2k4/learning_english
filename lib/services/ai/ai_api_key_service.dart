import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/encryption_helper.dart';
import '../../core/errors/ai_exceptions.dart';

class AiApiKeyService {
  final _supabase = SupabaseConfig.client;

  /// ✅ FIXED: Get API key by ID - Simplified validation
  Future<Map<String, dynamic>?> getApiKeyById(String apiKeyId) async {
    try {
      debugPrint('🔍 Getting API key by ID: $apiKeyId');
      
      final response = await _supabase
          .from('user_api_keys')
          .select('id, provider, api_key_encrypted, last_used_at')
          .eq('id', apiKeyId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ API key not found or inactive');
        return null;
      }

      final encryptedKey = response['api_key_encrypted'] as String;
      debugPrint('📦 Encrypted key length: ${encryptedKey.length}');

      // ✅ Just decrypt, let EncryptionHelper handle validation
      final decryptedKey = EncryptionHelper.decrypt(encryptedKey);

      debugPrint('✅ Got API key for provider: ${response['provider']}');
      debugPrint('🔑 Decrypted key length: ${decryptedKey.length}');

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

      final decryptedKey = EncryptionHelper.decrypt(response['api_key_encrypted']);

      return {
        'id': response['id'],
        'provider': response['provider'],
        'api_key': decryptedKey,
        'last_used_at': response['last_used_at'],
      };
    } catch (e) {
      debugPrint('❌ Error getting user API key: $e');
      throw AiApiKeyException('Không thể lấy API key: $e');
    }
  }

  /// Lưu/Cập nhật API key
  Future<void> upsertApiKey({
    required String userId,
    required String provider,
    required String apiKey,
  }) async {
    try {
      debugPrint('💾 Saving API key for provider: $provider');
      debugPrint('🔑 Plain key length: ${apiKey.length}');
      
      // Encrypt API key
      final encryptedKey = EncryptionHelper.encrypt(apiKey);

      // Check if exists
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
        
        debugPrint('✅ Updated existing API key');
      } else {
        // INSERT
        await _supabase.from('user_api_keys').insert({
          'user_id': userId,
          'provider': provider,
          'api_key_encrypted': encryptedKey,
        });
        
        debugPrint('✅ Inserted new API key');
      }

    } catch (e) {
      debugPrint('❌ Error saving API key: $e');
      throw AiApiKeyException('Không thể lưu API key: $e');
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
      debugPrint('❌ Error checking API key: $e');
      return false;
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

      debugPrint('✅ API key deleted: $provider');
    } catch (e) {
      debugPrint('❌ Error deleting API key: $e');
      throw AiApiKeyException('Không thể xóa API key: $e');
    }
  }

  /// ✅ Check daily usage
  Future<Map<String, dynamic>> checkDailyUsage(String userId) async {
    try {
      final result = await _supabase.rpc(
        'check_daily_usage_limit',
        params: {'p_user_id': userId},
      ).single();

      return {
        'remaining_uses': result['remaining_uses'] as int,
        'total_today': result['total_today'] as int,
        'has_own_api': result['has_own_api'] as bool,
      };
    } catch (e) {
      debugPrint('❌ Error checking daily usage: $e');
      return {
        'remaining_uses': 0,
        'total_today': 0,
        'has_own_api': false,
      };
    }
  }

  /// ✅ Get all API keys
  Future<List<Map<String, dynamic>>> getAllApiKeys(String userId) async {
    try {
      final response = await _supabase
          .from('user_api_keys')
          .select('id, provider, is_active, last_used_at, added_at')
          .eq('user_id', userId)
          .order('added_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting all API keys: $e');
      return [];
    }
  }
}