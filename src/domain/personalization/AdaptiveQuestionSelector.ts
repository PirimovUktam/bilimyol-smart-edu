import { Question } from '../entities/Question';

export interface AnswerHistoryItem {
  questionId: string;
  skillId: string;
  difficulty: 'easy' | 'medium' | 'hard';
  isCorrect: boolean;
}

export class AdaptiveQuestionSelector {
  /**
   * Determines the 1-step Markov difficulty transition from the latest answer
   * for a given skill, matching Mobile and SQL `next_placement_question`.
   */
  public static determineNextDifficulty(
    skillId: string,
    history: AnswerHistoryItem[],
    initialDifficulty: 'easy' | 'medium' | 'hard' = 'medium'
  ): 'easy' | 'medium' | 'hard' {
    const skillHistory = history.filter((h) => h.skillId === skillId);
    if (skillHistory.length === 0) {
      return initialDifficulty;
    }

    const last = skillHistory[skillHistory.length - 1];
    if (last.difficulty === 'medium') {
      return last.isCorrect ? 'hard' : 'easy';
    }
    if (last.difficulty === 'easy') {
      return last.isCorrect ? 'medium' : 'easy';
    }
    return last.isCorrect ? 'hard' : 'medium';
  }

  /**
   * Selects the next adaptive question based on balanced skill coverage and dynamic difficulty adjustment
   */
  public static getNextQuestion(
    questionBank: Question[],
    targetSkillIds: string[],
    history: AnswerHistoryItem[],
    targetQuestionsPerSkill: number = 2,
    initialDifficulty?: 'easy' | 'medium' | 'hard'
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
    const sortedSkills = targetSkillIds.filter((id) =>
      skillCounts[id] < targetQuestionsPerSkill && unasked.some((question) => question.skillId === id)
    ).sort(
      (a, b) => (skillCounts[a] || 0) - (skillCounts[b] || 0)
    );

    const candidateSkillId = sortedSkills[0];
    if (!candidateSkillId) return null;

    // 2. Determine target difficulty for candidateSkillId based on latest skill attempt
    // English placement starts at 'medium' (A2) so A2=1 -> B1 and A2=0 -> A1 within 2 items/skill.
    const defaultInitial: 'easy' | 'medium' | 'hard' = initialDifficulty ?? 'medium';
    const targetDifficulty = this.determineNextDifficulty(candidateSkillId, history, defaultInitial);

    // 3. Find matching question in unasked pool with difficulty-proximity fallback
    const proximityOrder: Record<'easy' | 'medium' | 'hard', Array<'easy' | 'medium' | 'hard'>> = {
      easy: ['easy', 'medium', 'hard'],
      medium: ['medium', 'easy', 'hard'],
      hard: ['hard', 'medium', 'easy'],
    };

    let match: Question | undefined;
    for (const diff of proximityOrder[targetDifficulty]) {
      match = unasked.find((q) => q.skillId === candidateSkillId && q.difficulty === diff);
      if (match) break;
    }

    return match || null;
  }
}
