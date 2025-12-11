import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lesson_section.dart';
import '../../models/section_media.dart';
import '../../models/lesson_question.dart';
import '../../models/question_option.dart';

class LessonSectionService {
  final _supabase = Supabase.instance.client;

  /// ✅ Lấy tất cả sections của một lesson
  Future<List<LessonSection>> fetchSectionsByLesson(String lessonId) async {
    try {
      debugPrint('📖 Fetching sections for lesson: $lessonId');

      final response = await _supabase
          .from('lesson_sections')
          .select('*')
          .eq('lesson_id', lessonId)
          .order('order_index', ascending: true);

      final sections = (response as List)
          .map((e) => LessonSection.fromJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Loaded ${sections.length} sections');
      return sections;
    } catch (e) {
      debugPrint('❌ Error fetching sections: $e');
      return [];
    }
  }

  /// ✅ Lấy media của một section
  Future<List<SectionMedia>> fetchMediaBySection(String sectionId) async {
    try {
      debugPrint('🎬 Fetching media for section: $sectionId');

      final response = await _supabase
          .from('section_media')
          .select('*')
          .eq('section_id', sectionId)
          .order('order_index', ascending: true);

      final medias = (response as List)
          .map((e) => SectionMedia.fromJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Loaded ${medias.length} medias');
      return medias;
    } catch (e) {
      debugPrint('❌ Error fetching media: $e');
      return [];
    }
  }

  /// ✅ Lấy questions của một section
  Future<List<LessonQuestion>> fetchQuestionsBySection(String sectionId) async {
    try {
      debugPrint('❓ Fetching questions for section: $sectionId');

      final response = await _supabase
          .from('lesson_questions')
          .select('*')
          .eq('section_id', sectionId)
          .eq('is_active', true)
          .order('order_index', ascending: true);

      final questions = (response as List)
          .map((e) => LessonQuestion.fromJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Loaded ${questions.length} questions');
      return questions;
    } catch (e) {
      debugPrint('❌ Error fetching questions: $e');
      return [];
    }
  }

  /// ✅ Lấy options của một question
  Future<List<QuestionOption>> fetchOptionsByQuestion(
    String questionId,
  ) async {
    try {
      debugPrint('📋 Fetching options for question: $questionId');

      final response = await _supabase
          .from('lesson_question_options')
          .select('*')
          .eq('question_id', questionId)
          .order('order_index', ascending: true);

      final options = (response as List)
          .map((e) => QuestionOption.fromJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Loaded ${options.length} options');
      return options;
    } catch (e) {
      debugPrint('❌ Error fetching options: $e');
      return [];
    }
  }

  /// ✅ Lấy toàn bộ lesson content (sections + media + questions + options)
  Future<Map<String, dynamic>> fetchFullLessonContent(String lessonId) async {
    try {
      debugPrint('📚 Fetching full lesson content for: $lessonId');

      final sections = await fetchSectionsByLesson(lessonId);

      final sectionContent = <String, dynamic>{};

      for (var section in sections) {
        final medias = await fetchMediaBySection(section.id);
        final questions = await fetchQuestionsBySection(section.id);

        // Fetch options cho mỗi question
        final questionsWithOptions = <Map<String, dynamic>>[];
        for (var question in questions) {
          final options = await fetchOptionsByQuestion(question.id);
          questionsWithOptions.add({
            'question': question,
            'options': options,
          });
        }

        sectionContent[section.id] = {
          'section': section,
          'medias': medias,
          'questions': questionsWithOptions,
        };
      }

      debugPrint('✅ Full lesson content loaded');
      return {
        'sections': sections,
        'content': sectionContent,
      };
    } catch (e) {
      debugPrint('❌ Error fetching full lesson content: $e');
      return {};
    }
  }

  /// ✅ Lấy icon theo media type
  IconData getMediaIcon(String mediaType) {
    switch (mediaType) {
      case 'image':
        return Icons.image;
      case 'audio':
        return Icons.audiotrack;
      case 'video':
        return Icons.video_library;
      default:
        return Icons.attachment;
    }
  }

  /// ✅ Lấy icon theo question type
  IconData getQuestionIcon(String questionType) {
    switch (questionType) {
      case 'single_choice':
        return Icons.radio_button_checked;
      case 'multiple_choice':
        return Icons.check_box;
      case 'fill_blank':
        return Icons.edit;
      case 'listening':
        return Icons.headphones;
      case 'reading':
        return Icons.menu_book;
      default:
        return Icons.help_outline;
    }
  }
}