import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/ai_config.dart'; // ✅ Use existing config

class GroqSpeechService {
  // ✅ Use API key from AiConfig
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  
  late final Dio _dio;

  GroqSpeechService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Authorization': 'Bearer ${AiConfig.groqApiKey}', 
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  /// Convert audio file to text using Groq Whisper
  Future<String> transcribeAudio(String audioPath) async {
    try {
      debugPrint('🎤 Transcribing audio: $audioPath');

      final audioFile = File(audioPath);
      
      if (!audioFile.existsSync()) {
        throw Exception('Audio file not found: $audioPath');
      }

      final fileSize = audioFile.lengthSync();
      debugPrint('📁 File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // Check file size limit (25MB for Groq)
      if (fileSize > 25 * 1024 * 1024) {
        throw Exception('File quá lớn. Giới hạn 25MB.');
      }

      // Create multipart request
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioPath,
          filename: 'audio.m4a',
        ),
        'model': 'whisper-large-v3-turbo', 
        'language': 'en', // English
        'response_format': 'json',
        'temperature': 0.0, // More accurate
      });

      debugPrint('📤 Uploading to Groq Whisper...');
      
      final response = await _dio.post(
        '/audio/transcriptions',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        final text = response.data['text'] as String? ?? '';
        debugPrint('✅ Transcription: "$text"');
        
        if (text.trim().isEmpty) {
          debugPrint('⚠️ Empty transcription received');
          return '';
        }
        
        return text.trim();
      } else {
        throw Exception('Groq API error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('❌ Dio error: ${e.type}');
      debugPrint('❌ Message: ${e.message}');
      debugPrint('❌ Response: ${e.response?.data}');
      
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Hết thời gian kết nối. Vui lòng kiểm tra internet.');
      } else if (e.response?.statusCode == 401) {
        throw Exception('API key không hợp lệ. Vui lòng kiểm tra lại trong ai_config.dart');
      } else if (e.response?.statusCode == 429) {
        throw Exception('Vượt quá giới hạn. Vui lòng đợi một chút.');
      } else if (e.response?.statusCode == 413) {
        throw Exception('File audio quá lớn. Vui lòng ghi âm ngắn hơn.');
      } else {
        throw Exception('Lỗi chuyển đổi âm thanh: ${e.response?.data?['error']?['message'] ?? e.message}');
      }
    } catch (e) {
      debugPrint('❌ Error transcribing audio: $e');
      rethrow;
    }
  }

  /// Get available Whisper models
  Future<List<String>> getAvailableModels() async {
    try {
      final response = await _dio.get('/models');
      
      if (response.statusCode == 200) {
        final models = (response.data['data'] as List)
            .map((m) => m['id'] as String)
            .where((id) => id.contains('whisper'))
            .toList();
        
        debugPrint('📋 Available Whisper models: $models');
        return models;
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching models: $e');
      return [];
    }
  }

  /// Check if API key is valid
  Future<bool> validateApiKey() async {
    try {
      final response = await _dio.get('/models');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ API key validation failed: $e');
      return false;
    }
  }
}