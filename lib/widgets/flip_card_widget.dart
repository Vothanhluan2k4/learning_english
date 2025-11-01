import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learning_english/models/word.dart';

class FlipCardWidget extends StatefulWidget {
  final Word word;
  final VoidCallback? onDelete;

  const FlipCardWidget({super.key, required this.word, this.onDelete});

  @override
  State<FlipCardWidget> createState() => _FlipCardWidgetState();
}

class _FlipCardWidgetState extends State<FlipCardWidget> {
  // State variables
  late final FlutterTts _tts;

  // Lifecycle methods
  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _initializeTts();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // TTS initialization
  Future<void> _initializeTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  // UI rendering
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: FlipCard(
        front: _buildFrontSide(),
        back: _buildBackSide(),
      ),
    );
  }

  Widget _buildFrontSide() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.word.word,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (widget.word.transcription != null)
            Text(
              widget.word.transcription!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => _tts.speak(widget.word.word),
          ),
        ],
      ),
    );
  }

  Widget _buildBackSide() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 200,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Định nghĩa: ${widget.word.define}',
              style: const TextStyle(fontSize: 18),
            ),
            if (widget.word.example != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Ví dụ: ${widget.word.example}'),
              ),
            if (widget.word.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Ghi chú: ${widget.word.note}'),
              ),
            if (widget.word.pictureUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Image.network(
                  widget.word.pictureUrl!,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) => const Text('Lỗi tải hình ảnh'),
                ),
              ),
            if (widget.onDelete != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}