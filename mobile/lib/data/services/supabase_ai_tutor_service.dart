import 'package:supabase_flutter/supabase_flutter.dart';
import 'i_ai_tutor_service.dart';
import 'demo_ai_tutor_service.dart';

class SupabaseAITutorService implements IAITutorService {
  final DemoAITutorService _fallbackService = DemoAITutorService();

  @override
  Future<AIExplanationResponse> explainMistake(AIExplanationRequest request) async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final token = session?.accessToken;

      final res = await client.functions.invoke(
        'yolchi-tutor',
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        body: {
          'action': 'diagnose_mistake',
          'courseId': request.courseId,
          'skillId': request.skillId,
          'questionId': request.questionId,
          'questionText': request.questionText,
          'selectedOption': request.selectedOption,
          'correctOption': request.correctOption,
          'learnerName': request.learnerName,
        },
      );

      final data = res.data;
      if (data != null && data is Map<String, dynamic>) {
        return AIExplanationResponse(
          tutorName: data['tutorName'] ?? 'Yo‘lchi AI',
          title: data['title'] ?? 'Xatoni tahlil qilish',
          explanation: data['explanation'] ?? 'Siz tanlagan javob (${request.selectedOption}) to‘g‘ri emas.',
          remediationStep: data['remediationStep'] ?? 'Mavzuni qadamma-qadam takrorlash tavsiya etiladi.',
          suggestedAction: data['suggestedAction'] ?? 'Keling, ushbu mavzuni qisqa mashq bilan mustahkamlaymiz.',
          isDeterministicFallback: data['isDeterministicFallback'] == true,
        );
      }

      return _fallbackService.explainMistake(request);
    } catch (_) {
      return _fallbackService.explainMistake(request);
    }
  }

  @override
  Future<GeneratedLessonResponse> generateLesson(GenerateLessonRequest request) async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final token = session?.accessToken;

      final res = await client.functions.invoke(
        'yolchi-tutor',
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        body: {
          'action': 'generate_lesson',
          'courseId': request.courseId,
          'skillId': request.skillId,
          'topic': request.topic,
          'level': request.level,
          'difficulty': request.difficulty,
          'questionCount': request.questionCount ?? 5,
          'learnerScore': request.learnerScore,
        },
      );

      final data = res.data;
      if (data != null && data is Map<String, dynamic> && data['title'] != null) {
        return GeneratedLessonResponse(
          lessonId: data['lessonId'] ?? 'lesson_gen_${request.skillId}',
          courseId: data['courseId'] ?? request.courseId,
          skillId: data['skillId'] ?? request.skillId,
          topic: data['topic'] ?? (request.topic ?? request.skillId),
          level: data['level'] ?? (request.level ?? 'intermediate'),
          difficulty: data['difficulty'] ?? (request.difficulty ?? 'medium'),
          title: data['title'] ?? 'Interaktiv dars',
          summary: data['summary'] ?? '',
          objective: data['objective'] ?? '',
          estimatedMinutes: data['estimatedMinutes'] ?? 15,
          steps: data['steps'] is List ? data['steps'] : const [],
          questions: data['questions'] is List ? data['questions'] : const [],
          isAiGenerated: data['isAiGenerated'] == true,
          model: data['model'] ?? 'gemini-3.6-flash',
        );
      }

      return _fallbackService.generateLesson(request);
    } catch (_) {
      return _fallbackService.generateLesson(request);
    }
  }
}
