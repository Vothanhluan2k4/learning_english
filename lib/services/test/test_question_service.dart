import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../../models/test_question.dart';
import '../../models/question_group.dart';

class TestQuestionService {
  final _supabase = Supabase.instance.client;

  /// Fetch all questions and groups for a test
  Future<List<dynamic>> fetchTestQuestions(String testId) async {
    try {
      debugPrint('📚 Loading questions for test: $testId');
      
      final allItems = <dynamic>[];

      // 1. Fetch direct questions (no group)
      final directRes = await _supabase
          .from('test_questions')
          .select()
          .eq('test_id', testId)
          .isFilter('group_id', null)
          .order('order_in_test', ascending: true);

      final directQuestions = 
          (directRes as List).map((q) => TestQuestion.fromJson(q)).toList();
      allItems.addAll(directQuestions);

      // 2. Fetch question groups with questions
      final groupRes = await _supabase
          .from('question_groups')
          .select('''
            id, test_id, title, instruction, media_type, media_url, content, order_in_test,
            test_questions!inner(*)
          ''')
          .eq('test_id', testId)
          .order('order_in_test', ascending: true);

      for (final g in groupRes) {
        final group = QuestionGroup.fromJson(g);
        group.testQuestions.sort((a, b) => 
            (a.orderInTest ?? 0).compareTo(b.orderInTest ?? 0));
        allItems.add(group);
      }

      // 3. Sort all items by order
      allItems.sort((a, b) {
        final orderA = a is TestQuestion ? a.orderInTest : (a as QuestionGroup).orderInTest;
        final orderB = b is TestQuestion ? b.orderInTest : (b as QuestionGroup).orderInTest;
        return (orderA ?? 0).compareTo(orderB ?? 0);
      });

      debugPrint('✅ Loaded ${allItems.length} items (questions + groups)');
      return allItems;
    } catch (e) {
      debugPrint('❌ Error loading questions: $e');
      rethrow;
    }
  }

  /// Get test info (time limit, type, etc.)
  Future<Map<String, dynamic>> getTestInfo(String testId) async {
    try {
      final testInfo = await _supabase
          .from('tests')
          .select('time_limit, test_type, recommended_course_id')
          .eq('id', testId)
          .single();
      
      return testInfo;
    } catch (e) {
      debugPrint('❌ Error getting test info: $e');
      rethrow;
    }
  }
}