import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import '../config/ai_config.dart';

/// Helper for encrypting/decrypting API keys
class EncryptionHelper {
  static final enc.Key _key = _createKey();
  
  // ✅ FIXED: IV cố định (16 bytes)
  static final enc.IV _iv = enc.IV.fromUtf8('1234567890123456'); 
  
  static final enc.Encrypter _encrypter = enc.Encrypter(
    enc.AES(_key, mode: enc.AESMode.cbc),
  );

  /// Tạo Key 32 bytes từ encryption key string
  static enc.Key _createKey() {
    final keyString = AiConfig.encryptionKey;
    
    // Convert sang bytes
    List<int> keyBytes = utf8.encode(keyString);
    
    // Validation: PHẢI ĐÚNG 32 bytes
    if (keyBytes.length != 32) {
      throw ArgumentError(
        'Encryption key must be exactly 32 bytes. '
        'Current: ${keyBytes.length} bytes. '
        'Key: "$keyString"'
      );
    }
    
    debugPrint('✅ Encryption key: 32 bytes');
    return enc.Key(Uint8List.fromList(keyBytes));
  }

  /// Encrypt API key
  static String encrypt(String plainText) {
    try {
      debugPrint('🔒 Encrypting API key (length: ${plainText.length})');
      debugPrint('   First 20 chars: ${plainText.substring(0, plainText.length > 20 ? 20 : plainText.length)}...');
      
      // ✅ VALIDATE: Check input
      if (plainText.isEmpty) {
        throw ArgumentError('Cannot encrypt empty string');
      }
      if (plainText.length < 20) {
        throw ArgumentError('API key too short (min 20 chars)');
      }

      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      final result = encrypted.base64;
      
      debugPrint('✅ Encrypted successfully (length: ${result.length})');
      
      // ✅ VERIFY: Test decrypt immediately
      try {
        final testDecrypt = decrypt(result);
        if (testDecrypt != plainText) {
          throw Exception('Encryption verification failed: mismatch');
        }
        debugPrint('✅ Verification passed');
      } catch (e) {
        debugPrint('❌ Verification failed: $e');
        throw Exception('Encryption test failed: $e');
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Encryption failed: $e');
      rethrow;
    }
  }

  /// Decrypt API key
  static String decrypt(String encryptedText) {
    try {
      debugPrint('🔓 Decrypting API key (length: ${encryptedText.length})');
      
      // ✅ VALIDATE: Check if valid base64
      if (!_isValidBase64(encryptedText)) {
        throw ArgumentError('Invalid base64 format');
      }

      final encrypted = enc.Encrypted.fromBase64(encryptedText);
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);
      
      debugPrint('✅ Decrypted successfully (length: ${decrypted.length})');
      debugPrint('   First 20 chars: ${decrypted.substring(0, decrypted.length > 20 ? 20 : decrypted.length)}...');
      
      // ✅ REMOVED: Các validation không cần thiết
      // Chỉ check empty
      if (decrypted.isEmpty) {
        throw Exception('Decrypted value is empty');
      }
      
      return decrypted;
    } catch (e) {
      debugPrint('❌ Decryption failed: $e');
      debugPrint('   Encrypted text: $encryptedText');
      rethrow;
    }
  }

  /// Validate base64 format
  static bool _isValidBase64(String str) {
    try {
      final regex = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
      if (!regex.hasMatch(str)) return false;
      
      base64.decode(str);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Alias methods
  static String encryptApiKey(String plainText) => encrypt(plainText);
  static String decryptApiKey(String encryptedText) => decrypt(encryptedText);
}