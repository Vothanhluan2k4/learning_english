import 'package:flutter/material.dart';
import 'dart:async';

class WritingEditorWidget extends StatefulWidget {
  final String? initialText;
  final int? minWords;
  final int? maxWords;
  final String? guideline;
  final Function(String)? onTextChanged;
  final VoidCallback? onSubmit;
  final bool readOnly;

  const WritingEditorWidget({
    super.key,
    this.initialText,
    this.minWords,
    this.maxWords,
    this.guideline,
    this.onTextChanged,
    this.onSubmit,
    this.readOnly = false,
  });

  @override
  State<WritingEditorWidget> createState() => _WritingEditorWidgetState();
}

class _WritingEditorWidgetState extends State<WritingEditorWidget> {
  late TextEditingController _controller;
  Timer? _debounce;
  int _wordCount = 0;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _updateWordCount();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(WritingEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // ✅ Only update controller if initialText actually changed
    if (widget.initialText != oldWidget.initialText) {
      final currentText = _controller.text;
      final newText = widget.initialText ?? '';
      
      // Only update if different to avoid cursor jump
      if (currentText != newText) {
        _controller.text = newText;
        _updateWordCount();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _updateWordCount();
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (widget.onTextChanged != null && !widget.readOnly) {
        widget.onTextChanged!(_controller.text);
      }
    });
  }

  void _updateWordCount() {
    final text = _controller.text;
    
    if (text.trim().isEmpty) {
      setState(() {
        _wordCount = 0;
        _isValid = _checkValid(0);
      });
      return;
    }
    
    // ✅ Same logic as AiGradingService.countWords()
    String cleaned = text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces/newlines/tabs with single space
        .replaceAll(RegExp(r"[^\w\s'-]"), ' '); // Remove special chars except apostrophe, hyphen
    
    final words = cleaned
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .length;
    
    setState(() {
      _wordCount = words;
      _isValid = _checkValid(words);
    });
  }

  bool _checkValid(int words) {
    if (widget.minWords != null && words < widget.minWords!) {
      return false;
    }
    if (widget.maxWords != null && words > widget.maxWords!) {
      return false;
    }
    return true;
  }

  Color _getWordCountColor() {
    if (!_isValid) return Colors.red;
    
    if (widget.minWords != null && _wordCount < widget.minWords!) {
      return Colors.orange;
    }
    
    return Colors.green;
  }

  String _getValidationMessage() {
    if (widget.minWords != null && _wordCount < widget.minWords!) {
      return 'Cần thêm ${widget.minWords! - _wordCount} từ';
    }
    if (widget.maxWords != null && _wordCount > widget.maxWords!) {
      return 'Vượt quá ${_wordCount - widget.maxWords!} từ';
    }
    return 'Đủ số từ yêu cầu';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Guideline
        if (widget.guideline != null && widget.guideline!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.guideline!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade900,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Word count indicator
        Row(
          children: [
            Icon(Icons.article_outlined, size: 18, color: _getWordCountColor()),
            const SizedBox(width: 8),
            Text(
              'Số từ: ',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            Text(
              '$_wordCount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _getWordCountColor(),
              ),
            ),
            if (widget.minWords != null || widget.maxWords != null) ...[
              Text(
                ' / ',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              Text(
                widget.minWords != null && widget.maxWords != null
                    ? '${widget.minWords}-${widget.maxWords}'
                    : widget.minWords != null
                        ? 'tối thiểu ${widget.minWords}'
                        : 'tối đa ${widget.maxWords}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isValid ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isValid ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Text(
                _getValidationMessage(),
                style: TextStyle(
                  fontSize: 12,
                  color: _isValid ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Text field
        TextField(
          controller: _controller,
          readOnly: widget.readOnly,
          maxLines: 15,
          minLines: 10,
          style: const TextStyle(fontSize: 16, height: 1.6),
          decoration: InputDecoration(
            hintText: widget.readOnly 
                ? 'Bài viết của bạn' 
                : 'Nhập câu trả lời của bạn...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            filled: true,
            fillColor: widget.readOnly ? Colors.grey.shade100 : Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 16),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: widget.readOnly 
                ? widget.onSubmit 
                : (_isValid && _wordCount > 0 ? widget.onSubmit : null),
            icon: Icon(widget.readOnly ? Icons.visibility : Icons.send),
            label: Text(
              widget.readOnly ? 'Xem kết quả' : 'Gửi bài chấm điểm',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.readOnly ? Colors.orange : Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}