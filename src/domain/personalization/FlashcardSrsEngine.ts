import type { FlashcardSrsBucket, FlashcardSrsEntry } from '@/domain/entities/LearnerProfile';

export const SRS_INTERVALS_DAYS = [0, 1, 3, 7, 14] as const;

export function computeNextFlashcardSrs(
  existing: FlashcardSrsEntry | undefined,
  cardId: string,
  rating: 'need_practice' | 'remembered',
  now: Date = new Date(),
  intervalsDays: readonly number[] = SRS_INTERVALS_DAYS,
): FlashcardSrsEntry {
  const reviewCount = (existing?.reviewCount ?? 0) + 1;
  const nowIso = now.toISOString();

  if (rating === 'need_practice') {
    return {
      cardId,
      status: 'need_practice',
      bucket: 'need_practice',
      reviewCount,
      intervalDays: 0,
      lastReviewedAt: nowIso,
      nextReviewAt: nowIso,
    };
  }

  const normalizedIntervals = intervalsDays.length >= 2 ? intervalsDays : SRS_INTERVALS_DAYS;
  const currentIdx = existing?.status === 'remembered'
    ? normalizedIntervals.findIndex((days) => days >= existing.intervalDays)
    : 0;
  const nextIdx =
    existing?.status !== 'remembered' || existing.intervalDays < 1
      ? 1
      : Math.min(normalizedIntervals.length - 1, Math.max(1, currentIdx) + 1);

  const intervalDays = Math.max(1, normalizedIntervals[nextIdx] ?? 1);
  const bucket: FlashcardSrsBucket =
    intervalDays >= 7 ? 'mastered' : intervalDays >= 3 ? 'review' : 'learning';
  const nextReviewAt = new Date(now.getTime() + intervalDays * 86_400_000).toISOString();

  return {
    cardId,
    status: 'remembered',
    bucket,
    reviewCount,
    intervalDays,
    lastReviewedAt: nowIso,
    nextReviewAt,
  };
}

export function isFlashcardDue(entry: FlashcardSrsEntry | undefined, now: Date = new Date()): boolean {
  if (!entry) return true;
  if (entry.status === 'need_practice') return true;
  const dueMs = Date.parse(entry.nextReviewAt);
  if (!Number.isFinite(dueMs)) return true;
  return dueMs <= now.getTime();
}
