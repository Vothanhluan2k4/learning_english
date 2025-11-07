import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import '../config/ai_config.dart';

/// Helper for encrypting/decrypting API keys
class EncryptionHelper {
  static final Key _key = _createKey();
  static final IV _iv = IV.fromLength(16);
  static final Encrypter _encrypter = Encrypter(AES(_key, mode: AESMode.cbc));

  /// Tạo Key 32 bytes từ encryption key string
  static Key _createKey() {
    final keyString = AiConfig.encryptionKey;
    
    // Convert sang bytes
    final keyBytes = utf8.encode(keyString);
    
    // Validation
    if (keyBytes.length != 32) {
      throw ArgumentError(
        'Encryption key must be exactly 32 bytes. '
        'Current: ${keyBytes.length} bytes. '
        'Key: "$keyString"'
      );
    }
    
    return Key(Uint8List.fromList(keyBytes));
  }

  /// Encrypt API key
  static String encrypt(String plainText) {
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      throw Exception('Failed to encrypt: $e');
    }
  }

  /// Decrypt API key
  static String decrypt(String encryptedText) {
    try {
      final encrypted = Encrypted.fromBase64(encryptedText);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      throw Exception('Failed to decrypt: $e');
    }
  }
}