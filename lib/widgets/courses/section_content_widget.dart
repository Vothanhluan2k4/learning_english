import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/lesson_section.dart';
import '../../models/section_media.dart';
import '../../models/lesson_question.dart';
import '../../services/lesson_section_service.dart';
import 'media_player_widget.dart';

class SectionContentWidget extends StatelessWidget {
  final LessonSection section;
  final List<SectionMedia> medias;
  final List<Map<String, dynamic>> questionsWithOptions;
  final bool allowReplay;
  final _sectionService = LessonSectionService();

  SectionContentWidget({
    required this.section,
    required this.medias,
    required this.questionsWithOptions,
    this.allowReplay = true,
    super.key,
  });

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
          mainAxisSize: MainAxisSize.min, // ✅ IMPORTANT: Prevent unbounded height
          children: [
            // ✅ Section title
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
                    section.sectionTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ✅ Content markdown - render với ký hiệu
            if (section.content != null) ...[
              _buildMarkdownContent(context, section.content!),
              const SizedBox(height: 16),
            ],

            // ✅ Media content
            if (medias.isNotEmpty) ...[
              _buildMediaContent(context),
              const SizedBox(height: 16),
            ],

            // ✅ Questions
            if (questionsWithOptions.isNotEmpty) ...[
              _buildQuestionsContent(),
            ],
          ],
        ),
      ),
    );
  }

  /// ✅ Build markdown content với styling
  Widget _buildMarkdownContent(BuildContext context, String content) {
    return SingleChildScrollView( // ✅ FIX: Wrap with SingleChildScrollView
      child: MarkdownBody(
        data: content,
        selectable: true,
        shrinkWrap: true, // ✅ IMPORTANT: Allow markdown to shrink
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          // ✅ Heading styles
          h1: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
            height: 1.5,
            letterSpacing: 0.5,
          ),
          h2: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
            height: 1.4,
            letterSpacing: 0.3,
          ),
          h3: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
            height: 1.3,
            letterSpacing: 0.2,
          ),
          // ✅ Paragraph style
          p: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.6,
          ),
          // ✅ Code inline style
          code: TextStyle(
            backgroundColor: Colors.grey.shade200,
            color: Colors.red.shade700,
            fontFamily: 'Courier New',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          // ✅ Code block decoration
          codeblockDecoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade700,
              width: 1,
            ),
          ),
          codeblockPadding: const EdgeInsets.all(12),
          // ✅ List bullet style
          listBullet: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.6,
          ),
          // ✅ Blockquote style
          blockquote: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
          blockquoteDecoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(
              left: BorderSide(
                color: Colors.blue.shade300,
                width: 4,
              ),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          // ✅ Table styles
          tableHead: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            backgroundColor: Colors.blue.shade700,
          ),
          tableBody: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
          tableBorder: TableBorder.all(
            color: Colors.grey.shade300,
            width: 1,
            borderRadius: BorderRadius.circular(4),
          ),
          tableCellsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          // ✅ Link style
          a: TextStyle(
            color: Colors.blue.shade700,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w500,
          ),
          // ✅ Horizontal rule
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.grey.shade300,
                width: 2,
              ),
            ),
          ),
        ),
        // ✅ Image builder
        imageBuilder: (uri, title, alt) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.image_not_supported),
                    ),
                  );
                },
              ),
            ),
          );
        },
        // ✅ Link callback
        onTapLink: (text, href, title) {
          debugPrint('Link tapped: $href');
          // TODO: Implement link handling
        },
      ),
    );
  }

  /// ✅ Build media - hỗ trợ nhiều video
  Widget _buildMediaContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ Tiêu đề media section
        if (medias.isNotEmpty)
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
                  'Tài liệu học tập (${medias.length})',
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

        // ✅ Danh sách media
        ...medias.asMap().entries.map((entry) {
          final index = entry.key;
          final media = entry.value;
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
                // ✅ Media header
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (media.caption != null)
                            Text(
                              media.caption!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            Text(
                              'Media ${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            media.mediaUrl.split('/').last,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ✅ Media player
                MediaPlayerWidget(
                  mediaType: media.mediaType,
                  mediaUrl: media.mediaUrl,
                  caption: null, // Đã show ở trên
                  allowReplay: allowReplay,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  /// ✅ Build questions
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
        ...questionsWithOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final question = data['question'] as LessonQuestion;
          final options = data['options'] as List;

          return _buildQuestionCard(index + 1, question, options);
        }).toList(),
      ],
    );
  }

  /// ✅ Question card
  Widget _buildQuestionCard(int number, dynamic question, List options) {
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
    switch (section.sectionType) {
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