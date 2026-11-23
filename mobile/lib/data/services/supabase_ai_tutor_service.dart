import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'i_ai_tutor_service.dart';
import 'demo_ai_tutor_service.dart';
import '../../core/config/supabase_config.dart';

/// Raised when the AI edge function is reachable but refuses or fails the chat
/// request. Chat has no deterministic fallback content, so the UI must surface
/// a clear, recoverable error instead of pretending the AI answered.
class AITutorUnavailableException implements Exception {
  final String message;
  const AITutorUnavailableException(this.message);
  @override
  String toString() => message;
}

class SupabaseAITutorService implements IAITutorService {
  final DemoAITutorService _fallbackService = DemoAITutorService();

  @override
  Future<AIExplanationResponse> explainMistake(
    AIExplanationRequest request,
  ) async {
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
          if (request.lessonId != null) 'lessonId': request.lessonId,
          if (request.topic != null) 'topic': request.topic,
          'language': request.language == 'ru' ? 'ru' : 'uz',
        },
      );

      final data = res.data;
      if (data != null && data is Map<String, dynamic>) {
        return AIExplanationResponse(
          tutorName: data['tutorName'] ?? 'Yölçi AI',
          title: data['title'] ?? 'Xatoni tahlil qiliş',
          explanation:
              data['explanation'] ??
              'Siz tanlagan javob (${request.selectedOption}) töğri emas.',
          remediationStep:
              data['remediationStep'] ??
              'Mavzuni qadamma-qadam takrorlaş tavsiya etiladi.',
          suggestedAction:
              data['suggestedAction'] ??
              'Keling, uşbu mavzuni qisqa maşq bilan mustahkamlaymiz.',
          isDeterministicFallback: data['isDeterministicFallback'] == true,
        );
      }

      if (SupabaseConfig.hasRemoteConfiguration) {
        throw const AITutorUnavailableException(
          'Yölçi AI hozirça javob bera olmadi. Iltimos, qayta urinib köring.',
        );
      }
      debugPrint(
        '[AITutor] explainMistake returned no usable payload — using deterministic fallback.',
      );
      return _fallbackService.explainMistake(request);
    } catch (err) {
      if (SupabaseConfig.hasRemoteConfiguration) {
        if (err is AITutorUnavailableException) rethrow;
        throw const AITutorUnavailableException(
          'Yölçi AI xizmatiga ulanib bölmadi. Internetni tekşirib qayta urinib köring.',
        );
      }
      debugPrint(
        '[AITutor] explainMistake failed ($err) — using deterministic fallback.',
      );
      return _fallbackService.explainMistake(request);
    }
  }

  @override
  Future<GeneratedLessonResponse> generateLesson(
    GenerateLessonRequest request,
  ) async {
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
      if (data != null &&
          data is Map<String, dynamic> &&
          data['title'] != null) {
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

      if (SupabaseConfig.hasRemoteConfiguration) {
        throw const AITutorUnavailableException(
          'Dars kontenti hozirça yuklanmadi. Internetni tekşirib qayta urinib köring.',
        );
      }
      debugPrint(
        '[AITutor] generateLesson returned no usable payload — using deterministic fallback.',
      );
      return _fallbackService.generateLesson(request);
    } catch (err) {
      if (SupabaseConfig.hasRemoteConfiguration) {
        if (err is AITutorUnavailableException) rethrow;
        throw const AITutorUnavailableException(
          'Dars kontenti xizmatiga ulanib bölmadi. Internetni tekşirib qayta urinib köring.',
        );
      }
      debugPrint(
        '[AITutor] generateLesson failed ($err) — using deterministic fallback.',
      );
      return _fallbackService.generateLesson(request);
    }
  }

  @override
  Future<AskTutorResponse> askTutor(AskTutorRequest request) async {
    final isRu = request.language == 'ru';
    final message = request.message.trim();
    if (message.isEmpty) {
      throw AITutorUnavailableException(
        isRu ? 'Пожалуйста, введите ваш вопрос.' : 'Iltimos, savolingizni yozing.',
      );
    }

    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final token = session?.accessToken;

      final res = await client.functions.invoke(
        'yolchi-tutor',
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        body: {
          'action': 'askTutor',
          'message': message,
          'courseId': request.courseId,
          'skillId': request.skillId,
          'lessonId': request.lessonId,
          'topic': request.topic,
          if (request.questionId != null) 'questionId': request.questionId,
          if (request.questionPrompt != null)
            'questionPrompt': request.questionPrompt,
          if (request.questionSkillId != null)
            'questionSkillId': request.questionSkillId,
          if (request.learnerScore != null) 'learnerScore': request.learnerScore,
          if (request.recentMistakes.isNotEmpty)
            'recentMistakes': request.recentMistakes,
          'language': isRu ? 'ru' : 'uz',
          'history': [
            for (final turn in request.history)
              {'sender': turn.sender, 'text': turn.text},
          ],
        },
      );

      final data = res.data;
      if (data is Map<String, dynamic> &&
          data['isAiGenerated'] == true &&
          data['isDeterministicFallback'] != true &&
          data['answer'] is String &&
          (data['answer'] as String).trim().isNotEmpty) {
        return AskTutorResponse(
          tutorName: data['tutorName'] ?? 'Yölçi AI',
          answer: data['answer'] as String,
          isAiGenerated: data['isAiGenerated'] == true,
          isDeterministicFallback: data['isDeterministicFallback'] == true,
        );
      }

      throw AITutorUnavailableException(
        isRu
            ? 'Yölçi AI пока не смог ответить. Пожалуйста, попробуйте ещё раз.'
            : 'Yölçi AI hozirça javob bera olmadi. Iltimos, qayta urinib köring.',
      );
    } on AITutorUnavailableException {
      rethrow;
    } catch (err) {
      debugPrint('[AITutor] askTutor failed: $err');
      throw AITutorUnavailableException(
        isRu
            ? 'Не удалось подключиться к Yölçi AI. Проверьте интернет и попробуйте снова.'
            : 'Yölçi AI xizmatiga ulanib bölmadi. Internet aloqasini tekşirib qayta urinib köring.',
      );
    }
  }
}
