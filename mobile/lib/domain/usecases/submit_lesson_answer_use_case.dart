import '../../data/services/i_ai_tutor_service.dart';
import '../entities/question.dart';
import '../repositories/i_learner_repository.dart';

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
  final ILearnerRepository learnerRepository;

  const SubmitLessonAnswerUseCase(this.aiTutorService, this.learnerRepository);

  Future<LessonAnswerResult> execute({
    required Question question,
    required String lessonId,
    required int selectedIndex,
    String? learnerName,
  }) async {
    final selectedOption = question.options[selectedIndex];
    final attempt = await learnerRepository.recordAnswerAttempt(
      courseId: question.courseId,
      skillId: question.skillId,
      lessonId: lessonId,
      questionId: question.id,
      selectedIndex: selectedIndex,
      selectedAnswer: selectedOption,
      // Used only by the offline repository. Authenticated scoring is returned
      // by the server RPC and is read from `attempt.isCorrect` below.
      isCorrect: selectedIndex == question.correctIndex,
    );
    final isCorrect = attempt.isCorrect;
    // Server-authoritative repositories may return the correct option directly;
    // otherwise fall back to the question's own answer key. This guarantees a
    // wrong answer can always reveal "To‘g‘ri javob: …" to the learner.
    final serverCorrectOption = attempt.correctOption;
    final correctIndex = question.correctIndex;
    final localCorrectOption =
        (correctIndex >= 0 && correctIndex < question.options.length)
        ? question.options[correctIndex]
        : '';
    final correctOption = (serverCorrectOption != null &&
            serverCorrectOption.isNotEmpty)
        ? serverCorrectOption
        : localCorrectOption;

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
        correctOption: correctOption.isEmpty ? 'to‘g‘ri javob' : correctOption,
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
