import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class AdaptiveVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? caption;
  final bool allowReplay;

  const AdaptiveVideoPlayer({
    required this.videoUrl,
    this.caption,
    this.allowReplay = true,
    super.key,
  });

  @override
  State<AdaptiveVideoPlayer> createState() => _AdaptiveVideoPlayerState();
}

class _AdaptiveVideoPlayerState extends State<AdaptiveVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  YoutubePlayerController? _youtubeController;
  bool _isYouTube = false;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  /// 🔍 Kiểm tra xem có phải YouTube URL không
  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') || 
           url.contains('youtu.be') ||
           url.contains('www.youtube.com');
  }

  /// 🎬 Lấy YouTube Video ID từ URL
  String? _extractYouTubeId(String url) {
    return YoutubePlayer.convertUrlToId(url);
  }

  /// ✅ Khởi tạo player tùy theo loại URL
  Future<void> _initializePlayer() async {
    try {
      _isYouTube = _isYouTubeUrl(widget.videoUrl);

      if (_isYouTube) {
        // 📺 YouTube Player
        final videoId = _extractYouTubeId(widget.videoUrl);
        
        if (videoId == null) {
          setState(() {
            _errorMessage = 'Không thể trích xuất YouTube Video ID';
          });
          return;
        }

        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            loop: widget.allowReplay,
            enableCaption: true,
          ),
        );

        setState(() => _isInitialized = true);
        
      } else {
        // 🎥 Storage Video Player
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );

        await _videoController!.initialize();

        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: widget.allowReplay,
          aspectRatio: _videoController!.value.aspectRatio,
          allowFullScreen: true,
          allowMuting: true,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.red.shade200,
          ),
          placeholder: Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          errorBuilder: (context, errorMessage) {
            return _buildErrorWidget('Lỗi tải video: $errorMessage');
          },
        );

        setState(() => _isInitialized = true);
      }

      debugPrint('✅ Video initialized: ${_isYouTube ? "YouTube" : "Storage"}');
      
    } catch (e) {
      debugPrint('❌ Error initializing video: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorWidget(_errorMessage!);
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _isYouTube 
              ? _buildYouTubePlayer()
              : _buildStoragePlayer(),
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

  /// 📺 YouTube Player Widget
  Widget _buildYouTubePlayer() {
    return YoutubePlayer(
      controller: _youtubeController!,
      showVideoProgressIndicator: true,
      progressIndicatorColor: Colors.red,
      progressColors: const ProgressBarColors(
        playedColor: Colors.red,
        handleColor: Colors.redAccent,
      ),
      onReady: () => debugPrint('✅ YouTube player ready'),
      onEnded: (_) => debugPrint('✅ YouTube video ended'),
    );
  }

  /// 🎥 Storage Video Player Widget
  Widget _buildStoragePlayer() {
    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }

  /// ⏳ Loading Widget
  Widget _buildLoadingWidget() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Đang tải video...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// ❌ Error Widget
  Widget _buildErrorWidget(String message) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
            const SizedBox(height: 12),
            Text(
              'Lỗi phát video',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}