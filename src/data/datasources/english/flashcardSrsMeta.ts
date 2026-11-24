export interface EnglishFlashcardSrsMeta {
  id: string;
  lessonId: string;
  moduleId?: string;
}

const ROWS: readonly (readonly [string, string, string])[] = [["starter_1","starter","a1_m1"],["starter_2","starter","a1_m1"],["a1_m1_1","a1_m1_greetings","a1_m1"],["a1_m1_2","a1_m1_greetings","a1_m1"],["a1_m1_3","a1_m1_greetings","a1_m1"],["a1_m1_4","a1_m1_greetings","a1_m1"],["a1_m2_1","a1_m2_sentence_builder","a1_m2"],["a1_m2_2","a1_m2_sentence_builder","a1_m2"],["a1_m2_3","a1_m2_sentence_builder","a1_m2"],["a1_m2_4","a1_m2_sentence_builder","a1_m2"],["a1_m3_beside","vocab_01","a1_m3"],["a1_m3_between","vocab_01","a1_m3"],["a1_m3_behind","vocab_01","a1_m3"],["a1_m3_armchair","vocab_01","a1_m3"],["a1_m3_qto","a1_m3_time_schedule","a1_m3"],["a1_m3_hp","a1_m3_time_schedule","a1_m3"],["a1_m3_oc","a1_m3_time_schedule","a1_m3"],["a2_m1_1","a2_m1_directions","a2_m1"],["a2_m1_2","a2_m1_directions","a2_m1"],["a2_m1_3","a2_m1_directions","a2_m1"],["a2_m1_4","a2_m1_directions","a2_m1"],["a2_m2_1","a2_m2_shopping","a2_m2"],["a2_m2_2","a2_m2_shopping","a2_m2"],["a2_m2_3","a2_m2_shopping","a2_m2"],["a2_m2_4","a2_m2_shopping","a2_m2"],["a2_m3_1","a2_m3_plans","a2_m3"],["a2_m3_2","a2_m3_plans","a2_m3"],["a2_m3_3","a2_m3_plans","a2_m3"],["a2_m3_4","a2_m3_plans","a2_m3"],["a2_m4_1","a2_m4_messages","a2_m4"],["a2_m4_2","a2_m4_messages","a2_m4"],["a2_m4_3","a2_m4_messages","a2_m4"],["a2_m4_4","a2_m4_messages","a2_m4"],["b1_m1_1","b1_m1_travel","b1_m1"],["b1_m1_2","b1_m1_travel","b1_m1"],["b1_m1_3","b1_m1_travel","b1_m1"],["b1_m1_4","b1_m1_travel","b1_m1"],["b1_m2_1","b1_m2_work_study","b1_m2"],["b1_m2_2","b1_m2_work_study","b1_m2"],["b1_m2_3","b1_m2_work_study","b1_m2"],["b1_m2_4","b1_m2_work_study","b1_m2"],["b1_m3_1","b1_m3_narrative","b1_m3"],["b1_m3_2","b1_m3_narrative","b1_m3"],["b1_m3_3","b1_m3_narrative","b1_m3"],["b1_m3_4","b1_m3_narrative","b1_m3"],["b1_m4_1","b1_m4_decisions","b1_m4"],["b1_m4_2","b1_m4_decisions","b1_m4"],["b1_m4_3","b1_m4_decisions","b1_m4"],["b1_m4_4","b1_m4_decisions","b1_m4"]];

export const ENGLISH_FLASHCARD_SRS_META: readonly EnglishFlashcardSrsMeta[] = ROWS.map(([id, lessonId, mod]) => ({
  id: 'fc_eng_' + id,
  lessonId: 'lesson_eng_' + lessonId,
  ...(mod ? { moduleId: 'mod_eng_' + mod } : {}),
}));
