// lib/widgets/markdown_syntax_highlighter.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' as highlight;

class MarkdownSyntaxHighlighter extends SyntaxHighlighter {
  @override
  TextSpan format(String source) {
    final result = highlight.highlight.parse(source, autoDetection: true);
    return TextSpan(
      style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: Colors.white),
      children: result.nodes?.map((node) {
        return TextSpan(
          text: node.value,
          style: TextStyle(color: _getColor(node.className)),
        );
      }).toList(),
    );
  }

  Color _getColor(String? className) {
    switch (className) {
      case 'keyword': return const Color(0xFFCC7832);
      case 'string':  return const Color(0xFF6A8759);
      case 'number':  return const Color(0xFF6897BB);
      case 'comment': return const Color(0xFF808080);
      case 'function':return const Color(0xFFFFC66D);
      case 'class':   return const Color(0xFFA9B7C6);
      case 'variable':return const Color(0xFF9876AA);
      default:        return Colors.white;
    }
  }
}