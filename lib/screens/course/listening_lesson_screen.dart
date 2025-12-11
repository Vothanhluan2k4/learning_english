import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/lesson_course.dart';
import '../../models/lesson_section.dart';
import '../../models/section_media.dart';
import '../../services/course/lesson_course_service.dart';
import '../../services/course/lesson_section_service.dart';
import '../../services/course/user_attempt_service.dart';
import 'course_quiz_content.dart';

class ListeningLessonScreen extends StatefulWidget {
  final String lessonId;

  const ListeningLessonScreen({
    required this.lessonId,
    super.key,
  });

  @override
  State<ListeningLessonScreen> createState() => _ListeningLessonScreenState();
}

class _ListeningLessonScreenState extends State<ListeningLessonScreen>
    with AutomaticKeepAliveClientMixin { // ✅ ADD: Keep state alive
  final _lessonService = LessonCourseService();
  final _sectionService = LessonSectionService();
  final _attemptService = UserAttemptService();
  final _scrollController = ScrollController();

  late Future<Map<String, dynamic>> _dataFuture;

  // ✅ Centralized Audio Players Management
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, PlayerState> _playerStates = {};
  final Map<String, Duration> _durations = {};
  final Map<String, Duration> _positions = {};
  final Map<String, double> _playbackSpeeds = {};
  final Map<String, bool> _isMuted = {};
  final Map<String, bool> _isLoading = {}; // ✅ ADD: Loading state

  @override
  bool get wantKeepAlive => true; // ✅ Keep state alive

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    // Stop and dispose all audio players
    for (var player in _audioPlayers.values) {
      player.stop();
      player.dispose();
    }
    _audioPlayers.clear();
    _scrollController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadData() async {
    try {
      debugPrint('🎧 Loading listening lesson: ${widget.lessonId}');

      final lesson = await _lessonService.fetchLessonById(widget.lessonId);
      final fullContent = await _sectionService.fetchFullLessonContent(widget.lessonId);

      return {
        'lesson': lesson,
        'content': fullContent,
      };
    } catch (e) {
      debugPrint('❌ Error loading listening lesson: $e');
      rethrow;
    }
  }

  // ✅ Get or create audio player (optimized)
  AudioPlayer _getAudioPlayer(String mediaId) {
    if (!_audioPlayers.containsKey(mediaId)) {
      final player = AudioPlayer();
      
      // ✅ Set player mode to optimize for streaming
      player.setReleaseMode(ReleaseMode.stop);
      
      _audioPlayers[mediaId] = player;
      _playerStates[mediaId] = PlayerState.stopped;
      _durations[mediaId] = Duration.zero;
      _positions[mediaId] = Duration.zero;
      _playbackSpeeds[mediaId] = 1.0;
      _isMuted[mediaId] = false;
      _isLoading[mediaId] = false;

      // Setup listeners (optimized - only update when needed)
      player.onPlayerStateChanged.listen((state) {
        if (mounted && _playerStates[mediaId] != state) {
          setState(() {
            _playerStates[mediaId] = state;
            if (state == PlayerState.playing) {
              _isLoading[mediaId] = false;
            }
          });
        }
      });

      player.onDurationChanged.listen((duration) {
        if (mounted && _durations[mediaId] != duration) {
          setState(() => _durations[mediaId] = duration);
        }
      });

      player.onPositionChanged.listen((position) {
        if (mounted) {
          // ✅ Only update every 100ms to reduce rebuilds
          final currentPos = _positions[mediaId] ?? Duration.zero;
          if ((position - currentPos).inMilliseconds.abs() > 100) {
            setState(() => _positions[mediaId] = position);
          }
        }
      });

      player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _positions[mediaId] = Duration.zero;
            _playerStates[mediaId] = PlayerState.stopped;
            _isLoading[mediaId] = false;
          });
        }
      });
    }
    return _audioPlayers[mediaId]!;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bài nghe',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Lỗi: ${snapshot.error}'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() => _dataFuture = _loadData()),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data;
          final lesson = data?['lesson'] as LessonCourse?;
          final fullContent = data?['content'] as Map<String, dynamic>? ?? {};
          final sections = fullContent['sections'] as List? ?? [];
          final content = fullContent['content'] as Map<String, dynamic>? ?? {};

          final textSections = <LessonSection>[];
          final audioSections = <LessonSection>[];
          final quizSections = <LessonSection>[];

          for (var section in sections) {
            switch (section.sectionType) {
              case 'text':
                textSections.add(section);
                break;
              case 'audio':
                audioSections.add(section);
                break;
              case 'quiz':
                quizSections.add(section);
                break;
            }
          }

          final allQuestions = <Map<String, dynamic>>[];
          for (var section in quizSections) {
            final sectionContent = content[section.id] as Map?;
            final questions = sectionContent?['questions'] as List? ?? [];
            allQuestions.addAll(questions.cast());
          }

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            // ✅ Reduce physics calculations
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ 1. Lesson Info
                if (lesson != null) ...[
                  RepaintBoundary( // ✅ Prevent unnecessary repaints
                    child: _buildLessonHeader(lesson),
                  ),
                  const SizedBox(height: 24),
                ],

                // ✅ 2. Instruction
                if (textSections.isNotEmpty) ...[
                  RepaintBoundary(
                    child: _buildSectionHeader(
                      icon: Icons.info_outline,
                      title: 'Hướng dẫn',
                      count: textSections.length,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...textSections.map((section) {
                    return RepaintBoundary(
                      key: ValueKey(section.id), // ✅ Stable key
                      child: _buildTextSection(section),
                    );
                  }).toList(),
                  const SizedBox(height: 24),
                ],

                // ✅ 3. Audio Sections (OPTIMIZED)
                if (audioSections.isNotEmpty) ...[
                  RepaintBoundary(
                    child: _buildSectionHeader(
                      icon: Icons.headphones,
                      title: 'Audio',
                      count: audioSections.length,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...audioSections.map((section) {
                    final sectionContent = content[section.id] as Map?;
                    final medias = sectionContent?['medias'] as List? ?? [];
                    
                    return RepaintBoundary(
                      key: ValueKey(section.id), // ✅ Stable key
                      child: _buildAudioSection(section, medias.cast()),
                    );
                  }).toList(),
                  const SizedBox(height: 24),
                ],

                // ✅ 4. Divider
                if (audioSections.isNotEmpty && allQuestions.isNotEmpty) ...[
                  Divider(thickness: 2, color: Colors.grey.shade300, height: 40),
                ],

                // ✅ 5. Questions
                if (allQuestions.isNotEmpty) ...[
                  RepaintBoundary(
                    child: _buildSectionHeader(
                      icon: Icons.quiz,
                      title: 'Câu hỏi',
                      count: allQuestions.length,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RepaintBoundary(
                    child: CourseQuizContent(
                      lessonId: widget.lessonId,
                      questions: allQuestions,
                      attemptService: _attemptService,
                      sectionService: _sectionService,
                      targetScore: _getTargetScore(lesson),
                      totalQuestions: allQuestions.length,
                    ),
                  ),
                ],

                if (textSections.isEmpty && audioSections.isEmpty && allQuestions.isEmpty) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Không có nội dung',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// ✅ Build Audio Section (OPTIMIZED)
  Widget _buildAudioSection(LessonSection section, List<SectionMedia> medias) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (medias.isNotEmpty)
            ...medias.map((media) {
              return Padding(
                key: ValueKey(media.id), // ✅ Stable key
                padding: const EdgeInsets.only(bottom: 16),
                child: _AudioPlayerWidget(
                  mediaId: media.id,
                  audioUrl: media.mediaUrl,
                  caption: media.caption ?? section.sectionTitle,
                  player: _getAudioPlayer(media.id),
                  playerState: _playerStates[media.id] ?? PlayerState.stopped,
                  duration: _durations[media.id] ?? Duration.zero,
                  position: _positions[media.id] ?? Duration.zero,
                  playbackSpeed: _playbackSpeeds[media.id] ?? 1.0,
                  isMuted: _isMuted[media.id] ?? false,
                  isLoading: _isLoading[media.id] ?? false,
                  onTogglePlayPause: () => _togglePlayPause(_getAudioPlayer(media.id), media.id, media.mediaUrl),
                  onStop: () => _stop(_getAudioPlayer(media.id), media.id),
                  onSkip: (seconds) => _skip(_getAudioPlayer(media.id), media.id, seconds),
                  onChangeSpeed: (speed) => _changeSpeed(_getAudioPlayer(media.id), media.id, speed),
                  onToggleMute: () => _toggleMute(_getAudioPlayer(media.id), media.id),
                  onReplay: () => _replay(_getAudioPlayer(media.id)),
                  onSeek: (position) => _getAudioPlayer(media.id).seek(position),
                ),
              );
            }).toList()
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Không có audio',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ✅ Audio Controls (optimized - no setState in fast operations)
  Future<void> _togglePlayPause(AudioPlayer player, String mediaId, String audioUrl) async {
    try {
      final state = _playerStates[mediaId] ?? PlayerState.stopped;
      final position = _positions[mediaId] ?? Duration.zero;

      if (state == PlayerState.playing) {
        await player.pause();
      } else {
        setState(() => _isLoading[mediaId] = true);
        
        if (position == Duration.zero || state == PlayerState.stopped) {
          await player.play(UrlSource(audioUrl));
        } else {
          await player.resume();
        }
      }
    } catch (e) {
      debugPrint('❌ Error toggling play/pause: $e');
      if (mounted) {
        setState(() => _isLoading[mediaId] = false);
      }
    }
  }

  Future<void> _stop(AudioPlayer player, String mediaId) async {
    await player.stop();
    if (mounted) {
      setState(() {
        _positions[mediaId] = Duration.zero;
        _playerStates[mediaId] = PlayerState.stopped;
        _isLoading[mediaId] = false;
      });
    }
  }

  Future<void> _skip(AudioPlayer player, String mediaId, int seconds) async {
    final position = _positions[mediaId] ?? Duration.zero;
    final duration = _durations[mediaId] ?? Duration.zero;
    final newPosition = position + Duration(seconds: seconds);

    if (newPosition < Duration.zero) {
      await player.seek(Duration.zero);
    } else if (newPosition > duration) {
      await player.seek(duration);
    } else {
      await player.seek(newPosition);
    }
  }

  Future<void> _changeSpeed(AudioPlayer player, String mediaId, double speed) async {
    await player.setPlaybackRate(speed);
    if (mounted) {
      setState(() => _playbackSpeeds[mediaId] = speed);
    }
  }

  Future<void> _toggleMute(AudioPlayer player, String mediaId) async {
    final isMuted = _isMuted[mediaId] ?? false;
    await player.setVolume(!isMuted ? 0.0 : 1.0);
    if (mounted) {
      setState(() => _isMuted[mediaId] = !isMuted);
    }
  }

  Future<void> _replay(AudioPlayer player) async {
    await player.seek(Duration.zero);
    await player.resume();
  }

  // ... (other builder methods remain the same - add RepaintBoundary where needed)
  
  Widget _buildLessonHeader(LessonCourse lesson) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.headphones, color: Colors.purple.shade700, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.lessonName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900,
                  ),
                ),
                if (lesson.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    lesson.description!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection(LessonSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.sectionTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 12),
          if (section.content != null && section.content!.isNotEmpty)
            MarkdownBody(
              data: section.content!,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 15, height: 1.8, color: Colors.black87),
                h1: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                strong: const TextStyle(fontWeight: FontWeight.bold),
                em: const TextStyle(fontStyle: FontStyle.italic),
                blockquote: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                blockquoteDecoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border(left: BorderSide(color: Colors.blue.shade300, width: 4)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _getTargetScore(LessonCourse? lesson) {
    if (lesson == null) return 50.0;
    return lesson.targetScore;
  }
}

// ✅ NEW: Separate Stateless Audio Player Widget (prevent unnecessary rebuilds)
class _AudioPlayerWidget extends StatelessWidget {
  final String mediaId;
  final String audioUrl;
  final String caption;
  final AudioPlayer player;
  final PlayerState playerState;
  final Duration duration;
  final Duration position;
  final double playbackSpeed;
  final bool isMuted;
  final bool isLoading;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onStop;
  final Function(int) onSkip;
  final Function(double) onChangeSpeed;
  final VoidCallback onToggleMute;
  final VoidCallback onReplay;
  final Function(Duration) onSeek;

  const _AudioPlayerWidget({
    required this.mediaId,
    required this.audioUrl,
    required this.caption,
    required this.player,
    required this.playerState,
    required this.duration,
    required this.position,
    required this.playbackSpeed,
    required this.isMuted,
    required this.isLoading,
    required this.onTogglePlayPause,
    required this.onStop,
    required this.onSkip,
    required this.onChangeSpeed,
    required this.onToggleMute,
    required this.onReplay,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.purple.shade700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.1),
            primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Caption
          Row(
            children: [
              Icon(Icons.headphones, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  caption,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: primaryColor,
                  inactiveTrackColor: primaryColor.withOpacity(0.3),
                  thumbColor: primaryColor,
                  overlayColor: primaryColor.withOpacity(0.2),
                ),
                child: Slider(
                  value: position.inMilliseconds.toDouble(),
                  max: duration.inMilliseconds.toDouble() > 0
                      ? duration.inMilliseconds.toDouble()
                      : 1.0,
                  onChanged: (value) => onSeek(Duration(milliseconds: value.toInt())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
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

          const SizedBox(height: 16),

          // Main controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: Icons.replay_10,
                onPressed: () => onSkip(-10),
                color: primaryColor,
                size: 40,
              ),
              const SizedBox(width: 16),
              _buildControlButton(
                icon: isLoading
                    ? Icons.hourglass_empty
                    : playerState == PlayerState.playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                onPressed: isLoading ? null : onTogglePlayPause,
                color: primaryColor,
                size: 64,
                isPrimary: true,
              ),
              const SizedBox(width: 16),
              _buildControlButton(
                icon: Icons.forward_10,
                onPressed: () => onSkip(10),
                color: primaryColor,
                size: 40,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Secondary controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSecondaryButton(
                icon: Icons.replay,
                label: 'Replay',
                onPressed: onReplay,
                color: primaryColor,
              ),
              _buildSpeedControl(playbackSpeed, primaryColor),
              _buildSecondaryButton(
                icon: isMuted ? Icons.volume_off : Icons.volume_up,
                label: isMuted ? 'Tắt' : 'Bật',
                onPressed: onToggleMute,
                color: isMuted ? Colors.red.shade700 : primaryColor,
              ),
              _buildSecondaryButton(
                icon: Icons.stop,
                label: 'Stop',
                onPressed: onStop,
                color: Colors.grey.shade700,
              ),
            ],
          ),

          if (isLoading) ...[
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    required double size,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPrimary ? color.withOpacity(0.1) : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: size,
            color: onPressed == null ? Colors.grey.shade400 : color,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedControl(double currentSpeed, Color color) {
    return PopupMenuButton<double>(
      onSelected: onChangeSpeed,
      itemBuilder: (context) => [
        _buildSpeedMenuItem(0.5, '0.5x', currentSpeed),
        _buildSpeedMenuItem(0.75, '0.75x', currentSpeed),
        _buildSpeedMenuItem(1.0, '1.0x', currentSpeed),
        _buildSpeedMenuItem(1.25, '1.25x', currentSpeed),
        _buildSpeedMenuItem(1.5, '1.5x', currentSpeed),
        _buildSpeedMenuItem(2.0, '2.0x', currentSpeed),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              '${currentSpeed}x',
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<double> _buildSpeedMenuItem(double speed, String label, double currentSpeed) {
    final isSelected = currentSpeed == speed;
    return PopupMenuItem<double>(
      value: speed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.purple.shade700 : Colors.black87,
            ),
          ),
          if (isSelected) Icon(Icons.check, color: Colors.purple.shade700, size: 18),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}