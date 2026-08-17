import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';

void main() {
  group('Gemini / AI Tutor Service Tests (Flutter)', () {
    test('provides explainable pedagogical error diagnosis without score alteration', () async {
      final aiService = DemoAITutorService();

      const request = AIExplanationRequest(
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        questionId: 'q_math_lesson_interactive',
        questionText: 'f(x) = 2x + 3 funksiyasida x = 4 bo‘lsa, f(4) ni toping:',
        selectedOption: '8',
        correctOption: '11',
        learnerName: 'Ali',
      );

      final response = await aiService.explainMistake(request);

      expect(response.tutorName, equals('Yo‘lchi AI'));
      expect(response.title, equals('Ozod son (+3) unutilgan'));
      expect(response.explanation.isNotEmpty, isTrue);
      expect(response.remediationStep.isNotEmpty, isTrue);
      expect(response.suggestedAction.isNotEmpty, isTrue);
    });

    test('gracefully handles unknown questions with robust deterministic fallback', () async {
      final aiService = DemoAITutorService();

      const request = AIExplanationRequest(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        questionId: 'unknown_question_id',
        questionText: 'Test text',
        selectedOption: 'Option A',
        correctOption: 'Option B',
      );

      final response = await aiService.explainMistake(request);

      expect(response.tutorName, equals('Yo‘lchi AI'));
      expect(response.title, equals('Xatoni tahlil qilish'));
      expect(response.explanation, contains('to‘g‘ri emas'));
      expect(response.isDeterministicFallback, isTrue);
    });

    test('generates structured lesson using gemini-3.6-flash configuration', () async {
      final aiService = DemoAITutorService();

      const request = GenerateLessonRequest(
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        topic: 'Chiziqli funksiyalar',
        level: 'intermediate',
        difficulty: 'medium',
      );

      final response = await aiService.generateLesson(request);

      expect(response.lessonId, isNotEmpty);
      expect(response.title, contains('Chiziqli funksiyalar'));
      expect(response.model, equals('gemini-3.6-flash'));
      expect(response.estimatedMinutes, equals(15));
    });
  });
}
