import { ICourseRepository } from '../repositories/ICourseRepository';
import { ILearnerRepository } from '../repositories/ILearnerRepository';
import { QuestionAnswerSubmission } from '../entities/Question';
import { AssessmentResult } from '../entities/Assessment';
import { SkillScoringEngine } from '../personalization/SkillScoringEngine';

export class SubmitPlacementTestUseCase {
  constructor(
    private courseRepo: ICourseRepository,
    private learnerRepo: ILearnerRepository
  ) {}

  async execute(courseId: string, submissions: QuestionAnswerSubmission[]): Promise<AssessmentResult> {
    if (submissions.length === 0) throw new Error('Placement javoblari bo‘sh bo‘lishi mumkin emas.');
    const questions = await this.courseRepo.getPlacementQuestions(courseId);
    const questionsById = new Map(questions.map((question) => [question.id, question]));
    const submittedIds = new Set<string>();
    // Validate the entire adaptive submission before evaluating or writing any
    // answers. A partial bank is valid; unknown or repeated questions are not.
    for (const submission of submissions) {
      const question = questionsById.get(submission.questionId);
      if (!question || question.courseId !== courseId) {
        throw new Error(`Placement savoli kursda topilmadi: ${submission.questionId}`);
      }
      if (submittedIds.has(submission.questionId)) {
        throw new Error(`Placement savoli takrorlangan: ${submission.questionId}`);
      }
      if (!Number.isInteger(submission.selectedIndex) || submission.selectedIndex < 0 || submission.selectedIndex >= question.options.length) {
        throw new Error(`Tanlangan javob indeksi noto‘g‘ri: ${submission.questionId}`);
      }
      submittedIds.add(submission.questionId);
    }

    // The repository returns the authoritative result in production; never
    // score placement from a client-supplied isCorrect flag. Production uses a
    // read-only evaluation followed by one atomic placement persistence RPC;
    // demo repositories retain the local audit-write path.
    const verifiedSubmissions = submissions.map((submission) => ({ ...submission, isCorrect: false }));
    for (const sub of verifiedSubmissions) {
      const q = questionsById.get(sub.questionId)!;
      if (this.learnerRepo.supportsServerPlacementPersistence) {
        const evaluation = await this.learnerRepo.evaluatePlacementAnswer(courseId, q.id, sub.selectedIndex);
        sub.isCorrect = evaluation.isCorrect;
      } else {
        const isCorrect = q.correctIndex !== undefined
          ? sub.selectedIndex === q.correctIndex
          : (await this.learnerRepo.evaluatePlacementAnswer(courseId, q.id, sub.selectedIndex)).isCorrect;
        const attempt = await this.learnerRepo.recordAnswerAttempt({
          courseId,
          skillId: q.skillId,
          lessonId: 'placement_test',
          questionId: q.id,
          selectedIndex: sub.selectedIndex,
          selectedAnswer: q.options[sub.selectedIndex] || '',
          isCorrect,
        });
        sub.isCorrect = attempt.isCorrect;
      }
    }

    // Compute real scores strictly from actual submissions
    let computedScores = SkillScoringEngine.computePlacementScores(courseId, questions, verifiedSubmissions);
    const overallScore = SkillScoringEngine.computeOverallScore(computedScores);

    // Find weakest skill dynamically
    const findWeakestSkillId = (scores: typeof computedScores): string =>
      Object.values(scores).reduce(
        (weakest, score) => score.score < weakest.score ? score : weakest,
        { score: 101, skillId: '' }
      ).skillId;
    let weakestSkillId = findWeakestSkillId(computedScores);

    // Save placement attempt & individual answers to Supabase / repository
    const attemptId = await this.learnerRepo.savePlacementAttempt({
      courseId,
      score: overallScore,
      weakestSkillId,
      submissions: verifiedSubmissions.map((s) => ({
        questionId: s.questionId,
        selectedIndex: s.selectedIndex,
        isCorrect: s.isCorrect,
      })),
    });

    // The production placement RPC already awards completion/answer XP and
    // records activity atomically. Keep the local path for demo mode only.
    if (this.learnerRepo.supportsServerPlacementPersistence) {
      const profile = await this.learnerRepo.getProfile();
      computedScores = profile.scoresByCourse[courseId] || {};
      weakestSkillId = findWeakestSkillId(computedScores);
    } else {
      await this.learnerRepo.saveSkillScores(courseId, computedScores);
      await this.learnerRepo.addXp(20, `placement_completed_${courseId}`);
      await this.learnerRepo.recordDailyActivity();
    }

    return {
      assessmentId: attemptId || `placement_${courseId}`,
      courseId,
      submissions: verifiedSubmissions,
      computedScores,
      weakestSkillId,
      timestamp: Date.now(),
    };
  }
}
