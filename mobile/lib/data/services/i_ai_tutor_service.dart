class AIExplanationRequest {
  final String courseId;
  final String skillId;
  final String questionId;
  final String questionText;
  final String selectedOption;
  final String correctOption;
  final String? learnerName;

  const AIExplanationRequest({
    required this.courseId,
    required this.skillId,
    required this.questionId,
    required this.questionText,
    required this.selectedOption,
    required this.correctOption,
    this.learnerName,
  });
}

class AIExplanationResponse {
  final String tutorName;
  final String title;
  final String explanation;
  final String remediationStep;
  final String suggestedAction;
  final bool isDeterministicFallback;

  const AIExplanationResponse({
    required this.tutorName,
    required this.title,
    required this.explanation,
    required this.remediationStep,
    required this.suggestedAction,
    this.isDeterministicFallback = true,
  });
}

abstract class IAITutorService {
  Future<AIExplanationResponse> explainMistake(AIExplanationRequest request);
}
