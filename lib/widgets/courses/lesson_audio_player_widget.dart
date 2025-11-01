import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class LessonAudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String? caption;
  final bool allowReplay; // true = ôn tập, false = test/exam

  const LessonAudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.caption,
    this.allowReplay = true,
  });

  @override
  State<LessonAudioPlayerWidget> createState() =>
      _LessonAudioPlayerWidgetState();
}

class _LessonAudioPlayerWidgetState extends State<LessonAudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _hasPlayed = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();

    _player.onDurationChanged.listen((Duration d) {
      setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((Duration p) {
      setState(() => _position = p);
    });

    _player.onPlayerStateChanged.listen((PlayerState state) {
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _player.onPlayerComplete.listen((_) {
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  Future<void> _togglePlayPause() async {
    try {
      // ✅ Nếu là test/exam mode và đã phát rồi, không cho phát lại
      if (!widget.allowReplay && _hasPlayed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bạn chỉ được nghe audio một lần!'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      if (_isPlaying) {
        await _player.pause();
      } else {
        if (_position == Duration.zero) {
          await _player.play(UrlSource(widget.audioUrl));
        } else {
          await _player.resume();
        }
      }
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không thể phát audio. Vui lòng thử lại.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() {
      _position = Duration.zero;
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTestMode = !widget.allowReplay;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _hasPlayed && isTestMode
            ? Colors.grey.shade100
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _hasPlayed && isTestMode
              ? Colors.grey.shade300
              : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Player controls
          Row(
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Progress bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                      ),
                      child: Slider(
                        value: _position.inSeconds.toDouble(),
                        max: _duration.inSeconds.toDouble(),
                        onChanged: (value) async {
                          await _player
                              .seek(Duration(seconds: value.toInt()));
                        },
                        activeColor: Colors.blue.shade700,
                        inactiveColor: Colors.grey.shade300,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Stop button
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _stop,
                child: Icon(
                  Icons.stop_circle_outlined,
                  size: 24,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),

          // ✅ Caption
          if (widget.caption != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.caption!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // ✅ File info
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.audiotrack,
                size: 16,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.audioUrl.split('/').last,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // ✅ Test mode warning
          if (isTestMode && _hasPlayed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn đã nghe audio. Không thể phát lại.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ✅ Review mode info
          if (widget.allowReplay && !isTestMode) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn có thể phát lại audio bao nhiêu lần tùy thích.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}