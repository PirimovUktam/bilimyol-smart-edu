import { useEffect, useState } from 'react';
import { ArrowRight, BookOpenCheck, ChartNoAxesCombined, Clock, Flame, Sparkles, Target, Trophy, Zap, type LucideIcon } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import type { DailyActivitySummary } from '@/domain/repositories/ILearnerRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { Badge } from '@/presentation/components/Badge';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { PageHeader } from '@/presentation/components/PageHeader';
import { Progress } from '@/presentation/components/Progress';
import { SectionState } from '@/presentation/components/SectionState';
import { WeeklyActivity } from '@/presentation/components/WeeklyActivity';

interface ProgressViewProps {
  onContinueLesson: () => void;
  onOpenRoadmap: () => void;
  onOpenKnowledgeMap: () => void;
}

export function ProgressView({ onContinueLesson, onOpenRoadmap, onOpenKnowledgeMap }: ProgressViewProps) {
  const activeCourse = useCourseStore((state) => state.activeCourse);
  const courses = useCourseStore((state) => state.courses);
  const skills = useCourseStore((state) => state.activeCourseSkills);
  const profile = useLearnerStore((state) => state.profile);
  const [period, setPeriod] = useState<7 | 30>(7);
  const [activity, setActivity] = useState<DailyActivitySummary[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setActivity(null);
    setFailed(false);
    void supabaseLearnerRepository.getDailyActivity(period).then(
      (days) => { if (active) setActivity(days); },
      () => { if (active) setFailed(true); },
    );
    return () => { active = false; };
  }, [period, retry]);

  const totals = activity?.reduce((total, day) => ({
    questions: total.questions + (day.questionsAnswered ?? 0),
    correct: total.correct + (day.correctAnswers ?? 0),
    minutes: total.minutes + day.activeMinutes,
  }), { questions: 0, correct: 0, minutes: 0 });
  const accuracy = totals && totals.questions > 0 ? Math.round(100 * totals.correct / totals.questions) : null;
  const scores = activeCourse ? profile?.scoresByCourse[activeCourse.id] ?? {} : {};
  const completed = new Set(profile?.completedLessonIds);
  const evaluated = skills.flatMap((skill) => scores[skill.id] ? [{ ...skill, score: scores[skill.id].score }] : [])
    .sort((a, b) => b.score - a.score);
  const achievements = [
    { title: 'Ilk qadam', description: 'Birinchi dars yakunlandi', earned: completed.size >= 1 },
    { title: 'Muntazam o‘quvchi', description: '7 kun ketma-ket o‘qish', earned: (profile?.streakDays ?? 0) >= 7 },
    { title: 'Beshta marraga yetildi', description: '5 ta dars yakunlandi', earned: completed.size >= 5 },
  ];

  return (
    <div className="learning-page space-y-6 sm:space-y-8">
      <PageHeader
        title="Ta’lim ko‘rsatkichlari"
        highlightWord="ko‘rsatkichlari"
        eyebrow="Natijalar"
        description="Darslar, mashqlar va o‘qish odatingiz qanday o‘zgarayotganini kuzating."
        action={
          <Button onClick={onContinueLesson} rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}>
            Darsga qaytish
          </Button>
        }
      />

      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <Stat icon={Clock} tone="bg-indigo-50 text-brand" label="O‘qish vaqti" value={totals ? totals.minutes + ' daqiqa' : '—'} index={0} />
        <Stat icon={BookOpenCheck} tone="bg-emerald-50 text-mint" label="Yakunlangan darslar" value={String(completed.size)} index={1} />
        <Stat icon={Flame} tone="bg-amber-50 text-amber-600" label="Ketma-ketlik" value={(profile?.streakDays ?? 0) + ' kun'} index={2} />
        <Stat icon={Zap} tone="bg-sky-50 text-path" label="Jamg‘arilgan XP" value={String(profile?.xp ?? 0)} index={3} />
      </div>

      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_minmax(16rem,21rem)]">
        <Card className="fade-up stagger-2 min-w-0 space-y-4" padding="md">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <span className="highlight mb-1.5">Statistika</span>
              <h2 className="heading flex items-center gap-2 text-xl font-extrabold">
                <ChartNoAxesCombined aria-hidden="true" className="size-5 text-brand" /> O‘qish <span className="heading-accent">faolligi</span>
              </h2>
            </div>
            <div role="group" aria-label="Vaqt oralig‘i" className="flex gap-1 rounded-xl bg-sand p-1">
              {([7, 30] as const).map((days) => (
                <Button
                  key={days}
                  size="sm"
                  variant={period === days ? 'primary' : 'ghost'}
                  aria-pressed={period === days}
                  onClick={() => setPeriod(days)}
                >
                  {days} kun
                </Button>
              ))}
            </div>
          </div>
          {failed ? (
            <SectionState kind="error" title="Faollik yuklanmadi" onRetry={() => setRetry((n) => n + 1)} />
          ) : activity ? (
            <WeeklyActivity days={activity} />
          ) : (
            <SectionState kind="loading" title="Faollik yuklanmoqda…" />
          )}
        </Card>

        <Card className="fade-up stagger-3 flex flex-col justify-between space-y-4" padding="md">
          <div className="space-y-2">
            <span className="highlight">Aniqlik</span>
            <h2 className="heading flex items-center gap-2 text-xl font-extrabold">
              <Target aria-hidden="true" className="size-5 text-brand" /> Mashqlar <span className="heading-accent">natijasi</span>
            </h2>
          </div>
          {accuracy == null ? (
            <p className="text-sm leading-relaxed text-slatefine">
              {totals ? 'Bu davrda baholangan mashqlar yo‘q.' : 'Hisoblanmoqda…'}
            </p>
          ) : (
            <div className="space-y-3">
              <p className="heading text-4xl font-extrabold text-ink">{accuracy}%</p>
              <Progress value={accuracy} ariaLabel="Mashqlardagi to‘g‘ri javoblar ulushi" tone="emerald" />
              <p className="text-sm font-medium text-slatefine">
                {totals?.questions} javobdan {totals?.correct} tasi to‘g‘ri
              </p>
            </div>
          )}
        </Card>
      </div>

      <div className="grid gap-5 lg:grid-cols-2">
        <Card className="fade-up stagger-3 space-y-4" padding="md">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <span className="highlight mb-1">Katalog bo‘yicha</span>
              <h2 className="heading text-xl font-extrabold">
                Fanlar bo‘yicha <span className="heading-accent">natijalar</span>
              </h2>
            </div>
            <Button size="sm" variant="ghost" onClick={onOpenRoadmap}>
              Ta’lim yo‘li
            </Button>
          </div>
          {courses.length ? (
            <ul className="space-y-3">
              {courses.map((course) => {
                const subjectScores = profile?.scoresByCourse[course.id] ?? {};
                const scored = Object.keys(subjectScores).length > 0;
                const lessonCount = course.lessons.filter((id) => completed.has(id)).length;
                return (
                  <li key={course.id} className="space-y-2.5 rounded-2xl border border-hairline bg-canvas/70 p-4">
                    <div className="flex flex-wrap justify-between gap-2 text-sm">
                      <strong className="heading font-extrabold">{course.title}</strong>
                      {course.lessons.length > 0 && (
                        <Badge variant="indigo" size="sm">
                          {lessonCount} / {course.lessons.length} dars
                        </Badge>
                      )}
                    </div>
                    {scored ? (
                      <Progress
                        value={SkillScoringEngine.computeOverallScore(subjectScores)}
                        size="sm"
                        ariaLabel="Baholangan mavzular"
                        showLabel
                      />
                    ) : (
                      <p className="text-xs font-medium text-slatefine">Baholash hali o‘tkazilmagan.</p>
                    )}
                  </li>
                );
              })}
            </ul>
          ) : (
            <p className="text-sm text-slatefine">Kurs natijalari hali mavjud emas.</p>
          )}
        </Card>

        <Card className="fade-up stagger-4 space-y-4" padding="md">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <span className="highlight mb-1">Ko‘nikmalar</span>
              <h2 className="heading text-xl font-extrabold">
                Mavzular <span className="heading-accent">tahlili</span>
              </h2>
            </div>
            <Button size="sm" variant="ghost" onClick={onOpenKnowledgeMap}>
              Bilim xaritasi
            </Button>
          </div>
          {evaluated.length ? (
            <ul className="space-y-3.5">
              {evaluated.map((skill) => (
                <li key={skill.id} className="rounded-2xl border border-hairline bg-canvas/50 p-3.5">
                  <Progress
                    value={skill.score}
                    ariaLabel={skill.name}
                    showLabel
                    tone={skill.score >= 80 ? 'emerald' : skill.score < 50 ? 'amber' : 'indigo'}
                  />
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-sm text-slatefine">
              Diagnostika yoki darsdan keyin kuchli va mustahkamlash kerak bo‘lgan mavzular ko‘rinadi.
            </p>
          )}
        </Card>
      </div>

      <section aria-labelledby="achievements-title" className="fade-up stagger-5 space-y-4">
        <div>
          <span className="highlight mb-1.5">
            <Sparkles aria-hidden="true" className="size-3.5" />
            Mukofotlar
          </span>
          <h2 id="achievements-title" className="heading text-xl font-extrabold">
            Yutuqlar
          </h2>
        </div>
        <div className="grid gap-4 sm:grid-cols-3">
          {achievements.map(({ title, description, earned }) => (
            <Card key={title} className="edtech-card-hover flex flex-col justify-between space-y-3" padding="md">
              <div className="flex items-center justify-between">
                <span
                  className={
                    'grid size-11 place-items-center rounded-2xl ' +
                    (earned ? 'bg-amber-50 text-amber-600' : 'bg-slate-100 text-faint')
                  }
                >
                  <Trophy aria-hidden="true" className="size-5" />
                </span>
                <Badge variant={earned ? 'emerald' : 'slate'} size="sm">
                  {earned ? 'Erishildi' : 'Hali ochilmagan'}
                </Badge>
              </div>
              <div>
                <h3 className="heading font-extrabold">{title}</h3>
                <p className="mt-1 text-xs text-slatefine">
                  {description} · {earned ? 'Erishildi' : 'Hali ochilmagan'}
                </p>
              </div>
            </Card>
          ))}
        </div>
      </section>
    </div>
  );
}

function Stat({ icon: Icon, tone, value, label, index }: { icon: LucideIcon; tone: string; value: string; label: string; index: number }) {
  return (
    <Card
      padding="sm"
      style={{ animationDelay: `${index * 70}ms` }}
      className="fade-up edtech-card-hover min-w-0 space-y-3"
    >
      <span className={`grid size-11 place-items-center rounded-2xl ${tone}`}>
        <Icon aria-hidden="true" className="size-5" />
      </span>
      <div>
        <p className="heading text-xl font-extrabold sm:text-2xl">{value}</p>
        <p className="mt-0.5 text-xs font-bold text-slatefine">{label}</p>
      </div>
    </Card>
  );
}
