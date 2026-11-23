import { useEffect, useState } from 'react';
import type { DailyTimeCommitment, InitialLevel, OnboardingGoal } from '@/core/types/common';
import { supabaseLessonRepository } from '@/data/repositories/SupabaseLessonRepository';
import type { Course } from '@/domain/entities/Course';
import type { LearnerProfile } from '@/domain/entities/LearnerProfile';
import type { LearningPath } from '@/domain/entities/LearningPathNode';
import { pendingFoundationLessons } from '@/domain/personalization/learningStart';
import { buildStudyPlan, type PlanLesson } from '@/domain/personalization/studyPlan';

export function useStudyPlan(
  course: Course | null, profile: LearnerProfile | null, path: LearningPath | null,
  level: InitialLevel | null, goal: OnboardingGoal, minutes: DailyTimeCommitment,
) {
  const courseId = course?.id;
  const pending = pendingFoundationLessons(course, profile, level);
  const matchingPath = path?.courseId === courseId ? path : null;
  const linked = new Map<string, PlanLesson>();
  for (const node of matchingPath?.nodes ?? []) {
    if (node.courseId === courseId && node.targetLessonId && node.estimatedMinutes > 0) {
      linked.set(node.targetLessonId, { ...node, id: node.targetLessonId });
    }
  }
  const missing = pending.filter((id) => !linked.has(id)).join('|');
  const [fetched, setFetched] = useState<{ courseId: string; key: string; lessons: PlanLesson[] }>();
  const cached = fetched?.courseId === courseId && fetched?.key === missing ? fetched : null;

  useEffect(() => {
    if (!courseId || !missing) return;
    let active = true;
    void Promise.all(missing.split('|').map((id) => supabaseLessonRepository.getLessonById(id).catch(() => null)))
      .then((lessons) => {
        if (active) setFetched({
          courseId, key: missing,
          lessons: lessons.flatMap((lesson) => lesson?.courseId === courseId && lesson.estimatedMinutes > 0 ? [lesson] : []),
        });
      });
    return () => { active = false; };
  }, [courseId, missing]);

  const foundation = pending.flatMap((id) => {
    const lesson = linked.get(id) ?? cached?.lessons.find((entry) => entry.id === id);
    return lesson ? [lesson] : [];
  });
  const loading = Boolean(missing && !cached);
  const unavailable = pending.length !== foundation.length && !loading;
  const sessions = courseId && level && !loading && !unavailable
    ? buildStudyPlan(courseId, matchingPath, foundation, profile?.completedLessonIds ?? [], goal, minutes)
    : [];
  return { sessions, loading, unavailable, foundation };
}
