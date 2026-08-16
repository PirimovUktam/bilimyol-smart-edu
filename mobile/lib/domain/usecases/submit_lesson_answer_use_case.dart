import '../../data/services/i_ai_tutor_service.dart';
import '../entities/question.dart';

class LessonAnswerResult {
  final bool isCorrect;
  final String selectedOption;
  final String correctOption;
  final AIExplanationResponse? aiExplanation;

  const LessonAnswerResult({
    required this.isCorrect,
    required this.selectedOption,
    required this.correctOption,
    this.aiExplanation,
  });
}

class SubmitLessonAnswerUseCase {
  final IAITutorService aiTutorService;

  const SubmitLessonAnswerUseCase(this.aiTutorService);

  Future<LessonAnswerResult> execute({
    required Question question,
    required int selectedIndex,
    String? learnerName,
  }) async {
    final isCorrect = selectedIndex == question.correctIndex;
    final selectedOption = question.options[selectedIndex];
    final correctOption = question.options[question.correctIndex];

    if (isCorrect) {
      return LessonAnswerResult(
        isCorrect: true,
        selectedOption: selectedOption,
        correctOption: correctOption,
      );
    }

    // Call AI Tutor service for diagnostic explanation
    final aiExplanation = await aiTutorService.explainMistake(
      AIExplanationRequest(
        courseId: question.courseId,
        skillId: question.skillId,
        questionId: question.id,
        questionText: question.text,
        selectedOption: selectedOption,
        correctOption: correctOption,
        learnerName: learnerName,
      ),
    );

    return LessonAnswerResult(
      isCorrect: false,
      selectedOption: selectedOption,
      correctOption: correctOption,
      aiExplanation: aiExplanation,
    );
  }
}
