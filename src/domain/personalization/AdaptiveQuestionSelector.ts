import { Question } from '../entities/Question';

export interface AnswerHistoryItem {
  questionId: string;
  skillId: string;
  difficulty: 'easy' | 'medium' | 'hard';
  isCorrect: boolean;
}

export class AdaptiveQuestionSelector {
  /**
   * Selects the next adaptive question based on balanced skill coverage and dynamic difficulty adjustment
   */
  public static getNextQuestion(
    questionBank: Question[],
    targetSkillIds: string[],
    history: AnswerHistoryItem[],
    targetQuestionsPerSkill: number = 2
  ): Question | null {
    const answeredIds = new Set(history.map((h) => h.questionId));
    const unasked = questionBank.filter((q) => !answeredIds.has(q.id));

    if (unasked.length === 0) return null;

    // 1. Find which skill currently has the fewest questions answered
    const skillCounts: Record<string, number> = {};
    targetSkillIds.forEach((sid) => {
      skillCounts[sid] = history.filter((h) => h.skillId === sid).length;
    });

    // Sort skills by least answered
    const sortedSkills = [...targetSkillIds].sort(
      (a, b) => (skillCounts[a] || 0) - (skillCounts[b] || 0)
    );

    const candidateSkillId = sortedSkills[0];
    if (skillCounts[candidateSkillId] >= targetQuestionsPerSkill) {
      // All skills reached target count
      return null;
    }

    // 2. Determine target difficulty for candidateSkillId based on recent performance
    const skillHistory = history.filter((h) => h.skillId === candidateSkillId);
    let targetDifficulty: 'easy' | 'medium' | 'hard' = 'medium';

    if (skillHistory.length > 0) {
      const recent = skillHistory.slice(-2);
      const correctCount = recent.filter((r) => r.isCorrect).length;

      if (correctCount === recent.length && recent.length >= 1) {
        // Performing well -> increase difficulty
        const lastDiff = recent[recent.length - 1].difficulty;
        if (lastDiff === 'easy') targetDifficulty = 'medium';
        else if (lastDiff === 'medium') targetDifficulty = 'hard';
        else targetDifficulty = 'hard';
      } else if (correctCount === 0) {
        // Struggling -> decrease difficulty
        const lastDiff = recent[recent.length - 1].difficulty;
        if (lastDiff === 'hard') targetDifficulty = 'medium';
        else if (lastDiff === 'medium') targetDifficulty = 'easy';
        else targetDifficulty = 'easy';
      } else {
        targetDifficulty = 'medium';
      }
    }

    // 3. Find matching question in unasked pool
    let match = unasked.find(
      (q) => q.skillId === candidateSkillId && q.difficulty === targetDifficulty
    );

    // Fallback if exact difficulty is exhausted
    if (!match) {
      match = unasked.find((q) => q.skillId === candidateSkillId);
    }

    // Fallback to any remaining unasked question
    if (!match && unasked.length > 0) {
      match = unasked[0];
    }

    return match || null;
  }
}
