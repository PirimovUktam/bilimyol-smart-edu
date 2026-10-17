import { create } from 'zustand';
import { LearningPath, LearningPathNode } from '@/domain/entities/LearningPathNode';
import { supabaseLessonRepository } from '@/data/repositories/SupabaseLessonRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { GetRoadmapUseCase } from '@/domain/usecases/GetRoadmapUseCase';
import { SubmitReinforcementUseCase, ReinforcementResult } from '@/domain/usecases/SubmitReinforcementUseCase';
import { Question } from '@/domain/entities/Question';

interface RoadmapState {
  roadmap: LearningPath | null;
  selectedNode: LearningPathNode | null;
  isLoading: boolean;
  isUpdating: boolean;
  error: string | null;

  clearSession: () => void;
  loadRoadmap: (courseId: string) => Promise<void>;
  selectNode: (node: LearningPathNode) => void;
  completeReinforcement: (
    courseId: string,
    skillId: string,
    reinforcementNodeId: string,
    reinforcementQuestion: Question,
    selectedIndex: number
  ) => Promise<ReinforcementResult>;
}

const reinforcementCancelled = (): Error => {
  const error = new Error('Mustahkamlash amali bekor qilindi. Joriy ta’lim yo‘lida qayta urinib ko‘ring.');
  error.name = 'AbortError';
  return error;
};

export const useRoadmapStore = create<RoadmapState>((set) => {
  // Loads and reinforcement results replace the same roadmap: latest action wins.
  let currentOperation: object | null = null;
  let pendingReinforcement: { courseId: string; operation: object } | null = null;

  return {
    roadmap: null,
    selectedNode: null,
    isLoading: false,
    isUpdating: false,
    error: null,

    clearSession: () => {
      currentOperation = null;
      pendingReinforcement = null;
      set({ roadmap: null, selectedNode: null, isLoading: false, isUpdating: false, error: null });
    },

    loadRoadmap: async (courseId: string) => {
      const operation = {};
      currentOperation = operation;
      set({ isLoading: true, isUpdating: false, error: null });
      if (currentOperation !== operation) return;
      try {
        const useCase = new GetRoadmapUseCase(supabaseLessonRepository, supabaseLearnerRepository);
        const roadmap = await useCase.execute(courseId);
        if (currentOperation !== operation) return;
        const activeNode =
          roadmap.nodes.find((n) => n.status === 'reinforcement' || n.status === 'available') ||
          roadmap.nodes[0] ||
          null;

        set({
          roadmap,
          selectedNode: activeNode,
          isLoading: false,
          error: null,
        });
      } catch (err) {
        if (currentOperation !== operation) return;
        set({
          roadmap: null,
          selectedNode: null,
          isLoading: false,
          error: err instanceof Error ? err.message : 'Ta’lim yo‘li yuklanmadi.',
        });
      }
    },

    selectNode: (node) => {
      set({ selectedNode: node });
    },

    completeReinforcement: async (courseId, skillId, reinforcementNodeId, reinforcementQuestion, selectedIndex) => {
      // A refresh may invalidate the result, but must not enable duplicate writes.
      if (pendingReinforcement?.courseId === courseId) {
        throw reinforcementCancelled();
      }
      const operation = {};
      currentOperation = operation;
      pendingReinforcement = { courseId, operation };
      set({ isUpdating: true, isLoading: false, error: null });
      try {
        if (currentOperation !== operation) throw reinforcementCancelled();
        const useCase = new SubmitReinforcementUseCase(supabaseLearnerRepository, supabaseLessonRepository);
        const result = await useCase.execute(
          courseId,
          skillId,
          reinforcementNodeId,
          reinforcementQuestion,
          selectedIndex
        );
        if (currentOperation !== operation) throw reinforcementCancelled();

        if (result.isCorrect) {
          set({
            roadmap: result.updatedRoadmap,
            selectedNode: result.updatedRoadmap.nodes.find((n) => n.id === reinforcementNodeId) || null,
            isUpdating: false,
            error: null,
          });
        } else {
          set({ isUpdating: false, error: null });
        }

        if (currentOperation !== operation) throw reinforcementCancelled();
        return result;
      } catch (err) {
        if (currentOperation !== operation) throw reinforcementCancelled();
        set({
          isUpdating: false,
          error: err instanceof Error ? err.message : 'Mustahkamlash javobi serverda saqlanmadi.',
        });
        throw err;
      } finally {
        if (pendingReinforcement?.operation === operation) pendingReinforcement = null;
      }
    },
  };
});
