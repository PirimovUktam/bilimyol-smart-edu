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
}
