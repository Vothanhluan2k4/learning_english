import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  const AudioPlayerWidget({super.key, required this.audioUrl});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _hasPlayed = false; // Track if audio has been played

  @override
  void initState() {
    super.initState();
    // Listen for audio completion
    _player.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _hasPlayed = true;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _playAudio() async {
    if (_hasPlayed) {
      // Show warning if already played
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bạn chỉ được nghe audio một lần!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _player.play(UrlSource(widget.audioUrl));
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể phát audio. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _hasPlayed ? Colors.grey.shade100 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasPlayed ? Colors.grey.shade300 : Colors.blue.shade200,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying 
                ? Icons.pause_circle 
                : (_hasPlayed ? Icons.check_circle : Icons.play_circle),
              size: 32,
              color: _hasPlayed 
                ? Colors.grey 
                : (_isPlaying ? Colors.blue : Colors.blue),
            ),
            onPressed: _isPlaying ? null : _playAudio,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasPlayed 
                    ? "Đã nghe audio" 
                    : "Nhấn để nghe audio ",
                  style: TextStyle(
                    color: _hasPlayed ? Colors.grey : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_hasPlayed) ...[
                  SizedBox(height: 4),
                  Text(
                    "Lưu ý: Bạn chỉ được nghe một lần duy nhất",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
