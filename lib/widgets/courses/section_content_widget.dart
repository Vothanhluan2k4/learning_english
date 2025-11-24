import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'adaptive_video_widget.dart'; 
import '../../models/lesson_section.dart';
import '../../models/section_media.dart';
import '../../models/lesson_question.dart';
import '../../services/lesson_section_service.dart';

class SectionContentWidget extends StatefulWidget {
  final LessonSection section;
  final List<SectionMedia> medias;
  final List<Map<String, dynamic>> questionsWithOptions;
  final bool allowReplay;

  const SectionContentWidget({
    required this.section,
    required this.medias,
    required this.questionsWithOptions,
    this.allowReplay = true,
    super.key,
  });

  @override
  State<SectionContentWidget> createState() => _SectionContentWidgetState();
}

class _SectionContentWidgetState extends State<SectionContentWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section title
            Row(
              children: [
                Icon(
                  _getSectionIcon(),
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.section.sectionTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content markdown
            if (widget.section.content != null) ...[
              _buildMarkdownContent(context, widget.section.content!),
              const SizedBox(height: 16),
            ],

            // Media content
            if (widget.medias.isNotEmpty) ...[
              _buildMediaContent(context),
              const SizedBox(height: 16),
            ],

            // Questions
            if (widget.questionsWithOptions.isNotEmpty) ...[
              _buildQuestionsContent(),
            ],
          ],
        ),
      ),
    );
  }

  /// Build markdown content
  Widget _buildMarkdownContent(BuildContext context, String content) {
    return MarkdownBody(
      data: content,
      selectable: true,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        h1: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
          height: 1.5,
        ),
        h2: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
          height: 1.4,
        ),
        h3: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade700,
          height: 1.3,
        ),
        p: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
          height: 1.6,
        ),
        // ✅ Code block styling (for email examples)
        code: TextStyle(
          backgroundColor: Colors.pink.shade50,
          color: Colors.black,
          fontFamily: 'Times New Roman',
          fontSize: 13,
          height: 1.5,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.pink.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white54, width: 1),
        ),
        codeblockPadding: const EdgeInsets.all(16),
        // ✅ List styling
        listBullet: TextStyle(
          fontSize: 14,
          color: Colors.blue.shade700,
          fontWeight: FontWeight.bold,
        ),
        listIndent: 24,
        // ✅ Strong/Bold text
        strong: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade900,
        ),
        // ✅ Emphasis/Italic text
        em: const TextStyle(
          fontStyle: FontStyle.italic,
        ),
        // ✅ Blockquote styling
        blockquote: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(
              color: Colors.grey.shade400,
              width: 4,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.all(12),
      ),
    );
  }

  /// Build media content với Chewie player
  Widget _buildMediaContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Media section header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                Icons.video_library,
                color: Colors.teal.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Tài liệu học tập (${widget.medias.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Media list
        ...widget.medias.asMap().entries.map((entry) {
          final index = entry.key;
          final media = entry.value;
          
          return _buildMediaItem(index, media);
        }).toList(),
      ],
    );
  }

  /// Build single media item
  Widget _buildMediaItem(int index, SectionMedia media) {
    final isVideo = media.mediaType == 'video';
    final isAudio = media.mediaType == 'audio';
    final isImage = media.mediaType == 'image';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Media header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isVideo
                      ? Colors.red.shade700
                      : isAudio
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isVideo ? 'VIDEO' : isAudio ? 'AUDIO' : 'IMAGE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  media.caption ?? 'Media ${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Media player
          if (isVideo)
            AdaptiveVideoPlayer(
              videoUrl: media.mediaUrl,
              caption: media.caption,
              allowReplay: widget.allowReplay,
            )
          else if (isAudio)
            _buildAudioPlayer(media.mediaUrl)
          else if (isImage)
            _buildImageViewer(media.mediaUrl),
        ],
      ),
    );
  }

  /// Build audio player
  Widget _buildAudioPlayer(String audioUrl) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.audiotrack, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              'Audio Player',
              style: TextStyle(color: Colors.blue.shade700),
            ),
          ],
        ),
      ),
    );
  }

  /// Build image viewer
  Widget _buildImageViewer(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.broken_image, size: 48),
            ),
          );
        },
      ),
    );
  }

  /// Build questions content
  Widget _buildQuestionsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Câu hỏi ôn tập',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.questionsWithOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final question = data['question'] as LessonQuestion;
          final options = data['options'] as List;

          return _buildQuestionCard(index + 1, question, options);
        }).toList(),
      ],
    );
  }

  /// Question card
  Widget _buildQuestionCard(int number, LessonQuestion question, List options) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Q$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question.questionText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...options.asMap().entries.map((entry) {
            final optionIndex = entry.key;
            final option = entry.value;
            final isCorrect = option.isCorrect ?? false;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCorrect ? Colors.green : Colors.grey.shade400,
                        width: 2,
                      ),
                      color: isCorrect ? Colors.green.shade50 : null,
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + optionIndex),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.optionText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (isCorrect)
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 18,
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  IconData _getSectionIcon() {
    switch (widget.section.sectionType) {
      case 'text':
        return Icons.description;
      case 'video':
        return Icons.video_library;
      case 'audio':
        return Icons.audiotrack;
      case 'quiz':
        return Icons.quiz;
      default:
        return Icons.article;
    }
  }
}