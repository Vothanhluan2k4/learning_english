/// Custom exceptions cho AI services
class AiException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AiException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'AiException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Exception khi API key không hợp lệ
class AiApiKeyException extends AiException {
  AiApiKeyException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

/// Exception khi vượt quá giới hạn requests
class AiQuotaExceededException extends AiException {
  AiQuotaExceededException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

/// Exception từ AI provider (Groq, Gemini)
class AiProviderException extends AiException {
  final String provider;

  AiProviderException(this.provider, String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

/// Exception khi parse response thất bại
class AiParseException extends AiException {
  AiParseException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}