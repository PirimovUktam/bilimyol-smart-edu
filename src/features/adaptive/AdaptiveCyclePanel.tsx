import { useTranslation } from '@/core/locales/useTranslation';
import type { MessageKey } from '@/core/locales/messages';
import type {
  AdaptiveCycleSnapshot,
  AdaptiveStepKey,
} from '@/domain/personalization/AdaptiveCycleEngine';
import type { DailyMicroTask, ExplainableFactor, ExplainableFactorKey } from '@/domain/entities/Recommendation';
import {
  Activity,
  AlertCircle,
  ArrowRight,
  Brain,
  Check,
  Clock,
  Compass,
  Gauge,
  RefreshCw,
  Sparkles,
  Target,
  TrendingUp,
  Zap,
  type LucideIcon,
} from 'lucide-react';
import { Badge } from '@/presentation/components/Badge';
import { Button } from '@/presentation/components/Button';

const STEP_META: Record<
  AdaptiveStepKey,
  { titleKey: MessageKey; descKey: MessageKey; accent: string; ring: string; badge: string }
> = {
  diagnostic: {
    titleKey: 'adaptive.stepDiagnostic',
    descKey: 'adaptive.stepDiagnosticDesc',
    accent: 'from-cyan-500 to-sky-600 text-white',
    ring: 'border-cyan-500/40 bg-cyan-500/10',
    badge: 'text-path',
  },
  profile: {
    titleKey: 'adaptive.stepProfile',
    descKey: 'adaptive.stepProfileDesc',
    accent: 'from-blue-500 to-indigo-600 text-white',
    ring: 'border-blue-500/40 bg-blue-500/10',
    badge: 'text-brand',
  },
  path: {
    titleKey: 'adaptive.stepPath',
    descKey: 'adaptive.stepPathDesc',
    accent: 'from-violet-500 to-purple-600 text-white',
    ring: 'border-violet-500/40 bg-violet-500/10',
    badge: 'text-brand-dark',
  },
  practice: {
    titleKey: 'adaptive.stepPractice',
    descKey: 'adaptive.stepPracticeDesc',
    accent: 'from-amber-500 to-orange-500 text-white',
    ring: 'border-amber-500/40 bg-amber-500/10',
    badge: 'text-amber-600',
  },
  progress: {
    titleKey: 'adaptive.stepProgress',
    descKey: 'adaptive.stepProgressDesc',
    accent: 'from-emerald-500 to-teal-600 text-white',
    ring: 'border-emerald-500/40 bg-emerald-500/10',
    badge: 'text-mint',
  },
};

const FACTOR_META: Record<ExplainableFactorKey, { icon: LucideIcon; labelKey: MessageKey; tone: string }> = {
  goal: { icon: Target, labelKey: 'adaptive.factorGoal', tone: 'text-brand bg-brand/10 border-brand/20' },
  skill_profile: { icon: Compass, labelKey: 'adaptive.factorSkillProfile', tone: 'text-path bg-path/10 border-path/25' },
  knowledge_level: { icon: Gauge, labelKey: 'adaptive.factorKnowledgeLevel', tone: 'text-mint bg-mint/10 border-mint/25' },
  error_pattern: { icon: AlertCircle, labelKey: 'adaptive.factorErrorPattern', tone: 'text-coral bg-coral/10 border-coral/25' },
  learning_speed: { icon: Zap, labelKey: 'adaptive.factorLearningSpeed', tone: 'text-amber-600 bg-amber-500/10 border-amber-500/25' },
  daily_time: { icon: Clock, labelKey: 'adaptive.factorDailyTime', tone: 'text-brand-dark bg-sand border-hairline' },
};

interface AdaptiveCyclePanelProps {
  cycle: AdaptiveCycleSnapshot;
  factors: ExplainableFactor[];
  dailyTasks: DailyMicroTask[];
  compact?: boolean;
  onStepAction: (stepKey: AdaptiveStepKey) => void;
  onPrimaryAction?: () => void;
  primaryActionLabel?: string;
}

