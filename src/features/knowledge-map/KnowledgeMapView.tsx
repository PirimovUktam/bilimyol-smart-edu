import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Compass, AlertTriangle, ArrowRight, Map, ShieldCheck } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { GetKnowledgeMapUseCase, KnowledgeMapData } from '@/domain/usecases/GetKnowledgeMapUseCase';
import { supabaseCourseRepository } from '@/data/repositories/SupabaseCourseRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Progress } from '@/presentation/components/Progress';

interface KnowledgeMapViewProps {
  onProceedToRoadmap: () => void;
}

export const KnowledgeMapView: React.FC<KnowledgeMapViewProps> = ({ onProceedToRoadmap }) => {
  const { activeCourse, activeCourseSkills } = useCourseStore();
  const { profile } = useLearnerStore();
  const [mapData, setMapData] = useState<KnowledgeMapData | null>(null);
  const [mapError, setMapError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    const courseId = activeCourse?.id;
    if (!courseId) {
      setMapData(null);
      setMapError(null);
      return;
    }

    let cancelled = false;
    setMapData(null);
    setMapError(null);
    const useCase = new GetKnowledgeMapUseCase(supabaseCourseRepository, supabaseLearnerRepository);
    void useCase.execute(courseId).then((nextMap) => {
      if (!cancelled) setMapData(nextMap);
    }).catch((err) => {
      if (!cancelled) {
        setMapData(null);
        setMapError(err instanceof Error ? err.message : 'Bilim xaritasi yuklanmadi.');
      }
    });

    return () => {
      cancelled = true;
    };
  }, [activeCourse?.id, profile, reloadKey]);

  if (mapError && activeCourse) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center px-4">
        <Card className="max-w-md w-full p-7 text-center border-coral/25 bg-rose-50/50 space-y-4">
          <AlertTriangle className="w-10 h-10 text-coral mx-auto" />
          <div>
            <h2 className="text-lg font-black text-slate-900">Bilim xaritasi yuklanmadi</h2>
            <p role="alert" className="text-sm text-slate-600 mt-1">{mapError}</p>
          </div>
          <Button variant="primary" onClick={() => setReloadKey((key) => key + 1)}>
            Qayta urinish
          </Button>
        </Card>
      </div>
    );
  }

  if (!mapData || !activeCourse || mapData.courseId !== activeCourse.id) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="w-10 h-10 border-4 border-brand border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const weakest = mapData.weakestSkill;
  const weakestSkillName = weakest
    ? activeCourseSkills.find((s) => s.id === weakest.skillId)?.name || 'Ko‘nikma'
    : 'Ko‘nikma';
  const overallScore = mapData.overallScore;
  const skillBandCounts = mapData.skills.reduce(
    (counts, skill) => {
      const score = mapData.scores[skill.id]?.score ?? 0;
      if (score >= 80) counts.strong += 1;
      else if (score >= 50) counts.medium += 1;
      else counts.weak += 1;
      return counts;
    },
    { strong: 0, medium: 0, weak: 0 }
  );

  return (
    <div className="max-w-5xl mx-auto px-4 py-8 space-y-7">
      {/* Header bar with View Switcher */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-[#e4ddce]">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="editorial-kicker">
              Bilim Xaritasi // Diagnostika tahlili
            </span>
            <span className="font-mono text-xs font-bold text-slate-700 bg-white border border-[#e4ddce] px-2.5 py-0.5 rounded">
              {activeCourse.title} • {overallScore}%
            </span>
          </div>
          <h1 className="font-display text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight">
            Bilim Holati va Ko‘nikmalar Xaritasi
          </h1>
          <p className="text-xs sm:text-sm text-slate-600 mt-1 font-medium">
            Diagnostika va darslar asosida aniqlangan bilim xaritangiz
          </p>
        </div>

        {/* View Switcher Toggle Pill */}
        <div className="flex items-center bg-white p-1 rounded-xl border border-[#e4ddce] self-start sm:self-auto shadow-2xs">
          <button
            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-bold bg-[#10151f] text-white shadow-2xs transition-all cursor-default"
          >
            <Compass className="w-3.5 h-3.5 text-path" />
            <span>Bilim xaritasi</span>
          </button>
          <button
            onClick={onProceedToRoadmap}
            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-bold text-slate-600 hover:text-slate-900 hover:bg-[#f5efe4] transition-all cursor-pointer"
          >
            <Map className="w-3.5 h-3.5" />
            <span>Roadmap</span>
          </button>
        </div>
      </div>

      {/* Radial Gauge Summary Card */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {/* Gauge card */}
        <div className="p-6 bg-white border border-[#e4ddce] rounded-2xl shadow-sm flex flex-col items-center justify-center text-center space-y-3">
          <span className="font-mono text-[10px] font-bold text-slate-500 uppercase tracking-widest">
            Sizning Bilim Holatingiz
          </span>

          <div className="relative w-36 h-36 flex items-center justify-center">
            <svg className="w-full h-full -rotate-90" viewBox="0 0 120 120">
              <circle
                cx="60"
                cy="60"
                r="46"
                fill="none"
                stroke="#F0ECE3"
                strokeWidth="10"
              />
              <circle
                cx="60"
                cy="60"
                r="46"
                fill="none"
                stroke="url(#mapRingGrad)"
                strokeWidth="10"
                strokeDasharray="289"
                strokeDashoffset={289 * (1 - overallScore / 100)}
                strokeLinecap="round"
                className="transition-all duration-1000 ease-out"
              />
              <defs>
                <linearGradient id="mapRingGrad" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0%" stopColor="#38BDF8" />
                  <stop offset="50%" stopColor="#3B5BDB" />
                  <stop offset="100%" stopColor="#0E131F" />
                </linearGradient>
              </defs>
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <span className="font-display text-3xl font-bold text-slate-900">{overallScore}%</span>
              <span className="font-mono text-[10px] font-bold text-mint uppercase">
                {SkillScoringEngine.getMasteryLabelUz(overallScore)}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2 text-xs font-medium text-slate-600 pt-1">
            <span className="w-2 h-2 rounded-full bg-mint inline-block" />
            <span>Faol tahlil natijasi</span>
          </div>
        </div>

        {/* Detailed Breakdown Card */}
        <div className="p-6 bg-white border border-[#e4ddce] rounded-2xl shadow-sm md:col-span-2 space-y-4 flex flex-col justify-between">
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-brand" />
              <h3 className="font-display text-base font-bold text-slate-900">
                Diagnostika xulosasi
              </h3>
            </div>
            <p className="text-xs sm:text-sm text-slate-600 leading-relaxed font-medium">
              Siz tanlagan <strong>{activeCourse.title}</strong> fani bo‘yicha ko‘nikmalaringiz tahlil qilindi.
              Har bir mavzu uchun bilim darajasi va qaysi mavzularda bo‘shliq borligi aniqlandi.
            </p>
          </div>

          <div className="grid grid-cols-3 gap-3 pt-2 border-t border-[#f0ece3] text-center">
            <div className="p-3 rounded-xl bg-mint/10 border border-mint/25">
              <div className="font-mono text-[10px] font-bold text-mint uppercase tracking-wider">Yaxshi</div>
              <div className="font-mono text-base sm:text-lg font-bold text-mint mt-0.5">{skillBandCounts.strong} ta mavzu</div>
            </div>
            <div className="p-3 rounded-xl bg-amber-50 border border-amber-200">
              <div className="font-mono text-[10px] font-bold text-amber-800 uppercase tracking-wider">O‘rta</div>
              <div className="font-mono text-base sm:text-lg font-bold text-amber-950 mt-0.5">{skillBandCounts.medium} ta mavzu</div>
            </div>
            <div className="p-3 rounded-xl bg-coral/5 border border-coral/25">
              <div className="font-mono text-[10px] font-bold text-coral uppercase tracking-wider">Bo‘shliq</div>
              <div className="font-mono text-base sm:text-lg font-bold text-coral mt-0.5">{skillBandCounts.weak} ta mavzu</div>
            </div>
          </div>
        </div>
      </div>

      {/* Weakest Skill Alert Banner */}
      {weakest && weakest.score < 50 && (
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          className="p-5 sm:p-6 bg-[#fff5f5] border border-coral/25 rounded-2xl shadow-xs flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
        >
          <div className="flex items-start gap-4">
            <div className="w-10 h-10 rounded-xl bg-coral text-white flex items-center justify-center shrink-0 shadow-sm shadow-rose-600/20">
              <AlertTriangle className="w-5 h-5 lab-pulse" />
            </div>
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <span className="font-mono text-[9px] font-bold tracking-wider uppercase px-2 py-0.5 rounded bg-coral/10 text-coral border border-coral/25">
                  Mustahkamlash talab etiladi
                </span>
                <span className="font-display text-sm font-bold text-coral">
                  {weakestSkillName} ({weakest.score}%)
                </span>
              </div>
              <p className="text-xs sm:text-sm text-coral font-medium">
                Ushbu mavzu bo‘yicha tushunchalar mustahkamlangandan so‘ng keyingi qiyinroq bosqichlar ochiladi.
              </p>
            </div>
          </div>

          <Button
            variant="danger"
            size="md"
            onClick={onProceedToRoadmap}
            rightIcon={<ArrowRight className="w-4 h-4" />}
            className="shrink-0 font-bold"
          >
            Yo‘l xaritasiga o‘tish
          </Button>
        </motion.div>
      )}

      {/* Skills Grid */}
      <div className="space-y-3">
        <h3 className="font-display text-base font-bold text-slate-900 tracking-tight">
          Fan ko‘nikmalari reytingi
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {mapData.skills.map((skill) => {
            const skillScore = mapData.scores[skill.id]?.score ?? 0;
            const isWeak = skillScore < 50;
            const isStrong = skillScore >= 80;

            return (
              <div
                key={skill.id}
                className={`p-5 rounded-2xl border transition-all ${
                  isWeak
                    ? 'border-coral/25 bg-[#fffbfb]'
                    : isStrong
                    ? 'border-mint/25 bg-[#fbfdfb]'
                    : 'border-[#e4ddce] bg-white'
                }`}
              >
                <div className="flex items-start justify-between gap-3 mb-2">
                  <div>
                    <h4 className="font-display text-sm font-bold text-slate-900">
                      {skill.name}
                    </h4>
                    <p className="text-xs text-slate-500 font-medium mt-0.5">
                      {skill.description || 'Asosiy tushunchalar'}
                    </p>
                  </div>
                  <span
                    className={`font-mono text-xs font-bold px-2 py-0.5 rounded-lg border ${
                      isWeak
                        ? 'bg-coral/10 text-coral border-coral/25'
                        : isStrong
                        ? 'bg-mint/10 text-mint border-mint/25'
                        : 'bg-[#f5efe4] text-slate-800 border-[#e4ddce]'
                    }`}
                  >
                    {skillScore}%
                  </span>
                </div>

                <div className="mt-3">
                  <Progress
                    value={skillScore}
                    tone={isWeak ? 'rose' : isStrong ? 'emerald' : 'indigo'}
                    size="md"
                    ariaLabel={`${skill.name} o‘zlashtirish`}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Bottom CTA */}
      <div className="pt-2 flex justify-end">
        <Button
          variant="secondary"
          size="lg"
          onClick={onProceedToRoadmap}
          rightIcon={<ArrowRight className="w-4 h-4 text-path" />}
          className="shadow-md"
        >
          Shaxsiy Yo‘l Xaritasiga O‘tish
        </Button>
      </div>
    </div>
  );
};
