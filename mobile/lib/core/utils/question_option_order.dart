import '../../domain/entities/question.dart';

/// Stable, deterministic option ordering for the bundled question banks.
///
/// The placement bank was authored with the correct answer always at index 0,
/// making every diagnostic trivially guessable ("always A"). We permute the
/// options per question id so the correct answer lands at a varied position,
/// while moving the answer key together with its option (so correctness is
/// always preserved). The result is a pure function of the id, so scoring and
/// the UI always agree.
int _stableHash(String value) {
  var hash = 2166136261;
  for (var i = 0; i < value.length; i++) {
    hash ^= value.codeUnitAt(i);
    hash = (hash * 16777619) & 0xFFFFFFFF;
  }
  return hash;
}

Question permuteQuestionOptions(Question question) {
  final options = question.options;
  if (options.length < 2) return question;

  final current = question.correctIndex;
  if (current < 0 || current >= options.length) return question;

  final target = _stableHash(question.id) % options.length;
  if (target == current) return question;

  final correctOption = options[current];
  final remaining = [...options]..removeAt(current);
  remaining.insert(target, correctOption);

  return Question(
    id: question.id,
    courseId: question.courseId,
    skillId: question.skillId,
    text: question.text,
    contextSnippet: question.contextSnippet,
    options: remaining,
    correctIndex: target,
    difficulty: question.difficulty,
    explanation: question.explanation,
    formulaLatex: question.formulaLatex,
    audioSimText: question.audioSimText,
    audioSimSpeaker: question.audioSimSpeaker,
  );
}