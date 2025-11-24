import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/speaking_question.dart';
import '../models/lesson_section.dart';

class SpeakingQuestionService {
  final _supabase = SupabaseConfig.client;

  /// Fetch all sections with their speaking questions for a lesson
  Future<List<SectionWithQuestions>> fetchLessonSectionsWithQuestions(String lessonId) async {
    try {
      debugPrint('📚 Loading sections for lesson: $lessonId');

      // 1. Load all sections for this lesson
      final sectionsResponse = await _supabase
          .from('lesson_sections')
          .select()
          .eq('lesson_id', lessonId)
          .order('order_index', ascending: true);

      final sections = (sectionsResponse as List)
          .map((json) => LessonSection.fromJson(json))
          .toList();

      debugPrint('✅ Loaded ${sections.length} sections');

      // 2. Load speaking questions for each speaking section
      final List<SectionWithQuestions> sectionsWithQuestions = [];

      for (var section in sections) {
        if (section.sectionType == 'speaking') {
          // Load questions for this speaking section
          final questionsResponse = await _supabase
              .from('lesson_questions')
              .select()
              .eq('section_id', section.id)
              .eq('question_type', 'speaking')
              .eq('is_active', true)
              .order('order_index', ascending: true);

          final questions = (questionsResponse as List)
              .map((json) => SpeakingQuestion.fromJson(json))
              .toList();

          sectionsWithQuestions.add(SectionWithQuestions(
            section: section,
            questions: questions,
          ));

          debugPrint('🎤 Speaking section "${section.sectionTitle}": ${questions.length} questions');
        } else {
          // Non-speaking section (text, video, etc.)
          sectionsWithQuestions.add(SectionWithQuestions(
            section: section,
            questions: const [],
          ));

          debugPrint('📝 ${section.sectionType.toUpperCase()} section: "${section.sectionTitle}"');
        }
      }

      return sectionsWithQuestions;
    } catch (e) {
      debugPrint('❌ Error fetching sections with questions: $e');
      rethrow;
    }
  }

  /// Legacy method - Fetch speaking questions by lesson (backward compatibility)
  Future<List<SpeakingQuestion>> fetchSpeakingQuestionsByLesson(String lessonId) async {
    try {
      final response = await _supabase
          .from('lesson_questions')
          .select('''
            *,
            lesson_sections!inner(
              lesson_id
            )
          ''')
          .eq('lesson_sections.lesson_id', lessonId)
          .eq('question_type', 'speaking')
          .eq('is_active', true)
          .order('order_index', ascending: true);

      return (response as List)
          .map((json) => SpeakingQuestion.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch speaking questions by lesson: $e');
    }
  }

  /// Fetch speaking questions by section ID
  Future<List<SpeakingQuestion>> fetchSpeakingQuestionsBySection(String sectionId) async {
    try {
      final response = await _supabase
          .from('lesson_questions')
          .select()
          .eq('section_id', sectionId)
          .eq('question_type', 'speaking')
          .eq('is_active', true)
          .order('order_index', ascending: true);

      return (response as List)
          .map((json) => SpeakingQuestion.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch speaking questions: $e');
    }
  }

  /// Get speaking question by ID
  Future<SpeakingQuestion?> getSpeakingQuestionById(String questionId) async {
    try {
      final response = await _supabase
          .from('lesson_questions')
          .select()
          .eq('id', questionId)
          .eq('question_type', 'speaking')
          .maybeSingle();

      return response != null ? SpeakingQuestion.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to get speaking question: $e');
    }
  }
}

// ✅ Model to combine section with its questions
class SectionWithQuestions {
  final LessonSection section;
  final List<SpeakingQuestion> questions;

  SectionWithQuestions({
    required this.section,
    this.questions = const [],
  });

  bool get hasSpeakingQuestions => questions.isNotEmpty;
  bool get isSpeakingSection => section.sectionType == 'speaking';
  bool get isTextSection => section.sectionType == 'text';
}