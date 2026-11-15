import { useTranslation } from '@/core/locales/useTranslation';
import { ArrowRight, BookOpen, Check, Compass, Sparkles, Zap } from 'lucide-react';
import { useAuth } from '@/core/context/AuthContext';
import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';
import { Button } from '@/presentation/components/Button';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

export function WelcomeView({ onRegister, onLogin }: { onRegister: () => void; onLogin: () => void }) {
  const { t } = useTranslation();
  const { setDemoUser } = useAuth();
  return (
    <div className="welcome-page mx-auto grid min-h-[88dvh] w-full max-w-304 content-center gap-8 px-5 py-8 sm:px-9 lg:grid-cols-2 lg:items-center lg:gap-14">
      <section className="fade-up min-w-0 space-y-6" aria-labelledby="welcome-title">
        <BilimYolLogo variant="auto" />
        <div>
          <p className="highlight mb-3.5">
            <Compass aria-hidden="true" className="size-4 text-cyan-300" />
            {t('auth.welcomePath')}
          </p>
          <h1 id="welcome-title" className="heading max-w-xl text-[clamp(2.4rem,5.6vw,4.4rem)] leading-[1.06] font-extrabold tracking-tight">
            {t('auth.welcomeStart')} <span className="heading-accent">{t('auth.welcomeEnd')}</span>
          </h1>
          <p className="mt-4 max-w-md text-base leading-relaxed text-slatefine sm:text-lg">
            {t('auth.welcomeDescription')}
          </p>
        </div>

        {/* Highlight Stats Row */}
        <div className="flex flex-wrap items-center gap-3 pt-1">
          <span className="inline-flex items-center gap-1.5 rounded-full border border-purple-400/30 bg-[#171C4B]/90 px-3.5 py-1.5 text-xs font-bold text-white shadow-2xs">
            <Sparkles aria-hidden="true" className="size-3.5 text-cyan-300" />
            {t('auth.diagnostics')}
          </span>
          <span className="inline-flex items-center gap-1.5 rounded-full border border-purple-400/30 bg-[#171C4B]/90 px-3.5 py-1.5 text-xs font-bold text-white shadow-2xs">
            <Zap aria-hidden="true" className="size-3.5 text-emerald-400" />
            {t('auth.alwaysTutor')}
          </span>
        </div>

        <div className="flex flex-wrap items-center gap-3 pt-1">
          <Button size="lg" onClick={onRegister} rightIcon={<ArrowRight aria-hidden="true" className="size-5" />}>
            {t('auth.register')}
          </Button>
          <Button size="lg" variant="outline" onClick={onLogin}>
            {t('auth.login')}
          </Button>
        </div>
        <button
          type="button"
          className="min-h-11 cursor-pointer text-sm font-bold text-cyan-300 underline-offset-4 hover:text-cyan-200 hover:underline"
          onClick={setDemoUser}
        >
          {t('auth.demo')}
        </button>
      </section>

      <section aria-label={t('auth.learningOrder')} className="welcome-path fade-up stagger-2 rounded-3xl p-6 text-white sm:p-8">
        <div className="mb-6 flex items-center justify-between gap-3">
          <div>
            <span className="inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 text-xs font-bold tracking-wide text-indigo-100">
              <Sparkles aria-hidden="true" className="size-3.5 text-sky-300" />
              {t('auth.withTutor')}
            </span>
            <h2 className="mt-2 font-display text-2xl font-extrabold">{t('auth.threeSteps')}</h2>
          </div>
          <div aria-hidden="true" className="hidden sm:block">
            <YolchiAIMascot size="md" mood="explaining" />
          </div>
        </div>
        <ol className="space-y-3.5">
          {[
            { icon: Compass, title: t('auth.chooseSubject'), description: t('auth.chooseSubjectDescription') },
            { icon: BookOpen, title: t('auth.readLesson'), description: t('auth.readLessonDescription') },
            { icon: Sparkles, title: t('auth.findNext'), description: t('auth.findNextDescription') },
          ].map(({ icon: Icon, title, description }, index) => (
            <li
              key={title}
              className="flex items-center gap-3.5 rounded-2xl border border-white/15 bg-white/10 p-4 backdrop-blur-xs transition-transform hover:-translate-y-0.5"
            >
              <span className="grid size-11 shrink-0 place-items-center rounded-2xl bg-indigo-400/25 text-white shadow-xs">
                <Icon aria-hidden="true" className="size-5" />
              </span>
              <div className="min-w-0 flex-1">
                <h3 className="font-display font-bold">{title}</h3>
                <p className="mt-0.5 text-sm text-indigo-100">{description}</p>
              </div>
              <span aria-hidden="true" className="font-mono text-sm font-bold text-sky-300">
                0{index + 1}
              </span>
            </li>
          ))}
        </ol>
        <p className="mt-6 flex items-center gap-2 text-sm font-medium text-emerald-200">
          <Check aria-hidden="true" className="size-4 text-emerald-300" />
          {t('auth.separateProgress')}
        </p>
      </section>
    </div>
  );
}
