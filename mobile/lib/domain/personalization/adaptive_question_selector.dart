import '../entities/question.dart';

class AnswerHistoryItem {
  final String questionId;
  final String skillId;
  final QuestionDifficulty difficulty;
  final bool isCorrect;

  const AnswerHistoryItem({
    required this.questionId,
    required this.skillId,
    required this.difficulty,
    required this.isCorrect,
  });
}

class AdaptiveQuestionSelector {
  /// Determines the target difficulty for the next question for a given skill.
  /// Standard progression:
  /// - Default / Initial: medium
  /// - If medium was answered correctly: hard
  /// - If medium or easy was missed: easy
  /// - If easy was answered correctly: medium
  /// - If hard was missed: medium
  static QuestionDifficulty determineNextDifficulty(
    String skillId,
    List<AnswerHistoryItem> history, {
    QuestionDifficulty initialDifficulty = QuestionDifficulty.medium,
  }) {
    final skillHistory = history.where((h) => h.skillId == skillId).toList();
    if (skillHistory.isEmpty) {
      return initialDifficulty;
    }

    final last = skillHistory.last;
    if (last.difficulty == QuestionDifficulty.medium) {
      return last.isCorrect ? QuestionDifficulty.hard : QuestionDifficulty.easy;
    } else if (last.difficulty == QuestionDifficulty.easy) {
      return last.isCorrect
          ? QuestionDifficulty.medium
          : QuestionDifficulty.easy;
    } else {
      // hard
      return last.isCorrect
          ? QuestionDifficulty.hard
          : QuestionDifficulty.medium;
    }
  }

  /// Selects the next adaptive question from the bank
  static Question? getNextQuestion(
    List<Question> questionBank,
    List<String> targetSkillIds,
    List<AnswerHistoryItem> history, [
    int targetQuestionsPerSkill = 2,
  ]) {
    final askedQuestionIds = history.map((h) => h.questionId).toSet();
    final unasked = questionBank
        .where((q) => !askedQuestionIds.contains(q.id))
        .toList();

    // 1. Balance question distribution across target skills
    final skillCounts = <String, int>{};
    for (final sid in targetSkillIds) {
      skillCounts[sid] = history.where((h) => h.skillId == sid).length;
    }

    // Find skills that haven't reached their quota
    final pendingSkills = targetSkillIds
        .where(
          (sid) =>
              (skillCounts[sid] ?? 0) < targetQuestionsPerSkill &&
              unasked.any((q) => q.skillId == sid),
        )
        .toList();

    if (pendingSkills.isEmpty) {
      return null;
    }

    // Prioritize the skill with fewest answered questions
    pendingSkills.sort(
      (a, b) => (skillCounts[a] ?? 0).compareTo(skillCounts[b] ?? 0),
    );
    final nextSkillId = pendingSkills.first;
    final candidates = unasked.where((q) => q.skillId == nextSkillId).toList();
    final isEnglish = candidates.any((q) => q.courseId == 'course_eng_01');

    // 2. Determine target difficulty (English A1-B1 starts at easy/A1)
    final targetDiff = determineNextDifficulty(
      nextSkillId,
      history,
      initialDifficulty: isEnglish
          ? QuestionDifficulty.easy
          : QuestionDifficulty.medium,
    );

    // 3. Find candidate questions matching skill & nearest difficulty
    final fallbackOrder = switch (targetDiff) {
      QuestionDifficulty.easy => const [
        QuestionDifficulty.easy,
        QuestionDifficulty.medium,
        QuestionDifficulty.hard,
      ],
      QuestionDifficulty.medium => const [
        QuestionDifficulty.medium,
        QuestionDifficulty.easy,
        QuestionDifficulty.hard,
      ],
      QuestionDifficulty.hard => const [
        QuestionDifficulty.hard,
        QuestionDifficulty.medium,
        QuestionDifficulty.easy,
      ],
    };
    for (final diff in fallbackOrder) {
      final match = candidates.where((q) => q.difficulty == diff).firstOrNull;
      if (match != null) return match;
    }
    return candidates.first;
  }
}
