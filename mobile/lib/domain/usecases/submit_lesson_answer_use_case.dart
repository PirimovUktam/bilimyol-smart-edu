import 'dart:collection';
import 'dart:convert';
import '../../core/utils/attempt_uuid.dart';
import '../entities/question.dart';
import '../personalization/starter_question_feedback.dart';
import '../repositories/i_learner_repository.dart';

class LessonAnswerResult {
  final bool isCorrect;
  final String selectedOption;
  final String correctOption;
  final String explanation;
  final String? optionFeedback;

  const LessonAnswerResult({
    required this.isCorrect,
    required this.selectedOption,
    required this.correctOption,
    required this.explanation,
    this.optionFeedback,
  });
}

class SubmitLessonAnswerUseCase {
  final ILearnerRepository learnerRepository;

  const SubmitLessonAnswerUseCase(this.learnerRepository);

  Future<LessonAnswerResult> execute({
    required Question question,
    required String lessonId,
    int? selectedIndex,
    String? selectedText,
    Map<String, String>? matchedPairs,
    List<String>? orderedTokens,
    List<String>? checkedCriteriaIds,
    String? idempotencyKey,
    String uiLocale = 'uz',
  }) async {
    final resolvedKey =
        (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        ? idempotencyKey.trim()
        : generateAttemptUuidV4();

    if (question.usesTextEvaluation) {
      final answerText = (selectedText ?? '').trim();
      if (answerText.isEmpty) {
        throw ArgumentError.value(selectedText, 'selectedText');
      }
      final effectiveIndex = selectedIndex ?? 0;
      final attempt = await learnerRepository.recordAnswerAttemptIdempotent(
        courseId: question.courseId,
        skillId: question.skillId,
        lessonId: lessonId,
        questionId: question.id,
        selectedIndex: effectiveIndex,
        selectedAnswer: answerText,
        isCorrect: question.isTextAnswerCorrect(answerText),
        idempotencyKey: resolvedKey,
      );
      final isCorrect = attempt.isCorrect;
      final starterFeedback = isCorrect
          ? null
          : buildStarterFreeTextFeedback(
              questionId: question.id,
              rawAnswer: answerText,
              uiLocale: uiLocale,
            );
      final wrongExplanation =
          starterFeedback ??
          question.localizedWrongFeedback(uiLocale) ??
          (uiLocale == 'ru'
              ? 'Проверьте правило и попробуйте ещё раз.'
              : 'Qoidani tekshirib, qayta urinib ko‘ring.');

      return LessonAnswerResult(
        isCorrect: isCorrect,
        selectedOption: answerText,
        correctOption: '',
        explanation: isCorrect
            ? (attempt.explanation ?? question.localizedExplanation(uiLocale))
            : (attempt.explanation ?? wrongExplanation),
        optionFeedback: starterFeedback,
      );
    }

    if (question.mode == QuestionMode.wordMatch) {
      final pairs = matchedPairs ?? const <String, String>{};
      if (pairs.isEmpty) {
        throw ArgumentError.value(matchedPairs, 'matchedPairs');
      }
      final sortedPairs = SplayTreeMap<String, String>.from(pairs);
      final serialized = jsonEncode(sortedPairs);
      final summary = pairs.entries
          .map((e) {
            final left = question.matchPairs
                .where((p) => p.id == e.key)
                .map((p) => p.left)
                .firstOrNull ?? e.key;
            return '$left → ${e.value}';
          })
          .join(', ');
      final isLocallyCorrect = question.isWordMatchCorrect(pairs);
      final attempt = await learnerRepository.recordAnswerAttemptIdempotent(
        courseId: question.courseId,
        skillId: question.skillId,
        lessonId: lessonId,
        questionId: question.id,
        selectedIndex: 0,
        selectedAnswer: serialized,
        isCorrect: isLocallyCorrect,
        idempotencyKey: resolvedKey,
      );
      final isPartial = pairs.length < question.matchPairs.length;
      final partialHint = isPartial
          ? (uiLocale == 'ru'
              ? 'Сопоставьте все пары (${pairs.length}/${question.matchPairs.length}). '
              : 'Barcha juftliklarni moslang (${pairs.length}/${question.matchPairs.length}). ')
          : '';
      final feedbackText = '$partialHint${question.localizedWrongFeedback(uiLocale) ?? ''}'.trim();
      final wrongExplanation = feedbackText.isNotEmpty
          ? feedbackText
          : (uiLocale == 'ru'
                ? 'Проверьте пары слов и попробуйте ещё раз.'
                : 'Juftliklarni tekshirib, qayta urinib ko‘ring.');
      return LessonAnswerResult(
        isCorrect: attempt.isCorrect,
        selectedOption: summary.isEmpty ? '—' : summary,
        correctOption: '',
        explanation: attempt.isCorrect
            ? (attempt.explanation ?? question.localizedExplanation(uiLocale))
            : (attempt.explanation ?? wrongExplanation),
        optionFeedback: !attempt.isCorrect && partialHint.isNotEmpty
            ? feedbackText
            : null,
      );
    }

    if (question.mode == QuestionMode.sentenceOrder) {
      final tokens = orderedTokens ?? const <String>[];
      if (tokens.isEmpty) {
        throw ArgumentError.value(orderedTokens, 'orderedTokens');
      }
      final joined = tokens.join(' ').trim();
      final serialized = jsonEncode(tokens);
      final isLocallyCorrect = question.isSentenceOrderCorrect(tokens);
      final attempt = await learnerRepository.recordAnswerAttemptIdempotent(
        courseId: question.courseId,
        skillId: question.skillId,
        lessonId: lessonId,
        questionId: question.id,
        selectedIndex: 0,
        selectedAnswer: serialized,
        isCorrect: isLocallyCorrect,
        idempotencyKey: resolvedKey,
      );
      final isPartial = tokens.length < question.orderedTokens.length;
      final partialHint = isPartial
          ? (uiLocale == 'ru'
              ? 'Расставьте все слова предложения (${tokens.length}/${question.orderedTokens.length}). '
              : 'Gapdagi barcha so‘zlarni tartiblang (${tokens.length}/${question.orderedTokens.length}). ')
          : '';
      final feedbackText = '$partialHint${question.localizedWrongFeedback(uiLocale) ?? ''}'.trim();
      final wrongExplanation = feedbackText.isNotEmpty
          ? feedbackText
          : (uiLocale == 'ru'
                ? 'Проверьте порядок слов и попробуйте ещё раз.'
                : 'So‘z tartibini tekshirib, qayta urinib ko‘ring.');
      return LessonAnswerResult(
        isCorrect: attempt.isCorrect,
        selectedOption: joined.isEmpty ? '—' : joined,
        correctOption: '',
        explanation: attempt.isCorrect
            ? (attempt.explanation ?? question.localizedExplanation(uiLocale))
            : (attempt.explanation ?? wrongExplanation),
        optionFeedback: !attempt.isCorrect && partialHint.isNotEmpty
            ? feedbackText
            : null,
      );
    }

    if (question.isSelfAssessed) {
      final responseText = (selectedText ?? '').trim();
      final sortedCriteria = [...(checkedCriteriaIds ?? const <String>[])]
        ..sort();
      final serialized = jsonEncode({
        'response': responseText,
        'criteria': sortedCriteria,
      });
      final attempt = await learnerRepository.recordAnswerAttemptIdempotent(
        courseId: question.courseId,
        skillId: question.skillId,
        lessonId: lessonId,
        questionId: question.id,
        selectedIndex: 0,
        selectedAnswer: serialized,
        isCorrect: responseText.isNotEmpty,
        idempotencyKey: resolvedKey,
      );
      return LessonAnswerResult(
        isCorrect: attempt.isCorrect,
        selectedOption: responseText,
        correctOption: '',
        explanation: attempt.explanation ?? question.localizedExplanation(uiLocale),
      );
    }

    final idx = selectedIndex!;
    final selectedOption = question.options[idx];
    final attempt = await learnerRepository.recordAnswerAttemptIdempotent(
      courseId: question.courseId,
      skillId: question.skillId,
      lessonId: lessonId,
      questionId: question.id,
      selectedIndex: idx,
      selectedAnswer: selectedOption,
      // Used only by the offline repository. Authenticated scoring is returned
      // by the server RPC and is read from `attempt.isCorrect` below.
      isCorrect: idx == question.correctIndex,
      idempotencyKey: resolvedKey,
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
    final correctOption =
        (serverCorrectOption != null && serverCorrectOption.isNotEmpty)
        ? serverCorrectOption
        : localCorrectOption;

    return LessonAnswerResult(
      isCorrect: isCorrect,
      selectedOption: selectedOption,
      correctOption: correctOption,
      explanation: attempt.explanation ?? question.localizedExplanation(uiLocale),
      optionFeedback: isCorrect
          ? null
          : question.localizedOptionFeedback(selectedOption, uiLocale),
    );
  }
}
