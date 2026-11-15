import { useTranslation } from '@/core/locales/useTranslation';
import type { ReactNode } from 'react';
import { BookOpenCheck, Compass, Sparkles } from 'lucide-react';
import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

const features = [
  { icon: Compass, title: 'auth.levelPath' as const },
  { icon: BookOpenCheck, title: 'auth.exercises' as const },
  { icon: Sparkles, title: 'auth.explanations' as const },
];

export function AuthLayout({ title, subtitle, children }: { title: string; subtitle?: string; children: ReactNode }) {
  const { t } = useTranslation();
  return (
    <div className="mx-auto grid min-h-[calc(100dvh-62px)] max-w-360 items-stretch gap-4 p-3 lg:grid-cols-[minmax(0,1fr)_minmax(26rem,0.88fr)] lg:p-6">
      <aside className="auth-showcase hidden min-h-150 flex-col justify-between gap-8 overflow-hidden rounded-3xl p-10 lg:flex xl:p-14" aria-label={t('auth.about')}>
        <BilimYolLogo variant="dark" size="lg" showSubtitle={false} />
        <div className="max-w-xl">
          <p className="mb-4 inline-flex items-center gap-2 rounded-full bg-white/15 px-3.5 py-1.5 text-xs font-bold text-indigo-100">
            <Sparkles aria-hidden="true" className="size-4 text-sky-300" /> {t('auth.aiEducation')}
          </p>
          <p className="font-display text-5xl font-extrabold leading-[1.06] tracking-tight xl:text-6xl">
            {t('auth.sloganStart')}<br /><span className="text-sky-300">{t('auth.sloganEnd')}</span>
          </p>
          <p className="mt-4 max-w-sm text-sm leading-relaxed text-indigo-100">
            {t('auth.introduction')}
          </p>
        </div>
        <div className="flex items-center justify-between gap-4">
          <ul className="space-y-3">
            {features.map(({ icon: Icon, title: text }) => (
              <li key={t(text)} className="flex items-center gap-2.5 text-sm font-semibold text-indigo-100">
                <span className="grid size-8 place-items-center rounded-xl bg-white/12 text-sky-300">
                  <Icon aria-hidden="true" className="size-4 shrink-0" />
                </span>
                {t(text)}
              </li>
            ))}
          </ul>
          <div aria-hidden="true" className="tutor-orbit min-w-30 flex-1 xl:max-w-44">
            <YolchiAIMascot size="lg" mood="happy" />
          </div>
        </div>
      </aside>
      <div className="fade-up flex items-center justify-center px-2 py-6 sm:px-8 sm:py-10">
        <div className="edtech-card w-full max-w-112 p-6 sm:p-9">
          <div className="mb-6 lg:hidden"><BilimYolLogo variant="auto" showSubtitle={false} /></div>
          <header className="mb-6">
            <span className="highlight mb-2.5">
              <Sparkles aria-hidden="true" className="size-3.5" />
              BilimYo‘l Smart Edu
            </span>
            <h1 className="heading text-3xl font-extrabold tracking-tight text-ink">{title}</h1>
            {subtitle && <p className="mt-2 text-sm leading-relaxed text-slatefine">{subtitle}</p>}
          </header>
          {children}
        </div>
      </div>
    </div>
  );
}
