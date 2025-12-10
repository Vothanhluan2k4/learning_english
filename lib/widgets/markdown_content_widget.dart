// lib/widgets/markdown_syntax_highlighter.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' as highlight;
import 'package:url_launcher/url_launcher.dart';

/// ✅ Syntax Highlighter for code blocks
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

/// ✅ Markdown Content Widget with custom styling
class MarkdownContentWidget extends StatelessWidget {
  final String content;
  final double fontSize;
  final Color? textColor;
  final bool selectable;

  const MarkdownContentWidget({
    required this.content,
    this.fontSize = 16,
    this.textColor,
    this.selectable = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final baseTextStyle = TextStyle(
      fontSize: fontSize,
      color: textColor ?? Colors.black87,
      height: 1.5,
    );

    return MarkdownBody(
      data: content,
      selectable: selectable,
      styleSheet: MarkdownStyleSheet(
        // Paragraph
        p: baseTextStyle,
        
        // Headings
        h1: baseTextStyle.copyWith(
          fontSize: fontSize * 1.8,
          fontWeight: FontWeight.bold,
        ),
        h2: baseTextStyle.copyWith(
          fontSize: fontSize * 1.6,
          fontWeight: FontWeight.bold,
        ),
        h3: baseTextStyle.copyWith(
          fontSize: fontSize * 1.4,
          fontWeight: FontWeight.bold,
        ),
        h4: baseTextStyle.copyWith(
          fontSize: fontSize * 1.2,
          fontWeight: FontWeight.bold,
        ),
        h5: baseTextStyle.copyWith(
          fontSize: fontSize * 1.1,
          fontWeight: FontWeight.bold,
        ),
        h6: baseTextStyle.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
        
        // Text styles
        strong: baseTextStyle.copyWith(
          fontWeight: FontWeight.bold,
        ),
        em: baseTextStyle.copyWith(
          fontStyle: FontStyle.italic,
        ),
        del: baseTextStyle.copyWith(
          decoration: TextDecoration.lineThrough,
        ),
        
        // Links
        a: baseTextStyle.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        
        // Code
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize * 0.9,
          backgroundColor: Colors.grey.shade200,
          color: Colors.red.shade700,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        
        // Lists
        listBullet: baseTextStyle.copyWith(
          fontSize: fontSize * 0.8,
        ),
        
        // Blockquote
        blockquote: baseTextStyle.copyWith(
          color: Colors.grey.shade700,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Colors.grey.shade400,
              width: 4,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        
        // Table
        tableHead: baseTextStyle.copyWith(
          fontWeight: FontWeight.bold,
        ),
        tableBody: baseTextStyle,
        tableBorder: TableBorder.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        tableCellsPadding: const EdgeInsets.all(8),
        
        // Horizontal rule
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade400,
              width: 1,
            ),
          ),
        ),
      ),
      
      // Syntax highlighting for code blocks
      syntaxHighlighter: MarkdownSyntaxHighlighter(),
      
      // Handle link taps
      onTapLink: (text, href, title) async {
        if (href != null) {
          final uri = Uri.parse(href);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }
}