export function AdaptiveCyclePanel({
  cycle,
  factors,
  dailyTasks,
  compact = false,
  onStepAction,
  onPrimaryAction,
  primaryActionLabel,
}: AdaptiveCyclePanelProps) {
  const { t } = useTranslation();

  return (
    <section
      aria-labelledby="adaptive-cycle-heading"
      className="cosmos-card fade-up stagger-1 min-w-0 space-y-5 p-4 sm:p-6"
    >
      {/* Header Row */}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0 flex-1 space-y-1">
          <span className="highlight max-w-full">
            <RefreshCw aria-hidden="true" className="size-3.5 shrink-0 text-path" />
            <span className="truncate">{t('adaptive.cycleEyebrow')}</span>
          </span>
          <h2 id="adaptive-cycle-heading" className="font-display text-lg font-extrabold tracking-tight text-ink sm:text-xl">
            {t('adaptive.cycleTitle')}
          </h2>
          <p className="text-xs font-medium text-slatefine sm:text-sm">
            {t('adaptive.cycleSubtitle')}
          </p>
        </div>

        <Badge variant="teal" size="md" icon={<Activity aria-hidden="true" className="size-3.5" />}>
          0{cycle.activeStep}/05
        </Badge>
      </div>

      {/* 5 Connected Steps */}
      <ol className="grid min-w-0 grid-cols-1 gap-2.5 sm:grid-cols-2 lg:grid-cols-5">
        {cycle.steps.map((step) => {
          const meta = STEP_META[step.key];
          const isCompleted = step.status === 'completed';
          const isActive = step.status === 'active';

          return (
            <li key={step.step} className="min-w-0">
              <button
                type="button"
                onClick={() => onStepAction(step.key)}
                aria-current={isActive ? 'step' : undefined}
                className={
                  'group flex h-full w-full min-w-0 cursor-pointer flex-col justify-between gap-2.5 rounded-2xl border p-3.5 text-left transition-all hover:-translate-y-0.5 ' +
                  (isActive
                    ? `ring-2 ring-brand/35 ${meta.ring}`
                    : isCompleted
                    ? 'border-mint/30 bg-mint/5 hover:border-mint/50'
                    : 'border-hairline bg-canvas/60 hover:border-brand/40')
                }
              >
                <div className="flex items-center justify-between gap-2">
                  <span
                    className={`grid size-8 shrink-0 place-items-center rounded-xl bg-gradient-to-br text-xs font-black shadow-xs ${meta.accent}`}
                  >
                    {isCompleted ? <Check aria-hidden="true" className="size-4" /> : step.code}
                  </span>
                  <span
                    className={
                      'rounded-full px-2 py-0.5 text-[10px] font-extrabold uppercase tracking-wide ' +
                      (isActive
                        ? 'bg-brand/15 text-brand'
                        : isCompleted
                        ? 'bg-mint/15 text-mint'
                        : 'bg-sand text-slatefine')
                    }
                  >
                    {isActive
                      ? t('adaptive.statusActive')
                      : isCompleted
                      ? t('adaptive.statusCompleted')
                      : t('adaptive.statusUpcoming')}
                  </span>
                </div>

                <div className="min-w-0 space-y-0.5">
                  <h3 className="font-display text-sm font-extrabold text-ink group-hover:text-brand">
                    {t(meta.titleKey)}
                  </h3>
                  <p className="text-[11px] font-medium text-slatefine">
                    {t(meta.descKey)}
                  </p>
                </div>

                <p className={`w-full min-w-0 truncate border-t border-hairline/70 pt-2 font-mono text-[11px] font-bold ${meta.badge}`}>
                  {step.metricLabel}
                </p>
              </button>
            </li>
          );
        })}
      </ol>

      {/* Dynamic Loop Feedback Banner */}
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-brand/25 bg-sand/75 px-4 py-3">
        <div className="flex min-w-0 flex-1 items-start gap-2.5">
          <Sparkles aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-brand" />
          <p className="text-xs leading-relaxed font-semibold text-graphite sm:text-sm">
            {cycle.loopUpdateSummary}
          </p>
        </div>
        {onPrimaryAction && primaryActionLabel && (
          <Button
            size="sm"
            variant="outline"
            onClick={onPrimaryAction}
            rightIcon={<ArrowRight aria-hidden="true" className="size-3.5" />}
          >
            {primaryActionLabel}
          </Button>
        )}
      </div>

      {/* Explainable AI (6 Personalization Inputs) & Daily Micro-Tasks */}
      {!compact && (
        <div className="grid min-w-0 gap-4 border-t border-hairline pt-4 lg:grid-cols-12">
          {/* 6 Inputs Matrix */}
          <div className="min-w-0 space-y-3 lg:col-span-8">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="flex min-w-0 items-center gap-2">
                <Brain aria-hidden="true" className="size-4.5 shrink-0 text-brand" />
                <h3 className="font-display text-sm font-extrabold text-ink sm:text-base">
                  {t('adaptive.xaiTitle')}
                </h3>
              </div>
              <Badge variant="indigo" size="sm">
                {t('adaptive.xaiInputsBadge')}
              </Badge>
            </div>

            <div className="grid min-w-0 gap-2.5 sm:grid-cols-2 md:grid-cols-3">
              {factors.map((factor) => {
                const meta = FACTOR_META[factor.key];
                const Icon = meta.icon;
                return (
                  <div
                    key={factor.key}
                    className="flex min-w-0 flex-col justify-between gap-1.5 rounded-2xl border border-hairline bg-canvas/60 p-3"
                  >
                    <div className="flex min-w-0 items-center gap-2">
                      <span className={`grid size-6 shrink-0 place-items-center rounded-lg border ${meta.tone}`}>
                        <Icon aria-hidden="true" className="size-3.5" />
                      </span>
                      <span className="truncate text-[11px] font-extrabold uppercase tracking-wide text-slatefine">
                        {t(meta.labelKey)}
                      </span>
                    </div>
                    <p className="min-w-0 break-words text-xs font-extrabold text-ink">{factor.value}</p>
                    <p className="line-clamp-2 text-[11px] leading-snug text-slatefine">{factor.impact}</p>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Daily Personal Micro-Recommendations */}
          <div className="min-w-0 space-y-3 rounded-2xl border border-hairline bg-canvas/60 p-3.5 lg:col-span-4">
            <div className="flex min-w-0 items-center justify-between gap-2">
              <h3 className="flex min-w-0 items-center gap-1.5 font-display text-sm font-extrabold text-ink">
                <TrendingUp aria-hidden="true" className="size-4 shrink-0 text-mint" />
                {t('adaptive.dailyTasksTitle')}
              </h3>
            </div>
            <ul className="min-w-0 space-y-2">
              {dailyTasks.map((task) => (
                <li
                  key={task.id}
                  className="min-w-0 rounded-xl border border-hairline bg-paper p-2.5 shadow-2xs"
                >
                  <div className="flex min-w-0 items-start justify-between gap-2">
                    <span className="min-w-0 break-words text-xs font-extrabold text-ink">{task.title}</span>
                    <span className="shrink-0 rounded-md bg-sand px-1.5 py-0.5 font-mono text-[10px] font-bold text-brand-dark">
                      {task.minutes} {t('dashboard.min')}
                    </span>
                  </div>
                  <p className="mt-1 line-clamp-2 text-[11px] leading-snug text-slatefine">
                    {task.reason}
                  </p>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}
    </section>
  );
}
