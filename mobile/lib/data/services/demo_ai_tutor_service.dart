import 'i_ai_tutor_service.dart';
import '../datasources/demo_ai_data.dart';

class DemoAITutorService implements IAITutorService {
  @override
  Future<AIExplanationResponse> explainMistake(AIExplanationRequest request) async {
    // Artificial minimal delay (100ms) for natural feel without slowing tests
    await Future.delayed(const Duration(milliseconds: 100));

    final matched = demoAiResponsesData[request.questionId];

    if (matched != null) {
      return AIExplanationResponse(
        tutorName: 'Yo‘lchi AI',
        title: matched.misconceptionTitle,
        explanation: matched.explanation,
        remediationStep: matched.remediationStep,
        suggestedAction: matched.suggestedAction,
        isDeterministicFallback: true,
      );
    }

    return AIExplanationResponse(
      tutorName: 'Yo‘lchi AI',
      title: 'Xatoni tahlil qilish',
      explanation: 'Siz tanlagan javob (${request.selectedOption}) to‘g‘ri emas. To‘g‘ri javob: ${request.correctOption}.',
      remediationStep: 'Mavzuni to‘liq o‘zlashtirish uchun formulani qadamma-qadam tekshirib chiqing.',
      suggestedAction: 'Keling, ushbu ko‘nikmani mustahkamlash mashqi bilan tekshiramiz.',
      isDeterministicFallback: true,
    );
  }

  @override
  Future<GeneratedLessonResponse> generateLesson(GenerateLessonRequest request) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final topic = request.topic ?? request.skillId;
    return GeneratedLessonResponse(
      lessonId: 'lesson_fallback_${request.skillId}',
      courseId: request.courseId,
      skillId: request.skillId,
      topic: topic,
      level: request.level ?? 'intermediate',
      difficulty: request.difficulty ?? 'medium',
      title: '$topic bo‘yicha interaktiv dars',
      summary: 'Asosiy nazariy qoidalar va amaliy misollar jamlanmasi.',
      objective: 'Mavzuni to‘liq o‘zlashtirish va mustahkamlash.',
      estimatedMinutes: 15,
      steps: const [],
      questions: const [],
      isAiGenerated: false,
      model: 'gemini-3.6-flash',
    );
  }
}
