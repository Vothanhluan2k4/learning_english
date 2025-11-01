import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class MediaPlayerWidget extends StatefulWidget {
  final String mediaType; // 'image', 'audio', 'video'
  final String mediaUrl; // URL từ storage hoặc YouTube
  final String? caption;
  final bool allowReplay;

  const MediaPlayerWidget({
    required this.mediaType,
    required this.mediaUrl,
    this.caption,
    this.allowReplay = true,
    super.key,
  });

  @override
  State<MediaPlayerWidget> createState() => _MediaPlayerWidgetState();
}

class _MediaPlayerWidgetState extends State<MediaPlayerWidget> {
  late VideoPlayerController _videoController;
  late YoutubePlayerController _youtubeController;
  bool _isVideoInitialized = false;
  bool _isYouTube = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  /// ✅ Kiểm tra xem có phải YouTube URL không
  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('youtube');
  }

  /// ✅ Lấy YouTube Video ID từ URL
  String? _extractYouTubeVideoId(String url) {
    final patterns = [
      RegExp(
          r'(?:https?:\/\/)?(?:www\.)?youtube\.com\/watch\?v=([a-zA-Z0-9_-]+)'),
      RegExp(r'(?:https?:\/\/)?(?:www\.)?youtu\.be\/([a-zA-Z0-9_-]+)'),
      RegExp(r'(?:https?:\/\/)?(?:www\.)?youtube\.com\/embed\/([a-zA-Z0-9_-]+)'),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    return null;
  }

  /// ✅ Initialize media (video hoặc YouTube)
  Future<void> _initializeMedia() async {
    try {
      if (_isYouTubeUrl(widget.mediaUrl)) {
        debugPrint('📺 Initializing YouTube video: ${widget.mediaUrl}');

        final videoId = _extractYouTubeVideoId(widget.mediaUrl);
        if (videoId == null) {
          throw Exception('Cannot extract YouTube video ID');
        }

        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            showLiveFullscreenButton: true,
            enableCaption: true,
          ),
        );

        setState(() {
          _isYouTube = true;
          _isVideoInitialized = true;
        });

        debugPrint('✅ YouTube video initialized: $videoId');
      } else {
        debugPrint('📹 Initializing video from storage: ${widget.mediaUrl}');

        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.mediaUrl),
        );

        await _videoController.initialize();

        setState(() {
          _isVideoInitialized = true;
          _isYouTube = false;
        });

        debugPrint('✅ Video initialized successfully');
      }
    } catch (e) {
      debugPrint('❌ Error initializing media: $e');
      setState(() {
        _errorMessage = 'Lỗi tải video: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    if (_isYouTube) {
      _youtubeController.dispose();
    } else if (_isVideoInitialized) {
      _videoController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaType == 'image') {
      return _buildImagePlayer();
    } else if (widget.mediaType == 'audio') {
      return _buildAudioPlayer();
    } else if (widget.mediaType == 'video') {
      return _buildVideoPlayer();
    }

    return const SizedBox.shrink();
  }

  /// ✅ Image player
  Widget _buildImagePlayer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            widget.mediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      const Text('Không thể tải hình ảnh'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.caption != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.caption!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  /// ✅ Audio player
  Widget _buildAudioPlayer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.audiotrack,
            color: Colors.blue.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audio',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.caption != null)
                  Text(
                    widget.caption!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.play_circle_filled,
            color: Colors.blue.shade700,
            size: 32,
          ),
        ],
      ),
    );
  }

  /// ✅ Video player
  Widget _buildVideoPlayer() {
    if (_errorMessage != null) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade700,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isVideoInitialized) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isYouTube) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: YoutubePlayer(
              controller: _youtubeController,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              progressColors: const ProgressBarColors(
                playedColor: Colors.red,
                handleColor: Colors.redAccent,
              ),
              onReady: () {
                debugPrint('✅ YouTube player ready');
              },
              onEnded: (metadata) {
                debugPrint('✅ YouTube video ended');
              },
            ),
          ),
          if (widget.caption != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.caption!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    } else {
      // ✅ Storage video player
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: _videoController.value.aspectRatio,
                    child: VideoPlayer(_videoController),
                  ),
                  if (!_videoController.value.isPlaying)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_videoController.value.isPlaying) {
                            _videoController.pause();
                          } else {
                            _videoController.play();
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildVideoControls(),
          if (widget.caption != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.caption!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    }
  }

  /// ✅ Video controls
  Widget _buildVideoControls() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (_videoController.value.isPlaying) {
                _videoController.pause();
              } else {
                _videoController.play();
              }
            });
          },
          child: Icon(
            _videoController.value.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            color: Colors.blue.shade700,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: VideoProgressIndicator(
            _videoController,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: Colors.blue.shade700,
              bufferedColor: Colors.grey.shade300,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _formatDuration(_videoController.value.position),
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(width: 4),
        Text(
          '/',
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(width: 4),
        Text(
          _formatDuration(_videoController.value.duration),
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  /// ✅ Format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours == 0) {
      return '$minutes:$seconds';
    }
    return '$hours:$minutes:$seconds';
  }
}