

import 'package:flutter/material.dart';

class ParseFeedbackAI {

  
/// ✅ NEW: Parse ai_feedback string to Map
Map<String, dynamic> parseAiFeedbackString(String feedbackString) {
  final Map<String, dynamic> result = {};
  
  try {
    
    String content = feedbackString.trim();
    if (content.startsWith('{')) content = content.substring(1);
    if (content.endsWith('}')) content = content.substring(0, content.length - 1);
    
    // ✅ Extract numeric scores
    final scorePattern = RegExp(r'(\w+_score):\s*(\d+(?:\.\d+)?)');
    for (var match in scorePattern.allMatches(content)) {
      final key = match.group(1)!;
      final value = num.parse(match.group(2)!);
      result[key] = value;
    }
    
    // ✅ Extract detailed_feedback
    final feedbackPattern = RegExp(
      r'detailed_feedback:\s*(.+?)(?=,\s*mistakes:)',
      dotAll: false,
    );
    final feedbackMatch = feedbackPattern.firstMatch(content);
    if (feedbackMatch != null) {
      result['detailed_feedback'] = feedbackMatch.group(1)!.trim();
    }
    
    // ✅ Extract mistakes array
    final mistakesPattern = RegExp(r'mistakes:\s*\[(.*?)\]');
    final mistakesMatch = mistakesPattern.firstMatch(content);
    if (mistakesMatch != null) {
      final mistakesStr = mistakesMatch.group(1)!.trim();
      result['mistakes'] = mistakesStr.isEmpty 
          ? [] 
          : mistakesStr.split(',').map((s) => s.trim()).toList();
    } else {
      result['mistakes'] = [];
    }
    
    // ✅ Extract strengths array
    final strengthsPattern = RegExp(r'strengths:\s*\[([^\]]*)\]');
    final strengthsMatch = strengthsPattern.firstMatch(content);
    if (strengthsMatch != null) {
      final strengthsStr = strengthsMatch.group(1)!.trim();
      result['strengths'] = strengthsStr.isEmpty 
          ? [] 
          : strengthsStr.split(',').map((s) => s.trim()).toList();
    } else {
      result['strengths'] = [];
    }
    
    // ✅ Extract provider
    final providerPattern = RegExp(r'provider:\s*(\w+)');
    final providerMatch = providerPattern.firstMatch(content);
    if (providerMatch != null) {
      result['provider'] = providerMatch.group(1)!;
    }
    
    // ✅ Extract speaking_mode
    final modePattern = RegExp(r'speaking_mode:\s*(\w+)');
    final modeMatch = modePattern.firstMatch(content);
    if (modeMatch != null) {
      result['speaking_mode'] = modeMatch.group(1)!;
    }
    
    
  } catch (e, stack) {
    debugPrint('❌ Error parsing: $e');
    debugPrint('Stack: $stack');
  }
  
  return result;
}
}