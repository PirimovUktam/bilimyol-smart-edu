import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Compass, AlertTriangle, CheckCircle2, ArrowRight, Sparkles } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { GetKnowledgeMapUseCase, KnowledgeMapData } from '@/domain/usecases/GetKnowledgeMapUseCase';
import { inMemoryCourseRepository } from '@/data/repositories/InMemoryCourseRepository';
import { inMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Badge } from '@/presentation/components/Badge';

interface KnowledgeMapViewProps {
  onProceedToRoadmap: () => void;
}

export const KnowledgeMapView: React.FC<KnowledgeMapViewProps> = ({ onProceedToRoadmap }) => {
  const { activeCourse, activeCourseSkills } = useCourseStore();
  const { profile } = useLearnerStore();
  const [mapData, setMapData] = useState<KnowledgeMapData | null>(null);

  useEffect(() => {
    if (activeCourse) {
      const useCase = new GetKnowledgeMapUseCase(inMemoryCourseRepository, inMemoryLearnerRepository);
      useCase.execute(activeCourse.id).then(setMapData);
    }
  }, [activeCourse, profile]);

  if (!mapData || !activeCourse) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="w-10 h-10 border-4 border-blue-600 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const weakest = mapData.weakestSkill;
  const weakestSkillName = weakest
    ? activeCourseSkills.find((s) => s.id === weakest.skillId)?.name || 'Ko‘nikma'
    : 'Ko‘nikma';
  const overallScore = mapData.overallScore;

  return (
    <div className="max-w-5xl mx-auto px-4 py-8 space-y-8">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-200">
        <div>
          <div className="flex items-center gap-2 mb-1.5">
            <Badge variant="blue" size="sm">
              <Compass className="w-3.5 h-3.5 mr-1" />
              Bilim Xaritasi
            </Badge>
            <span className="text-xs font-semibold text-slate-500">
              {activeCourse.title} • Umumiy natija: {overallScore}%
            </span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
            Ko‘nikmalar Tahlili va Diagnostika Natijasi
          </h1>
          <p className="text-sm text-slate-600 mt-1">
            Haqiqiy javoblaringiz asosida hisoblangan har bir ko‘nikma darajasi
          </p>
        </div>

        <Button
          variant="primary"
          size="lg"
          onClick={onProceedToRoadmap}
          rightIcon={<ArrowRight className="w-5 h-5" />}
        >
          Shaxsiy Yo‘l Xaritasi
        </Button>
      </div>

      {/* Weakest Skill Alert Banner */}
      {weakest && weakest.score < 50 && (
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.3 }}
          className="p-6 bg-gradient-to-r from-amber-500/10 via-rose-500/10 to-amber-500/10 border-2 border-amber-400/80 rounded-3xl shadow-sm flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
        >
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 rounded-2xl bg-amber-500 text-white flex items-center justify-center shrink-0 shadow-md shadow-amber-500/20">
              <AlertTriangle className="w-6 h-6 animate-pulse" />
            </div>
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-extrabold tracking-wider uppercase px-2 py-0.5 rounded bg-amber-200/80 text-amber-900">
                  DIQQAT: Zaif Bo‘g‘in Aniqlandi
                </span>
                <span className="text-sm font-extrabold text-amber-950">
                  {weakestSkillName} — {weakest.score}%
                </span>
              </div>
              <p className="text-xs sm:text-sm text-amber-900/90 font-medium">
                {weakestSkillName} bo‘yicha tushunchalarda bo‘shliq aniqlandi ({weakest.score}%). Shaxsiy yo‘l xaritangizga ushbu ko‘nikmani mustahkamlash qadami qo‘shildi.
              </p>
            </div>
          </div>

          <Button
            variant="outline"
            size="sm"
            onClick={onProceedToRoadmap}
            className="border-amber-400 text-amber-950 bg-white hover:bg-amber-50 font-bold shrink-0 text-xs"
          >
            Yo‘lga O‘tish
          </Button>
        </motion.div>
      )}

      {/* Skills Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        {activeCourseSkills.map((skill, idx) => {
          const scoreObj = mapData.scores[skill.id];
          const score = scoreObj ? scoreObj.score : 0;
          const isWeak = score < 50;
          const levelLabel = SkillScoringEngine.getMasteryLabelUz(score);

          return (
            <motion.div
              key={skill.id}
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3, delay: idx * 0.08 }}
            >
              <Card
                className={`p-6 border-2 transition-all ${
                  isWeak
                    ? 'border-amber-400/90 bg-amber-50/30 shadow-md ring-2 ring-amber-400/20'
                    : 'border-slate-200/90 hover:border-slate-300 shadow-xs'
                }`}
              >
                <div className="flex items-start justify-between gap-3 mb-4">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                        {skill.code}
                      </span>
                      {isWeak ? (
                        <span className="px-2 py-0.5 text-[10px] font-bold rounded-md bg-rose-100 text-rose-700 border border-rose-200 flex items-center gap-1">
                          <AlertTriangle className="w-3 h-3" /> {levelLabel}
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 text-[10px] font-bold rounded-md bg-emerald-100 text-emerald-700 border border-emerald-200 flex items-center gap-1">
                          <CheckCircle2 className="w-3 h-3" /> {levelLabel}
                        </span>
                      )}
                    </div>
                    <h3 className="text-lg font-bold text-slate-900">{skill.name}</h3>
                    <p className="text-xs text-slate-500 line-clamp-2">{skill.description}</p>
                  </div>

                  <div className="text-right">
                    <div
                      className={`text-2xl sm:text-3xl font-black ${
                        isWeak ? 'text-rose-600' : 'text-slate-900'
                      }`}
                    >
                      {score}%
                    </div>
                    <span className="text-[10px] font-semibold text-slate-400">Haqiqiy Ko‘rsatkich</span>
                  </div>
                </div>

                {/* Progress bar */}
                <div className="space-y-1.5">
                  <div className="h-3 w-full bg-slate-100 rounded-full overflow-hidden p-0.5 border border-slate-200/60">
                    <motion.div
                      className={`h-full rounded-full ${
                        isWeak
                          ? 'bg-gradient-to-r from-rose-500 to-amber-500'
                          : 'bg-gradient-to-r from-blue-600 to-teal-500'
                      }`}
                      initial={{ width: 0 }}
                      animate={{ width: `${score}%` }}
                      transition={{ duration: 0.6, delay: 0.2 + idx * 0.1 }}
                    />
                  </div>
                  <div className="flex justify-between text-[11px] text-slate-500 font-medium">
                    <span>0%</span>
                    <span>50% (Mustahkamlash chegarasi)</span>
                    <span>100%</span>
                  </div>
                </div>
              </Card>
            </motion.div>
          );
        })}
      </div>

      {/* Footer Insight Box */}
      <Card className="p-6 bg-slate-900 text-slate-200 border-0 shadow-xl flex flex-col sm:flex-row items-center justify-between gap-6">
        <div className="space-y-1 text-center sm:text-left">
          <div className="flex items-center justify-center sm:justify-start gap-2 text-blue-400 font-bold text-xs uppercase tracking-wider">
            <Sparkles className="w-4 h-4" />
            <span>Yo‘lchi AI Tavsiyasi</span>
          </div>
          <h4 className="text-lg font-bold text-white">
            {weakest
              ? `${weakestSkillName} bo‘yicha interaktiv dars va mustahkamlash rejalashtirildi`
              : 'Darslar rejalashtirildi'}
          </h4>
          <p className="text-xs text-slate-400">
            Darsdagi har bir javobingiz tahlil qilinib, bilim darajangiz real vaqtda qayta hisoblanadi.
          </p>
        </div>

        <Button
          variant="primary"
          size="lg"
          onClick={onProceedToRoadmap}
          rightIcon={<ArrowRight className="w-5 h-5" />}
          className="shrink-0 w-full sm:w-auto"
        >
          Yo‘l Xaritasiga o‘tish
        </Button>
      </Card>
    </div>
  );
};
