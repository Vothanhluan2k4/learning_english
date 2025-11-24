import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final int remainingPlays; // ✅ NEW: Số lần còn lại được nghe
  final VoidCallback? onPlayStart; // ✅ NEW: Callback khi bắt đầu phát
  final VoidCallback? onPlayComplete; // ✅ NEW: Callback khi audio kết thúc

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.remainingPlays = 2, // ✅ Default 2 lần
    this.onPlayStart,
    this.onPlayComplete,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    
    // Listen to player state changes
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Listen for duration changes
    _player.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    // Listen for position changes
    _player.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    // Listen for audio completion
    _player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        widget.onPlayComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (widget.remainingPlays <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.block, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Bạn đã hết lượt nghe audio!'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      return;
    }

    try {
      // ✅ Notify parent that play started (count as 1 play)
      widget.onPlayStart?.call();
      
      await _player.play(UrlSource(widget.audioUrl));
      
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Không thể phát audio. Vui lòng thử lại.'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pauseAudio() async {
    await _player.pause();
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.remainingPlays <= 0;
    final canPlay = widget.remainingPlays > 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDisabled
            ? [Colors.grey.shade200, Colors.grey.shade100]
            : [Colors.purple.shade50, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDisabled ? Colors.grey.shade300 : Colors.purple.shade200,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Header: Icon + Title + Remaining plays
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDisabled 
                    ? Colors.grey.shade300 
                    : Colors.purple.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.headphones,
                  color: isDisabled 
                    ? Colors.grey.shade600 
                    : Colors.purple.shade700,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDisabled ? 'Đã hết lượt nghe' : 'Audio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDisabled 
                          ? Colors.grey.shade700 
                          : Colors.purple.shade900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: isDisabled ? Colors.grey : Colors.orange.shade700,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Còn ${widget.remainingPlays}/2 lượt nghe',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDisabled ? Colors.grey : Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ✅ Play count badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.remainingPlays == 2
                    ? Colors.green.shade100
                    : widget.remainingPlays == 1
                      ? Colors.orange.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.remainingPlays == 2
                      ? Colors.green.shade300
                      : widget.remainingPlays == 1
                        ? Colors.orange.shade300
                        : Colors.red.shade300,
                  ),
                ),
                child: Text(
                  '${widget.remainingPlays}x',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.remainingPlays == 2
                      ? Colors.green.shade700
                      : widget.remainingPlays == 1
                        ? Colors.orange.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // ✅ Progress bar (only show when playing)
          if (_isPlaying || _position.inSeconds > 0) ...[
            Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Colors.purple.shade700,
                    inactiveTrackColor: Colors.purple.shade200,
                    thumbColor: Colors.purple.shade700,
                    overlayColor: Colors.purple.shade700.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble(),
                    max: _duration.inMilliseconds.toDouble() > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1.0,
                    onChanged: null, // ✅ Disable seeking
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
          ],
          
          // ✅ Play/Pause button
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canPlay
                  ? (_isPlaying ? _pauseAudio : _playAudio)
                  : null,
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDisabled
                      ? Colors.grey.shade300
                      : (_isPlaying 
                        ? Colors.purple.shade100 
                        : Colors.purple.shade700.withOpacity(0.1)),
                  ),
                  child: Icon(
                    _isPlaying 
                      ? Icons.pause_circle_filled 
                      : (isDisabled 
                        ? Icons.block 
                        : Icons.play_circle_filled),
                    size: 48,
                    color: isDisabled
                      ? Colors.grey.shade600
                      : (_isPlaying 
                        ? Colors.purple.shade700 
                        : Colors.purple.shade700),
                  ),
                ),
              ),
            ),
          ),
          
          SizedBox(height: 12),
          
          // ✅ Warning message
          if (!isDisabled)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.remainingPlays == 2
                        ? 'Bạn được nghe audio 2 lần. Hãy tập trung!'
                        : 'Đây là lần nghe cuối cùng!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
