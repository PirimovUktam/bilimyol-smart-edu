import type { DifficultyLevel } from '@/core/types/common';
import type { CefrLevelId } from '@/domain/entities/Question';

export interface PlacementQuestionMetadata {
  id: string;
  courseId: string;
  skillId: string;
  difficulty: DifficultyLevel;
  cefrLevel?: CefrLevelId;
}

/**
 * Answer-free placement question index for adaptive scoring and CEFR tier
 * calculation when `PLACEMENT_QUESTIONS` (and its answer keys) must stay out
 * of the live production JS bundle. Transitional until `W1-B3` server-persists
 * placement CEFR state.
 */
export const PLACEMENT_QUESTION_METADATA: Record<string, PlacementQuestionMetadata[]> = {
  course_math_01: [
    { id: 'q_math_alg_01', courseId: 'course_math_01', skillId: 'skill_math_algebra', difficulty: 'easy' },
    { id: 'q_math_alg_02', courseId: 'course_math_01', skillId: 'skill_math_algebra', difficulty: 'easy' },
    { id: 'q_math_alg_03', courseId: 'course_math_01', skillId: 'skill_math_algebra', difficulty: 'medium' },
    { id: 'q_math_alg_04', courseId: 'course_math_01', skillId: 'skill_math_algebra', difficulty: 'medium' },
    { id: 'q_math_alg_05', courseId: 'course_math_01', skillId: 'skill_math_algebra', difficulty: 'hard' },
    { id: 'q_math_eq_01', courseId: 'course_math_01', skillId: 'skill_math_equations', difficulty: 'easy' },
    { id: 'q_math_eq_02', courseId: 'course_math_01', skillId: 'skill_math_equations', difficulty: 'medium' },
    { id: 'q_math_eq_03', courseId: 'course_math_01', skillId: 'skill_math_equations', difficulty: 'medium' },
    { id: 'q_math_eq_04', courseId: 'course_math_01', skillId: 'skill_math_equations', difficulty: 'easy' },
    { id: 'q_math_eq_05', courseId: 'course_math_01', skillId: 'skill_math_equations', difficulty: 'hard' },
    { id: 'q_math_func_01', courseId: 'course_math_01', skillId: 'skill_math_functions', difficulty: 'easy' },
    { id: 'q_math_func_02', courseId: 'course_math_01', skillId: 'skill_math_functions', difficulty: 'medium' },
    { id: 'q_math_func_03', courseId: 'course_math_01', skillId: 'skill_math_functions', difficulty: 'medium' },
    { id: 'q_math_func_04', courseId: 'course_math_01', skillId: 'skill_math_functions', difficulty: 'easy' },
    { id: 'q_math_func_05', courseId: 'course_math_01', skillId: 'skill_math_functions', difficulty: 'hard' },
    { id: 'q_math_func_06', courseId: 'course_math_01', skillId: 'skill_math_functions', difficulty: 'hard' },
    { id: 'q_math_graph_01', courseId: 'course_math_01', skillId: 'skill_math_graphs', difficulty: 'easy' },
    { id: 'q_math_graph_02', courseId: 'course_math_01', skillId: 'skill_math_graphs', difficulty: 'medium' },
    { id: 'q_math_graph_03', courseId: 'course_math_01', skillId: 'skill_math_graphs', difficulty: 'easy' },
    { id: 'q_math_graph_04', courseId: 'course_math_01', skillId: 'skill_math_graphs', difficulty: 'medium' },
    { id: 'q_math_graph_05', courseId: 'course_math_01', skillId: 'skill_math_graphs', difficulty: 'hard' },
  ],
  course_eng_01: [
    { id: 'q_eng_place_vocab_a1', courseId: 'course_eng_01', skillId: 'skill_eng_vocab', difficulty: 'easy', cefrLevel: 'A1' },
    { id: 'q_eng_place_vocab_a2', courseId: 'course_eng_01', skillId: 'skill_eng_vocab', difficulty: 'medium', cefrLevel: 'A2' },
    { id: 'q_eng_place_vocab_b1', courseId: 'course_eng_01', skillId: 'skill_eng_vocab', difficulty: 'hard', cefrLevel: 'B1' },
    { id: 'q_eng_place_grammar_a1', courseId: 'course_eng_01', skillId: 'skill_eng_grammar', difficulty: 'easy', cefrLevel: 'A1' },
    { id: 'q_eng_place_grammar_a2', courseId: 'course_eng_01', skillId: 'skill_eng_grammar', difficulty: 'medium', cefrLevel: 'A2' },
    { id: 'q_eng_place_grammar_b1', courseId: 'course_eng_01', skillId: 'skill_eng_grammar', difficulty: 'hard', cefrLevel: 'B1' },
    { id: 'q_eng_place_listening_a1', courseId: 'course_eng_01', skillId: 'skill_eng_listening', difficulty: 'easy', cefrLevel: 'A1' },
    { id: 'q_eng_place_listening_a2', courseId: 'course_eng_01', skillId: 'skill_eng_listening', difficulty: 'medium', cefrLevel: 'A2' },
    { id: 'q_eng_place_listening_b1', courseId: 'course_eng_01', skillId: 'skill_eng_listening', difficulty: 'hard', cefrLevel: 'B1' },
    { id: 'q_eng_place_reading_a1', courseId: 'course_eng_01', skillId: 'skill_eng_reading', difficulty: 'easy', cefrLevel: 'A1' },
    { id: 'q_eng_place_reading_a2', courseId: 'course_eng_01', skillId: 'skill_eng_reading', difficulty: 'medium', cefrLevel: 'A2' },
    { id: 'q_eng_place_reading_b1', courseId: 'course_eng_01', skillId: 'skill_eng_reading', difficulty: 'hard', cefrLevel: 'B1' },
  ],
  course_it: [
    { id: 'q_it_py_01', courseId: 'course_it', skillId: 'skill_it_python', difficulty: 'easy' },
    { id: 'q_it_py_02', courseId: 'course_it', skillId: 'skill_it_python', difficulty: 'easy' },
    { id: 'q_it_py_03', courseId: 'course_it', skillId: 'skill_it_python', difficulty: 'medium' },
    { id: 'q_it_py_04', courseId: 'course_it', skillId: 'skill_it_python', difficulty: 'medium' },
    { id: 'q_it_web_01', courseId: 'course_it', skillId: 'skill_it_web', difficulty: 'easy' },
    { id: 'q_it_web_02', courseId: 'course_it', skillId: 'skill_it_web', difficulty: 'easy' },
    { id: 'q_it_web_03', courseId: 'course_it', skillId: 'skill_it_web', difficulty: 'medium' },
    { id: 'q_it_web_04', courseId: 'course_it', skillId: 'skill_it_web', difficulty: 'medium' },
  ],
  course_logic: [
    { id: 'q_logic_puz_01', courseId: 'course_logic', skillId: 'skill_logic_puzzles', difficulty: 'easy' },
    { id: 'q_logic_puz_02', courseId: 'course_logic', skillId: 'skill_logic_puzzles', difficulty: 'easy' },
    { id: 'q_logic_puz_03', courseId: 'course_logic', skillId: 'skill_logic_puzzles', difficulty: 'medium' },
    { id: 'q_logic_puz_04', courseId: 'course_logic', skillId: 'skill_logic_puzzles', difficulty: 'hard' },
    { id: 'q_logic_pat_01', courseId: 'course_logic', skillId: 'skill_logic_patterns', difficulty: 'easy' },
    { id: 'q_logic_pat_02', courseId: 'course_logic', skillId: 'skill_logic_patterns', difficulty: 'medium' },
    { id: 'q_logic_pat_03', courseId: 'course_logic', skillId: 'skill_logic_patterns', difficulty: 'medium' },
    { id: 'q_logic_pat_04', courseId: 'course_logic', skillId: 'skill_logic_patterns', difficulty: 'hard' },
  ],
};
