import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';

void main() {
  group('Gemini / AI Tutor Service Tests (Flutter)', () {
    test('provides explainable pedagogical error diagnosis without score alteration', () async {
      final aiService = DemoAITutorService();

      const request = AIExplanationRequest(
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        questionId: 'q_math_func_01_step',
        questionText: 'f(x) = 2x + 3 funksiyasida x = 4 bölsa, f(4) ni toping:',
        selectedOption: '8',
        correctOption: '11',
        learnerName: 'Ali',
      );

      final response = await aiService.explainMistake(request);

      expect(response.tutorName, equals('Yölçi AI'));
      expect(response.title, equals('Ozod son (+3) hisobga olinmagan'));
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

      expect(response.tutorName, equals('Yölçi AI'));
      expect(response.title, equals('Xatoni tahlil qiliş'));
      expect(response.explanation, contains('töğri emas'));
      expect(response.isDeterministicFallback, isTrue);
    });

    test('generates structured lesson using gemini-3.6-flash configuration', () async {
      final aiService = DemoAITutorService();

      const request = GenerateLessonRequest(
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        topic: 'Çiziqli funksiyalar',
        level: 'intermediate',
        difficulty: 'medium',
      );

      final response = await aiService.generateLesson(request);

      expect(response.lessonId, isNotEmpty);
      expect(response.title, contains('Çiziqli funksiyalar'));
      expect(response.model, equals('gemini-3.6-flash'));
      expect(response.estimatedMinutes, equals(15));
    });

    test('explainMistake supports RU for curated and A1-B1 English questions', () async {
      final aiService = DemoAITutorService();

      final curatedRu = await aiService.explainMistake(
        const AIExplanationRequest(
          courseId: 'course_eng_01',
          skillId: 'skill_eng_listening',
          questionId: 'q_eng_listening_01',
          questionText: 'What time does the bus arrive?',
          selectedOption: '03:15',
          correctOption: '15:15',
          language: 'ru',
        ),
      );
      expect(curatedRu.title, equals('Выражение времени понято неверно'));
      expect(curatedRu.explanation, contains('Quarter past three'));

      final a2Lesson = seedLessons['lesson_eng_a2_m1_directions']!;
      final a2Question = a2Lesson.steps
          .firstWhere((s) => s.interactiveQuestion != null)
          .interactiveQuestion!;
      final a2Uz = await aiService.explainMistake(
        AIExplanationRequest(
          courseId: 'course_eng_01',
          skillId: a2Question.skillId,
          lessonId: a2Lesson.id,
          questionId: a2Question.id,
          questionText: a2Question.text,
          selectedOption:
              a2Question.options[(a2Question.correctIndex + 1) % a2Question.options.length],
          correctOption: a2Question.options[a2Question.correctIndex],
          language: 'uz',
        ),
      );
      expect(a2Uz.title, contains('A2'));
      expect(a2Uz.explanation, isNotEmpty);
      expect(a2Uz.remediationStep, isNotEmpty);
    });

    test('generateLesson for course_eng_01 includes audio_wave step', () async {
      final aiService = DemoAITutorService();
      final res = await aiService.generateLesson(
        const GenerateLessonRequest(
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          topic: 'Greetings',
        ),
      );
      expect(res.title.toLowerCase(), contains('dars'));
      final steps = res.steps.cast<Map<String, dynamic>>();
      expect(
        steps.any((s) => (s['visualModelData'] as Map?)?['type'] == 'audio_wave'),
        isTrue,
      );
    });

    test('askTutor grounds English replies in A1-B1 context and blocks answer-key spoilers', () async {
      final aiService = DemoAITutorService();

      final normalUz = await aiService.askTutor(
        const AskTutorRequest(
          message: 'Hello qaçon işlatiladi?',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_starter',
          topic: 'Birinçi inglizça sözlar',
          language: 'uz',
          learnerScore: 55,
          recentMistakes: ['Vocabulary'],
        ),
      );
      expect(normalUz.answer, contains('Birinçi inglizça sözlar'));
      expect(normalUz.answer, contains('qadam-baqadam'));
      expect(normalUz.answer, contains('55%'));
      expect(normalUz.answer, contains('Vocabulary'));

      for (final spoilerPrompt in [
        'Töğri javobni ayt',
        'javobni ber',
        'Скажи правильный ответ',
        'Tell me the answer',
      ]) {
        final isRu = spoilerPrompt == 'Скажи правильный ответ';
        final res = await aiService.askTutor(
          AskTutorRequest(
            message: spoilerPrompt,
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            lessonId: 'lesson_eng_starter',
            questionId: 'q_lesson_eng_starter_quiz',
            questionSkillId: 'skill_eng_vocab',
            language: isRu ? 'ru' : 'uz',
          ),
        );
        expect(res.answer, isNot(contains("I'm Sam")));
        expect(res.answer, isNot(contains('My name is Sam')));
        expect(res.answer, isNot(contains('I am Sam')));
        if (isRu) {
          expect(res.answer, contains('Давайте разберём вопрос по шагам'));
          expect(res.answer, contains('шаг за шагом'));
        } else {
          expect(res.answer, contains('qadam-baqadam'));
        }
      }
    });
  });
}
