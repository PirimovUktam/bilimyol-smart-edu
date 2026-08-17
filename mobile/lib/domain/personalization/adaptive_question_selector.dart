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
    List<AnswerHistoryItem> history,
  ) {
    final skillHistory = history.where((h) => h.skillId == skillId).toList();
    if (skillHistory.isEmpty) {
      return QuestionDifficulty.medium;
    }

    final last = skillHistory.last;
    if (last.difficulty == QuestionDifficulty.medium) {
      return last.isCorrect ? QuestionDifficulty.hard : QuestionDifficulty.easy;
    } else if (last.difficulty == QuestionDifficulty.easy) {
      return last.isCorrect ? QuestionDifficulty.medium : QuestionDifficulty.easy;
    } else {
      // hard
      return last.isCorrect ? QuestionDifficulty.hard : QuestionDifficulty.medium;
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

    // 1. Balance question distribution across target skills
    final skillCounts = <String, int>{};
    for (final sid in targetSkillIds) {
      skillCounts[sid] = history.where((h) => h.skillId == sid).length;
    }

    // Find skills that haven't reached their quota
    final pendingSkills = targetSkillIds
        .where((sid) => (skillCounts[sid] ?? 0) < targetQuestionsPerSkill)
        .toList();

    if (pendingSkills.isEmpty) {
      return null;
    }

    // Prioritize the skill with fewest answered questions
    pendingSkills.sort((a, b) => (skillCounts[a] ?? 0).compareTo(skillCounts[b] ?? 0));
    final nextSkillId = pendingSkills.first;

    // 2. Determine target difficulty
    final targetDiff = determineNextDifficulty(nextSkillId, history);

    // 3. Find candidate questions in bank matching skill & difficulty
    var candidates = questionBank.where((q) {
      return q.skillId == nextSkillId &&
          q.difficulty == targetDiff &&
          !askedQuestionIds.contains(q.id);
    }).toList();

    // Fallback: any unanswered question in the same skill
    if (candidates.isEmpty) {
      candidates = questionBank.where((q) {
        return q.skillId == nextSkillId && !askedQuestionIds.contains(q.id);
      }).toList();
    }

    // Ultimate fallback: any unanswered question in bank
    if (candidates.isEmpty) {
      candidates = questionBank.where((q) => !askedQuestionIds.contains(q.id)).toList();
    }

    if (candidates.isEmpty) return null;
    return candidates.first;
  }
}
