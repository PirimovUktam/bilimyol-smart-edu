import { translate as t } from '@/core/locales/useTranslation';
import { useTranslation } from '@/core/locales/useTranslation';
import { useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowRight,
  Award,
  BookOpen,
  Check,
  Clock,
  Compass,
  Layers,
  Lock,
  Mic,
  PenTool,
  Play,
  ShieldCheck,
  SlidersHorizontal,
  Sparkles,
  Zap,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { resolveNextLearningLesson, resolveRoadmapNodeLessonId } from '@/app/router/lessonResolution';
import { ENGLISH_ALL_FLASHCARD_ENTRIES } from '@/data/datasources/english/flashcards';
import { ENGLISH_CEFR_LEVELS } from '@/data/datasources/english/curriculum';
import { supabaseLessonRepository } from '@/data/repositories/SupabaseLessonRepository';
import type { LessonFlashcard } from '@/domain/entities/Lesson';
import type { LearningPathNode } from '@/domain/entities/LearningPathNode';
import type { CefrLevelId, Question } from '@/domain/entities/Question';
import { isFlashcardDue } from '@/domain/personalization/FlashcardSrsEngine';
import { foundationLessons, hasStartedCourse, pendingFoundationLesson } from '@/domain/personalization/learningStart';
import { AdaptiveCycleEngine } from '@/domain/personalization/AdaptiveCycleEngine';
import { RecommendationEngine } from '@/domain/personalization/RecommendationEngine';
import { AdaptiveCyclePanel } from '@/features/adaptive/AdaptiveCyclePanel';
import { FlashcardDeck } from '@/features/lesson/FlashcardDeck';
import { StudyPlanPreview } from '@/features/onboarding/StudyPlanPreview';
import { useStudyPlan } from '@/features/onboarding/useStudyPlan';
import { ReinforcementModal } from '@/features/reinforcement/ReinforcementModal';
import { Badge } from '@/presentation/components/Badge';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { PageHeader } from '@/presentation/components/PageHeader';
import { Progress } from '@/presentation/components/Progress';
import { SectionState } from '@/presentation/components/SectionState';

const filters = { get all() { return t('courses.all'); }, get active() { return t('path.openStages'); }, get completed() { return t('path.completed'); } } as const;

interface RoadmapViewProps {
  onStartLesson: (lessonId: string) => void;
  onOpenKnowledgeMap: () => void;
  onChooseCourse: () => void;
  onConfigure: () => void;
  onEditPlan?: () => void;
  onStartPlacement?: () => void;
}

export function RoadmapView({ onStartLesson, onOpenKnowledgeMap, onChooseCourse, onConfigure, onEditPlan, onStartPlacement }: RoadmapViewProps) {
  const { language, t } = useTranslation();
  const course = useCourseStore((state) => state.activeCourse);
  const skills = useCourseStore((state) => state.activeCourseSkills);
  const profile = useLearnerStore((state) => state.profile);
  const roadmap = useRoadmapStore((state) => state.roadmap);
  const error = useRoadmapStore((state) => state.error);
  const [filter, setFilter] = useState<keyof typeof filters>('all');
  const [practice, setPractice] = useState<Question | null>(null);
  const [practiceLoading, setPracticeLoading] = useState<string | null>(null);
  const [practiceError, setPracticeError] = useState('');
  const practiceRequest = useRef(0);
  const [lockedNoticeNodeId, setLockedNoticeNodeId] = useState<string | null>(null);
  const [showSrsHub, setShowSrsHub] = useState(false);
  const [srsHubSession, setSrsHubSession] = useState<{
    cards: LessonFlashcard[];
    startEmpty: boolean;
  }>({ cards: [], startEmpty: false });
  const courseId = course?.id;
  const isEnglishCourse = courseId === 'course_eng_01';

  useEffect(() => {
    if (courseId) void useRoadmapStore.getState().loadRoadmap(courseId);
    setLockedNoticeNodeId(null);
    setShowSrsHub(false);
    setPractice(null);
    setPracticeLoading(null);
    setPracticeError('');
    return () => { practiceRequest.current++; };
  }, [courseId]);

  const path = roadmap?.courseId === courseId ? roadmap : null;
  const nodes = useMemo(() => path?.nodes ?? [], [path?.nodes]);
  const topics = nodes.filter((node) => !node.isReinforcement && !node.isOptional);
  const policy = topics.find((node) => node.mastery);
  const completed = topics.filter((node) => node.status === 'completed').length;
  const lesson = resolveNextLearningLesson(course, profile, path);
  const foundation = pendingFoundationLesson(course, profile);
  const foundationPath = course ? foundationLessons(course) : [];
  const ready = Boolean(course && hasStartedCourse(course, profile));
  const foundationCompleted = foundationPath.filter((id) => profile?.completedLessonIds.includes(id)).length;
  const minutes = profile?.dailyMinutes ?? 15;
  const level = courseId && ready ? profile?.courseLevels?.[courseId] ?? 'intermediate' : null;
  const studyPlan = useStudyPlan(course, profile, path, level, profile?.goal ?? 'mastery', minutes);
  const plannedNext = studyPlan.sessions[0]?.items[0];
  const nextPlanId = !foundation && plannedNext?.ready ? plannedNext.id : null;
  const shown = nodes.filter((node) => filter === 'all' || (filter === 'active'
    ? node.status !== 'locked' && (node.status !== 'completed' || node.mastery?.reviewDue) : node.status === 'completed'));
  const courseScores = courseId ? profile?.scoresByCourse[courseId] ?? {} : {};
  const adaptiveCycle = path && !policy
    ? AdaptiveCycleEngine.evaluateCycle({ course, profile, skills, skillScores: courseScores, roadmap: path })
    : null;
  const adaptiveRec = path && !policy
    ? RecommendationEngine.generateRecommendation(courseId ?? '', skills, courseScores, path, profile)
    : null;

  const englishSrsMap = useMemo(
    () => (isEnglishCourse ? (profile?.flashcardSrsByCourse?.['course_eng_01'] ?? {}) : {}),
    [isEnglishCourse, profile?.flashcardSrsByCourse],
  );

  const unlockedEnglishFlashcards = useMemo(() => {
    if (!isEnglishCourse) return [];
    const unlockedLessonIds = new Set<string>([
      'lesson_eng_starter',
      'lesson_eng_foundation_02',
      ...nodes
        .filter((n) => n.status !== 'locked' && n.targetLessonId)
        .map((n) => n.targetLessonId as string),
      ...(profile?.completedLessonIds ?? []),
    ]);
    const pool = ENGLISH_ALL_FLASHCARD_ENTRIES
      .filter((entry) => unlockedLessonIds.has(entry.lessonId))
      .map((entry) => entry.card);
    return pool.length > 0 ? pool : ENGLISH_ALL_FLASHCARD_ENTRIES.map((entry) => entry.card);
  }, [isEnglishCourse, nodes, profile?.completedLessonIds]);

  const dueEnglishFlashcards = useMemo(() => {
    const due = unlockedEnglishFlashcards.filter((card) => isFlashcardDue(englishSrsMap[card.id]));
    const rank = (cardId: string): number => {
      const entry = englishSrsMap[cardId];
      if (entry?.status === 'need_practice') return 0;
      if (entry) return 1;
      return 2;
    };
    return due.sort((a, b) => {
      const ra = rank(a.id);
      const rb = rank(b.id);
      if (ra !== rb) return ra - rb;
      if (ra === 1) {
        return Date.parse(englishSrsMap[a.id]?.nextReviewAt ?? '') - Date.parse(englishSrsMap[b.id]?.nextReviewAt ?? '');
      }
      return 0;
    });
  }, [unlockedEnglishFlashcards, englishSrsMap]);

  const handleToggleSrsHub = () => {
    if (!showSrsHub) {
      const hasDue = dueEnglishFlashcards.length > 0;
      setSrsHubSession({
        cards: hasDue ? dueEnglishFlashcards : unlockedEnglishFlashcards,
        startEmpty: !hasDue,
      });
      setShowSrsHub(true);
    } else {
      setShowSrsHub(false);
    }
  };

  const loadPractice = async (node: LearningPathNode) => {
    const request = ++practiceRequest.current;
    const current = () => request === practiceRequest.current && useCourseStore.getState().activeCourse?.id === node.courseId;
    setPracticeLoading(node.id);
    setPracticeError('');
    try {
      const baseNode = topics.find((topic) => topic.skillId === node.skillId);
      const linked = baseNode?.targetLessonId
        ? await supabaseLessonRepository.getLessonById(baseNode.targetLessonId)
        : await supabaseLessonRepository.getLessonByCourseAndSkill(node.courseId, node.skillId);
      if (!current()) return;
      if (!linked || linked.courseId !== node.courseId || linked.skillId !== node.skillId || linked.reinforcementExercise.courseId !== node.courseId) {
        throw new Error(t('path.noExercise'));
      }
      setPractice(linked.reinforcementExercise);
    } catch {
      if (current()) setPracticeError(t('path.exerciseFailed'));
    } finally {
      if (current()) setPracticeLoading(null);
    }
  };

  const renderNodeCard = (node: LearningPathNode, index: number) => {
    const locked = node.status === 'locked';
    const done = node.status === 'completed';
    const isActive = path ? node.id === path.activeNodeId : false;
    const target = resolveRoadmapNodeLessonId(node);
    const Icon = locked
      ? Lock
      : done
      ? Check
      : node.isReinforcement
      ? Sparkles
      : node.nodeKind === 'level_assessment' || node.nodeKind === 'unit_checkpoint'
      ? Award
      : node.taskKind === 'speaking_prompt'
      ? Mic
      : node.taskKind === 'writing_prompt'
      ? PenTool
      : BookOpen;

    const localizedNodeTitle = (language === 'ru' && node.titleRu) ? node.titleRu : node.title;
    const localizedNodeDesc = (language === 'ru' && node.descriptionRu) ? node.descriptionRu : node.description;
    const localizedCanDo = (language === 'ru' && node.canDoObjectiveRu) ? node.canDoObjectiveRu : node.canDoObjective;
    const prerequisites = node.prerequisites.flatMap((id) => {
      const previous = nodes.find((item) => item.id === id);
      if (!previous) return [];
      return [(language === 'ru' && previous.titleRu) ? previous.titleRu : previous.title];
    });

    const iconBoxTone = done
      ? 'bg-mint/15 text-[#6EE7B7]'
      : locked
      ? 'bg-sand text-slatefine'
      : node.isReinforcement
      ? 'bg-amber/15 text-[#FCD34D]'
      : 'bg-brand/15 text-brand-dark';

    const showLockNotice = locked && lockedNoticeNodeId === node.id;
    const isCheckpointNode = node.nodeKind === 'unit_checkpoint' || node.nodeKind === 'level_assessment';
    const actionLabel = done || node.mastery?.state === 'needs_review'
      ? t('path.review')
      : isCheckpointNode
      ? t('path.startCheckpoint')
      : t('path.startLesson');

    return (
      <li
        key={node.id}
        data-node-id={node.id}
        data-node-kind={node.nodeKind ?? 'lesson'}
        data-has-rich-exercise={node.hasRichExercise ? 'true' : undefined}
        data-task-kind={node.taskKind ?? 'standard'}
        aria-current={isActive ? 'step' : undefined}
        style={{ animationDelay: `${index * 60}ms` }}
        className="fade-up"
      >
        <span
          className={
            'timeline-marker ' +
            (isActive
              ? 'timeline-current'
              : done
              ? 'bg-emerald-500! text-white! border-emerald-500!'
              : '')
          }
        >
          <Icon aria-hidden="true" className="size-4" />
        </span>
        <Card
          onClick={locked ? () => setLockedNoticeNodeId(node.id) : undefined}
          className={
            'edtech-card-hover flex min-w-0 flex-col justify-between gap-4 ' +
            (isActive ? 'ring-2 ring-brand/30 border-brand!' : '') +
            (locked ? ' cursor-pointer' : '')
          }
          padding="md"
        >
          {/* (a) Top: Icon Container + Status Badge + Kind Badge */}
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div className="flex flex-wrap items-center gap-2">
              <span className={`grid size-10 shrink-0 place-items-center rounded-xl ${iconBoxTone}`}>
                <Icon aria-hidden="true" className="size-5" />
              </span>
              <Badge
                variant={node.mastery?.reviewDue ? 'amber' : done ? 'emerald' : locked ? 'slate' :
                  node.status === 'reinforcement' || node.isReinforcement ? 'amber' : 'indigo'}
                size="sm"
              >
                {locked
                  ? t('path.locked')
                  : node.mastery?.reviewDue
                  ? t('path.scheduledReview')
                  : done
                  ? t(node.mastery ? 'path.mastered' : 'path.completed')
                  : node.mastery?.state === 'needs_review'
                  ? t('path.needsReview')
                  : node.isReinforcement
                  ? t('path.reinforce')
                  : isActive
                  ? t('lesson.nextStep')
                  : t('path.available')}
              </Badge>
              {node.nodeKind === 'unit_checkpoint' && (
                <Badge variant="amber" size="sm">{t('path.unitCheckpoint')}</Badge>
              )}
              {node.nodeKind === 'level_assessment' && (
                <Badge variant="purple" size="sm">{t('path.levelAssessment')}</Badge>
              )}
              {!locked && !done && !node.isReinforcement && node.routeStrategy === 'targeted_practice' && (
                <Badge variant="amber" size="sm">{t('path.targetedPracticeBadge')}</Badge>
              )}
              {!locked && !done && node.isPlacementRecommended && (
                <Badge variant="teal" size="sm">{t('path.placementRecommendedBadge')}</Badge>
              )}
              {node.taskKind === 'speaking_prompt' && (
                <Badge variant="teal" size="sm">Speaking</Badge>
              )}
              {node.taskKind === 'writing_prompt' && (
                <Badge variant="teal" size="sm">Writing</Badge>
              )}
            </div>
            {node.isOptional && <Badge variant="slate" size="sm">{t('path.optionalChallenge')}</Badge>}
          </div>

          {/* (b) Middle: Title, Can-Do, Description & Progress */}
          <div className="min-w-0 space-y-2">
            <h3 className="heading break-words text-lg font-extrabold">{localizedNodeTitle}</h3>
            {localizedCanDo && (
              <p className="text-xs font-semibold text-brand-dark">
                {t('path.canDoLabel')}: {localizedCanDo}
              </p>
            )}
            {localizedNodeDesc && (
              <p className="line-clamp-2 text-sm leading-relaxed text-slatefine">{localizedNodeDesc}</p>
            )}
            {!node.mastery && (isActive || node.isReinforcement || node.routeStrategy === 'targeted_practice') && (
              <div className="rounded-xl border border-brand/25 bg-sand/70 px-3 py-2 text-xs leading-relaxed text-graphite">
                <span className="font-extrabold text-brand-dark">{t('adaptive.xaiEyebrow')}: </span>
                <span>
                  {node.isReinforcement
                    ? adaptiveRec?.reason || localizedNodeDesc
                    : node.routeStrategy === 'targeted_practice' && !done
                    ? t('path.targetedPracticeHint', { score: node.score ?? 50 })
                    : adaptiveCycle?.loopUpdateSummary || localizedNodeDesc}
                </span>
              </div>
            )}
            {node.mastery && !locked && (
              <p className="text-xs font-semibold text-slatefine">
                {node.mastery.correct}/{node.mastery.requiredItems} {t('path.masteryEvidence')}
                {' · '}{node.mastery.passedCheckpoints}/{node.mastery.requiredCheckpoints} {t('path.masteryCheckpoints')}
              </p>
            )}
            {node.score != null && (
              <div className="max-w-md pt-1">
                <Progress
                  value={node.score}
                  size="sm"
                  tone={node.score >= 80 ? 'emerald' : 'indigo'}
                  ariaLabel={`${localizedNodeTitle} ${t('tutor.mastery')}`}
                />
              </div>
            )}
            {locked && prerequisites.length > 0 && (
              <p className="text-xs font-medium text-slatefine">{t('path.prerequisite')}{' '}{prerequisites.join(', ')}</p>
            )}
            {showLockNotice && (
              <p
                role="status"
                aria-live="polite"
                className="rounded-xl border border-amber/30 bg-amber/15 px-3 py-2 text-xs font-semibold text-ink"
              >
                {t('path.lockedInlineNotice', {
                  prerequisites: prerequisites.join(', ') || t('path.locked'),
                })}
              </p>
            )}
          </div>

          {/* (c) Bottom: Meta Data & Action Button */}
          <div className="flex flex-wrap items-center justify-between gap-3 border-t border-hairline pt-3">
            <p className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs font-bold text-slatefine">
              <span className="inline-flex items-center gap-1">
                <Clock aria-hidden="true" className="size-3.5 text-brand" />
                {node.estimatedMinutes}{' '}{t('courses.minutes')}</span>
              {!done && !locked && <span className="inline-flex items-center gap-1 text-[#FCD34D]">
                <Zap aria-hidden="true" className="size-3.5" />
                +20 XP
              </span>}
              {node.score != null && <span>{t('tutor.mastery')}{' '}{node.score}%</span>}
            </p>

            {locked ? (
              <Button
                size="sm"
                variant="outline"
                aria-expanded={showLockNotice}
                onClick={(event) => {
                  event.stopPropagation();
                  setLockedNoticeNodeId((prev) => (prev === node.id ? null : node.id));
                }}
                leftIcon={<Lock aria-hidden="true" className="size-3.5" />}
                className="min-h-11 opacity-85"
              >
                {t('path.lockedNoticeTrigger')}
              </Button>
            ) : (
              <div>
                {node.isReinforcement && !done ? (
                  <Button
                    size="sm"
                    variant="outline"
                    isLoading={practiceLoading === node.id}
                    disabled={practiceLoading !== null}
                    onClick={() => void loadPractice(node)}
                    className="min-h-11"
                  >{t('path.startExercise')}</Button>
                ) : target ? (
                  <Button
                    size="sm"
                    variant={done ? 'outline' : 'primary'}
                    onClick={() => {
                      useRoadmapStore.getState().selectNode(node);
                      onStartLesson(target);
                    }}
                    leftIcon={<Play aria-hidden="true" className="size-4" />}
                    className="min-h-11"
                  >
                    {actionLabel}
                  </Button>
                ) : (
                  !done && <p className="text-xs text-slatefine">{t('path.noLesson')}</p>
                )}
              </div>
            )}
          </div>
        </Card>
      </li>
    );
  };

  const renderEnglishGroupedRoadmap = () => {
    const completedNodeIds = new Set(
      nodes.filter((n) => n.status === 'completed').map((n) => n.id),
    );
    return (
      <div className="space-y-6">
        {ENGLISH_CEFR_LEVELS.map((levelMeta, levelIdx) => {
          const levelId: CefrLevelId = levelMeta.cefrLevel;
          const levelTitle = language === 'ru' ? levelMeta.titleRu : levelMeta.titleUz;
          const levelTitleClean = levelTitle.replace(new RegExp(`^${levelId}\\s*[—-]\\s*`), '');
          const levelCanDos = language === 'ru' ? levelMeta.canDoObjectivesRu : levelMeta.canDoObjectivesUz;
          const levelNodes = shown.filter((node) => (node.cefrLevel ?? 'A1') === levelId);
          const allLevelTopics = topics.filter((node) => (node.cefrLevel ?? 'A1') === levelId);
          const levelDoneCount = allLevelTopics.filter((n) => n.status === 'completed').length;
          const isA1 = levelId === 'A1';
          const prevLevelMeta = levelIdx > 0 ? ENGLISH_CEFR_LEVELS[levelIdx - 1] : undefined;
          const prevLevel = prevLevelMeta?.cefrLevel ?? 'A1';
          const requiredExitIds =
            levelMeta.prerequisites.length > 0
              ? levelMeta.prerequisites
              : prevLevelMeta?.exitAssessmentNodeId
              ? [prevLevelMeta.exitAssessmentNodeId]
              : [];
          const hasUnlockedTopic = allLevelTopics.some((n) => n.status !== 'locked');
          const hasPlacementRecommendedTopic = allLevelTopics.some((n) => n.isPlacementRecommended);
          const isDeferredLevel =
            (levelId === 'B2' || levelId === 'C1' || levelId === 'C2') && allLevelTopics.length === 0;
          const isLockedLevel =
            !isA1 &&
            !hasUnlockedTopic &&
            (allLevelTopics.length === 0 ||
              requiredExitIds.length === 0 ||
              !requiredExitIds.every((id) => completedNodeIds.has(id)));

          if (filter !== 'all' && levelNodes.length === 0 && !isA1) {
            return null;
          }

          return (
            <section
              key={levelId}
              data-cefr-level={levelId}
              aria-labelledby={`cefr-heading-${levelId}`}
              className="min-w-0 space-y-4"
            >
              {/* Level Header Card — NOTE: keep other CEFR level codes OUT of <h*> tags! */}
              <div className="edtech-card min-w-0 space-y-3 border border-hairline bg-paper p-5 sm:p-6">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="highlight">{t('path.levelBadge', { level: levelId })}</span>
                    <Badge variant={isLockedLevel ? 'slate' : levelDoneCount === allLevelTopics.length && allLevelTopics.length > 0 ? 'emerald' : 'indigo'} size="sm">
                      {isLockedLevel ? t('path.locked') : t('path.available')}
                    </Badge>
                    {hasPlacementRecommendedTopic && (
                      <Badge variant="teal" size="sm">{t('path.placementRecommendedBadge')}</Badge>
                    )}
                    {isDeferredLevel && (
                      <Badge variant="amber" size="sm">{t('path.deferredStageBadge')}</Badge>
                    )}
                  </div>
                  {allLevelTopics.length > 0 && (
                    <span className="text-xs font-bold text-slatefine">
                      {levelDoneCount} / {allLevelTopics.length} {t('path.topicsDone')}
                    </span>
                  )}
                </div>

                <h2 id={`cefr-heading-${levelId}`} className="heading break-words text-xl font-extrabold sm:text-2xl">
                  {levelId} — <span className="heading-accent">{levelTitleClean}</span>
                </h2>

                {levelCanDos.length > 0 && (
                  <ul className="space-y-1 text-xs leading-relaxed text-graphite sm:text-sm">
                    {levelCanDos.slice(0, 2).map((obj, idx) => (
                      <li key={idx} className="flex items-start gap-2">
                        <Check aria-hidden="true" className="mt-0.5 size-3.5 shrink-0 text-mint" />
                        <span>{obj}</span>
                      </li>
                    ))}
                  </ul>
                )}

                {isLockedLevel && (
                  <p className="rounded-xl border border-hairline bg-sand px-3 py-2 text-xs font-semibold text-slatefine">
                    {t('path.prerequisite')} {prevLevel}
                  </p>
                )}

                {isDeferredLevel && (
                  <p className="rounded-xl border border-amber/30 bg-amber/10 px-3 py-2 text-xs font-semibold text-ink">
                    {t('path.deferredStageNotice')}
                  </p>
                )}

                {allLevelTopics.length > 0 && (
                  <Progress
                    value={(100 * levelDoneCount) / allLevelTopics.length}
                    tone={levelDoneCount === allLevelTopics.length ? 'emerald' : 'indigo'}
                    size="sm"
                    ariaLabel={`${levelId} ${t('path.stageProgress')}`}
                  />
                )}
              </div>

              {/* Modules inside this level */}
              <div className="space-y-4">
                {levelMeta.modules.map((mod) => {
                  const modTitle = language === 'ru' ? mod.titleRu : mod.titleUz;
                  const modCanDo = language === 'ru' ? mod.canDoObjectiveRu : mod.canDoObjectiveUz;
                  const modNodes = levelNodes.filter((n) => n.moduleId === mod.id);
                  const modTopics = allLevelTopics.filter((n) => n.moduleId === mod.id);
                  const modDone = modTopics.filter((n) => n.status === 'completed').length;
                  const modPct = modTopics.length > 0 ? Math.round((100 * modDone) / modTopics.length) : 0;

                  if (modTopics.length > 0 && filter !== 'all' && modNodes.length === 0) {
                    return null;
                  }

                  return (
                    <div
                      key={mod.id}
                      className="edtech-card min-w-0 space-y-4 rounded-[22px] border border-hairline bg-paper p-4 sm:p-6"
                    >
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <span className="highlight">{t('path.moduleNumber', { order: mod.order })}</span>
                        {modTopics.length > 0 ? (
                          <Badge variant={modDone === modTopics.length ? 'emerald' : 'slate'} size="sm">
                            {modDone} / {modTopics.length}
                          </Badge>
                        ) : (
                          <Badge variant="slate" size="sm">{t('path.locked')}</Badge>
                        )}
                      </div>

                      <div className="min-w-0 space-y-1.5">
                        <p className="heading break-words text-base font-extrabold sm:text-lg">{modTitle}</p>
                        <p className="text-xs font-medium leading-relaxed text-slatefine sm:text-sm">
                          <span className="font-bold text-brand-dark">{t('path.canDoLabel')}: </span>
                          {modCanDo}
                        </p>
                      </div>

                      {modTopics.length > 0 ? (
                        <>
                          <Progress
                            value={modPct}
                            tone={modPct === 100 ? 'emerald' : 'indigo'}
                            size="sm"
                            ariaLabel={`${modTitle} ${t('path.progress')}`}
                          />
                          <ol className="learning-timeline">
                            {modNodes.map((node, idx) => renderNodeCard(node, idx))}
                          </ol>
                        </>
                      ) : (
                        <div className="space-y-2 rounded-xl border border-hairline bg-canvas p-3.5 text-xs text-slatefine">
                          <p className="font-bold text-graphite">{t('path.cefrPlannedScope')}</p>
                          <div className="flex flex-wrap gap-1.5">
                            {mod.grammarScope.slice(0, 2).map((item) => (
                              <span key={item} className="rounded-full border border-hairline bg-paper px-2.5 py-1 font-medium text-ink">
                                {item}
                              </span>
                            ))}
                            {mod.vocabularyThemes.slice(0, 2).map((item) => (
                              <span key={item} className="rounded-full border border-hairline bg-sand px-2.5 py-1 font-medium text-graphite">
                                {item}
                              </span>
                            ))}
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </section>
          );
        })}

        <p className="flex items-start gap-2 rounded-2xl border border-hairline bg-paper px-4 py-3 text-xs leading-relaxed text-slatefine">
          <ShieldCheck aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-brand" />
          <span>{t('path.cefrDisclaimer')}</span>
        </p>
      </div>
    );
  };

  return (
    <div className="learning-page space-y-6 sm:space-y-8">
      <PageHeader
        eyebrow={course?.title ?? t('path.curriculum')}
        title={t('path.title')}
        highlightWord={t('path.highlight')}
        description={t('path.description')}
        action={
          ready && <div className="flex flex-wrap gap-2">
            <Button variant="outline" leftIcon={<SlidersHorizontal aria-hidden="true" className="size-4 text-brand" />} onClick={onEditPlan ?? onConfigure}>{t('studyPlan.edit')}</Button>
            <Button variant="outline" leftIcon={<Compass aria-hidden="true" className="size-4 text-brand" />} onClick={onOpenKnowledgeMap}>{t('path.map')}</Button>
          </div>
        }
      />

      {ready && (path || foundation) && (
        <StudyPlanPreview
          wide
          sessions={studyPlan.sessions}
          minutes={minutes}
          status={studyPlan.loading ? 'loading' : studyPlan.unavailable ? 'unavailable' : 'empty'}
          action={nextPlanId ? { label: t('courses.continue'), run: () => onStartLesson(nextPlanId) } : undefined}
        />
      )}

      {!course ? (
        <Card className="space-y-4">
          <SectionState title={t('courses.chooseFirst')} />
          <Button onClick={onChooseCourse}>{t('courses.subjects')}</Button>
        </Card>
      ) : !ready ? (
        <Card className="space-y-4">
          <span className="highlight">{t('path.setup')}</span>
          <h2 className="heading text-xl font-extrabold">{t('path.where')}</h2>
          <p className="text-sm text-slatefine">{t('path.levelDescription')}</p>
          <Button onClick={onConfigure}>{t('path.start')}</Button>
        </Card>
      ) : foundation ? (
        <div className="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_18rem]">
          <section className="min-w-0 space-y-4" aria-labelledby="foundation-title">
            <div>
              <span className="highlight mb-2">{t('path.foundation')}</span>
              <h2 id="foundation-title" className="heading text-2xl font-extrabold">{t('courses.beginner')}{' '}<span className="heading-accent">{t('path.lessons')}</span>
              </h2>
            </div>
            <ol className="learning-timeline">
              {foundationPath.map((id, index) => {
                const done = profile?.completedLessonIds.includes(id) ?? false;
                const current = id === foundation;
                const entry = studyPlan.foundation.find((item) => item.id === id) ?? topics.find((node) => node.targetLessonId === id);
                return (
                  <li key={id} aria-current={current ? 'step' : undefined} style={{ animationDelay: `${index * 80}ms` }} className="fade-up">
                    <span className={'timeline-marker ' + (current ? 'timeline-current' : done ? 'bg-emerald-500! text-white! border-emerald-500!' : '')}>
                      {done ? <Check aria-hidden="true" className="size-4" /> : index + 1}
                    </span>
                    <Card
                      className={'edtech-card-hover flex min-w-0 flex-wrap items-center justify-between gap-4 ' + (current ? 'ring-2 ring-brand/30 border-brand!' : '')}
                      padding="sm"
                    >
                      <div className="space-y-1">
                        <Badge variant={done ? 'emerald' : current ? 'indigo' : 'slate'} size="sm">
                          {done ? t('path.completed') : current ? t('path.nextLesson') : t('path.nextStage')}
                        </Badge>
                        <h3 className="heading text-base font-extrabold">{entry ? (language === 'ru' ? entry.titleRu ?? entry.title : entry.title) : `${index + 1}${t('path.foundationNumber')}`}</h3>
                      </div>
                      {(current || done) && (
                        <Button variant={current ? 'primary' : 'outline'} size="sm" onClick={() => onStartLesson(id)}>
                          {current ? t('path.openFoundation') : t('path.review')}
                        </Button>
                      )}
                    </Card>
                  </li>
                );
              })}
            </ol>
          </section>
          <Card className="fade-up stagger-2 space-y-3" padding="md">
            <span className="highlight">{t('path.progress')}</span>
            <h2 className="heading text-lg font-extrabold">{t('path.result')}</h2>
            <p className="text-sm text-slatefine">
              {foundationCompleted} / {foundationPath.length}{t('path.lessonsDone')}</p>
            <Progress value={(100 * foundationCompleted) / foundationPath.length} tone="emerald" ariaLabel={t('path.foundationProgress')} />
            {isEnglishCourse && onStartPlacement && (
              <Button variant="outline" size="sm" onClick={onStartPlacement} className="min-h-11 w-full">
                {t('path.takePlacementFromFoundation')}
              </Button>
            )}
          </Card>
        </div>
      ) : error && !path ? (
        <SectionState
          kind="error"
          title={t('path.failed')}
          description={error}
          onRetry={() => void useRoadmapStore.getState().loadRoadmap(course.id)}
        />
      ) : !path ? (
        <SectionState kind="loading" title={t('path.loading')} />
      ) : (
        <>
          <section className="grid items-center gap-4 rounded-3xl border border-hairline bg-paper p-5 sm:grid-cols-[minmax(0,1fr)_auto]">
            <div className="min-w-0 space-y-2">
              {isEnglishCourse && <p className="text-xs font-semibold text-brand-dark">{t('path.cefrLevelsEyebrow')}</p>}
              <h2 className="heading text-lg font-extrabold">
                {completed} / {topics.length} {t(policy ? 'path.masteredTopics' : 'path.topicsDone')}</h2>
              {topics.length > 0 && (
                <Progress
                  value={(100 * completed) / topics.length}
                  tone="cyan"
                  size="sm"
                  className="max-w-sm"
                  ariaLabel={t('path.stageProgress')}
                />
              )}
            </div>
            <div className="flex flex-wrap items-center gap-2">
              {isEnglishCourse && (
                <Button
                  variant="outline"
                  aria-expanded={showSrsHub}
                  leftIcon={<Layers aria-hidden="true" className="size-4" />}
                  className="min-h-11 w-fit"
                  onClick={handleToggleSrsHub}
                >
                  {t('path.srsHubButton')} ({dueEnglishFlashcards.length})
                </Button>
              )}
              {lesson && !nextPlanId && (
                <Button
                  variant="outline"
                  className="min-h-11 w-fit"
                  onClick={() => onStartLesson(lesson)}
                  rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}
                >{t('courses.continue')}</Button>
              )}
            </div>
          </section>

          {isEnglishCourse && showSrsHub && (
            <section
              aria-label={t('path.srsHubTitle')}
              className="edtech-card min-w-0 space-y-4 border border-hairline bg-paper p-5 sm:p-6"
            >
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="space-y-1">
                  <span className="highlight">{t('path.srsDueCount', { count: dueEnglishFlashcards.length })}</span>
                  <h2 className="heading text-lg font-extrabold sm:text-xl">{t('path.srsHubTitle')}</h2>
                </div>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => setShowSrsHub(false)}
                  className="min-h-11"
                >
                  {t('path.srsCloseHub')}
                </Button>
              </div>
              <FlashcardDeck
                cards={srsHubSession.cards}
                srsMap={englishSrsMap}
                startEmptyWhenAllDone={srsHubSession.startEmpty}
                onRateCard={(cardId, rating, intervalsDays) => {
                  void useLearnerStore
                    .getState()
                    .recordFlashcardSrs('course_eng_01', cardId, rating, intervalsDays);
                }}
              />
            </section>
          )}

          {policy?.mastery && (
            <p className="text-sm font-medium leading-relaxed text-slatefine">
              {t('path.masteryPolicy', { items: policy.mastery.requiredItems, score: policy.requiredScore })}
            </p>
          )}

          {adaptiveCycle && adaptiveRec && (
            <AdaptiveCyclePanel
              compact
              cycle={adaptiveCycle}
              factors={adaptiveRec.explainableFactors ?? []}
              dailyTasks={adaptiveRec.dailyMicroTasks ?? []}
              onStepAction={(stepKey) => {
                if (stepKey === 'profile') onOpenKnowledgeMap();
                else if (stepKey === 'diagnostic') onConfigure();
                else if (stepKey === 'practice' && lesson) onStartLesson(lesson);
              }}
            />
          )}

          <div role="group" aria-label={t('path.filter')} className="fade-up stagger-2 flex flex-wrap gap-2">
            {(Object.keys(filters) as (keyof typeof filters)[]).map((key) => (
              <Button
                key={key}
                variant={filter === key ? 'primary' : 'outline'}
                aria-pressed={filter === key}
                size="sm"
                onClick={() => setFilter(key)}
                className="min-h-11"
              >
                {filters[key]}
              </Button>
            ))}
          </div>

          {practiceError && (
            <p role="alert" className="rounded-2xl border border-coral/25 bg-coral/10 p-3.5 text-sm text-ink">
              {practiceError}
            </p>
          )}
          {shown.length === 0 && (
            <SectionState title={nodes.length ? t('path.emptyFilter') : t('path.empty')} />
          )}

          {isEnglishCourse ? (
            renderEnglishGroupedRoadmap()
          ) : (
            <ol className="learning-timeline">
              {shown.map((node, index) => renderNodeCard(node, index))}
            </ol>
          )}
        </>
      )}
      {practice && practice.courseId === courseId && (
        <ReinforcementModal
          isOpen
          question={practice}
          courseId={practice.courseId}
          skillId={practice.skillId}
          onClose={() => setPractice(null)}
          onSuccess={() => {
            setPractice(null);
            void useLearnerStore
              .getState()
              .loadProfile()
              .catch(() => setPracticeError(t('path.refreshProfile')));
          }}
        />
      )}
    </div>
  );
}
