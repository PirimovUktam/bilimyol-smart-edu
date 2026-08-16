import React, { useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  Map,
  CheckCircle2,
  Lock,
  Play,
  RotateCcw,
  Sparkles,
  ArrowRight,
  Clock,
  Zap,
  Award,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Badge } from '@/presentation/components/Badge';

interface RoadmapViewProps {
  onStartLesson: (lessonId: string) => void;
  onOpenKnowledgeMap: () => void;
}

export const RoadmapView: React.FC<RoadmapViewProps> = ({ onStartLesson, onOpenKnowledgeMap }) => {
  const { activeCourse } = useCourseStore();
  const { roadmap, loadRoadmap, selectNode } = useRoadmapStore();

  useEffect(() => {
    if (activeCourse) {
      loadRoadmap(activeCourse.id);
    }
  }, [activeCourse, loadRoadmap]);

  if (!roadmap || !activeCourse) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="w-10 h-10 border-4 border-blue-600 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const isMath = activeCourse.subject === 'mathematics';
  const defaultLessonId = isMath ? 'lesson_math_functions_01' : 'lesson_eng_listening_01';

  return (
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-8">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-200">
        <div>
          <div className="flex items-center gap-2 mb-1.5">
            <Badge variant="blue" size="sm">
              <Map className="w-3.5 h-3.5 mr-1" />
              Moslashuvchan Yo‘l Xaritasi
            </Badge>
            <span className="text-xs font-semibold text-slate-500">
              {activeCourse.title}
            </span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
            Sizning Individual Ta'lim Yo‘lingiz
          </h1>
          <p className="text-sm text-slate-600 mt-1">
            Har bir bosqich Placement Test va o‘zlashtirish darajangizga qarab moslashadi.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="md"
            onClick={onOpenKnowledgeMap}
            leftIcon={<Sparkles className="w-4 h-4 text-blue-600" />}
          >
            Bilim Xaritasi
          </Button>
        </div>
      </div>

      {/* Roadmap Road Track */}
      <div className="relative pl-6 sm:pl-10 space-y-8 before:absolute before:left-[21px] sm:before:left-[37px] before:top-4 before:bottom-4 before:w-1.5 before:bg-gradient-to-b before:from-blue-600 before:via-teal-500 before:to-slate-300 before:rounded-full">
        {roadmap.nodes.map((node, index) => {
          const isCompleted = node.status === 'completed';
          const isReinforcement = node.isReinforcement || node.status === 'reinforcement';
          const isLocked = node.status === 'locked';
          const isAvailable = node.status === 'available' || node.status === 'reinforcement';

          const targetLesson = node.targetLessonId || defaultLessonId;

          return (
            <motion.div
              key={node.id}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.3, delay: index * 0.1 }}
              className="relative"
            >
              {/* Node Icon on Road Track */}
              <div
                className={`absolute -left-[30px] sm:-left-[46px] top-4 w-9 h-9 sm:w-11 sm:h-11 rounded-2xl flex items-center justify-center border-2 transition-transform ${
                  isCompleted
                    ? 'bg-emerald-600 border-emerald-600 text-white shadow-md shadow-emerald-600/20'
                    : isReinforcement
                    ? 'bg-amber-500 border-amber-500 text-white shadow-lg shadow-amber-500/30 animate-bounce'
                    : isAvailable
                    ? 'bg-blue-600 border-blue-600 text-white shadow-md shadow-blue-600/20 ring-4 ring-blue-100'
                    : 'bg-slate-200 border-slate-300 text-slate-400'
                }`}
              >
                {isCompleted ? (
                  <CheckCircle2 className="w-5 h-5 stroke-[2.5]" />
                ) : isReinforcement ? (
                  <RotateCcw className="w-5 h-5 animate-spin-slow" />
                ) : isAvailable ? (
                  <Play className="w-4 h-4 fill-white translate-x-0.5" />
                ) : (
                  <Lock className="w-4 h-4" />
                )}
              </div>

              {/* Node Content Card */}
              <Card
                className={`p-6 border-2 transition-all cursor-pointer ${
                  isReinforcement
                    ? 'border-amber-400 bg-gradient-to-r from-amber-50/60 to-white shadow-md ring-2 ring-amber-400/30'
                    : isCompleted
                    ? 'border-slate-200 bg-white/70'
                    : isAvailable
                    ? 'border-blue-400 bg-white shadow-md ring-2 ring-blue-100'
                    : 'border-slate-200 bg-slate-50/80 opacity-75'
                }`}
                onClick={() => {
                  selectNode(node);
                  if (isAvailable) {
                    onStartLesson(targetLesson);
                  }
                }}
              >
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                  <div className="space-y-1.5 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">
                        Qadam {node.order}
                      </span>

                      {isCompleted && (
                        <span className="px-2 py-0.5 text-[10px] font-extrabold rounded-md bg-emerald-100 text-emerald-800 border border-emerald-200">
                          ✓ O‘zlashtirilgan
                        </span>
                      )}

                      {isReinforcement && (
                        <span className="px-2 py-0.5 text-[10px] font-extrabold rounded-md bg-amber-100 text-amber-900 border border-amber-300 flex items-center gap-1 animate-pulse">
                          <Zap className="w-3 h-3 text-amber-600" />
                          MUSTAHKAMLASH FOKUS (41% → 63%)
                        </span>
                      )}

                      {isLocked && (
                        <span className="px-2 py-0.5 text-[10px] font-semibold rounded-md bg-slate-200 text-slate-600">
                          🔒 Bloklangan (Avvalgi darsni yakunlang)
                        </span>
                      )}
                    </div>

                    <h3 className="text-lg sm:text-xl font-bold text-slate-900">
                      {node.title}
                    </h3>
                    <p className="text-xs sm:text-sm text-slate-600">
                      {node.description || 'Ushbu mavzu bo‘yicha tushunchalar va amaliy mashqlar.'}
                    </p>

                    <div className="flex items-center gap-4 pt-1 text-xs text-slate-500 font-medium">
                      <span className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5" />
                        {node.estimatedMinutes} daqiqa
                      </span>
                      {node.score !== undefined && (
                        <span className="flex items-center gap-1">
                          <Award className="w-3.5 h-3.5" />
                          Daraja: <strong>{node.score}%</strong>
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Action CTA */}
                  <div className="sm:text-right shrink-0">
                    {isCompleted ? (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={(e) => {
                          e.stopPropagation();
                          onStartLesson(targetLesson);
                        }}
                        className="text-slate-600 text-xs"
                      >
                        Qayta takrorlash
                      </Button>
                    ) : isAvailable ? (
                      <Button
                        variant={isReinforcement ? 'primary' : 'primary'}
                        size="md"
                        onClick={(e) => {
                          e.stopPropagation();
                          onStartLesson(targetLesson);
                        }}
                        rightIcon={<ArrowRight className="w-4 h-4" />}
                        className={isReinforcement ? 'bg-amber-600 hover:bg-amber-700 border-amber-600 text-white' : ''}
                      >
                        {isReinforcement ? 'Darsni Boshlash' : 'Boshlash'}
                      </Button>
                    ) : (
                      <div className="text-xs font-semibold text-slate-400 flex items-center gap-1 justify-end">
                        <Lock className="w-3.5 h-3.5" />
                        Ochish uchun oldingi darsni topshiring
                      </div>
                    )}
                  </div>
                </div>
              </Card>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
};
