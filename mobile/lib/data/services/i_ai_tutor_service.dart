class AIExplanationRequest {
  final String courseId;
  final String skillId;
  final String questionId;
  final String questionText;
  final String selectedOption;
  final String correctOption;
  final String? learnerName;
  final String language;
  final String? lessonId;
  final String? topic;

  const AIExplanationRequest({
    required this.courseId,
    required this.skillId,
    required this.questionId,
    required this.questionText,
    required this.selectedOption,
    required this.correctOption,
    this.learnerName,
    this.language = 'uz',
    this.lessonId,
    this.topic,
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

class GenerateLessonRequest {
  final String courseId;
  final String skillId;
  final String? topic;
  final String? level;
  final String? difficulty;
  final int? questionCount;
  final int? learnerScore;

  const GenerateLessonRequest({
    required this.courseId,
    required this.skillId,
    this.topic,
    this.level,
    this.difficulty,
    this.questionCount,
    this.learnerScore,
  });
}

class GeneratedLessonResponse {
  final String lessonId;
  final String courseId;
  final String skillId;
  final String topic;
  final String level;
  final String difficulty;
  final String title;
  final String summary;
  final String objective;
  final int estimatedMinutes;
  final List<dynamic> steps;
  final List<dynamic> questions;
  final bool isAiGenerated;
  final String? model;

  const GeneratedLessonResponse({
    required this.lessonId,
    required this.courseId,
    required this.skillId,
    required this.topic,
    required this.level,
    required this.difficulty,
    required this.title,
    required this.summary,
    required this.objective,
    required this.estimatedMinutes,
    required this.steps,
    required this.questions,
    this.isAiGenerated = true,
    this.model,
  });
}

class AskTutorRequest {
  final String message;
  final String? courseId;
  final String? skillId;
  final String? lessonId;
  final String? topic;
  final String language;
  final List<({String sender, String text})> history;
  final int? learnerScore;
  final List<String> recentMistakes;
  final String? questionId;
  final String? questionPrompt;
  final String? questionSkillId;

  const AskTutorRequest({
    required this.message,
    this.courseId,
    this.skillId,
    this.lessonId,
    this.topic,
    this.language = 'uz',
    this.history = const [],
    this.learnerScore,
    this.recentMistakes = const [],
    this.questionId,
    this.questionPrompt,
    this.questionSkillId,
  });
}

class AskTutorResponse {
  final String tutorName;
  final String answer;
  final bool isAiGenerated;
  final bool isDeterministicFallback;

  const AskTutorResponse({
    required this.tutorName,
    required this.answer,
    this.isAiGenerated = true,
    this.isDeterministicFallback = false,
  });
}

abstract class IAITutorService {
  Future<AIExplanationResponse> explainMistake(AIExplanationRequest request);
  Future<GeneratedLessonResponse> generateLesson(GenerateLessonRequest request);
  Future<AskTutorResponse> askTutor(AskTutorRequest request);
}
