BEGIN;

-- Legacy demo questions remain available for existing attempt history and old
-- clients during migration. The server-owned bank never selects their keys.
CREATE TABLE bilimyol_private.demo_placement_question_ids (question_id TEXT PRIMARY KEY);
ALTER TABLE bilimyol_private.demo_placement_question_ids ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON bilimyol_private.demo_placement_question_ids FROM PUBLIC, anon, authenticated;
INSERT INTO bilimyol_private.demo_placement_question_ids (question_id)
SELECT unnest(ARRAY[
  'q_eng_p1', 'q_eng_p2', 'q_eng_p3', 'q_eng_p4', 'q_eng_p5',
  'q_it_py_01', 'q_it_py_02', 'q_it_py_03', 'q_it_py_04', 'q_it_web_01',
  'q_it_web_02', 'q_it_web_03', 'q_it_web_04', 'q_logic_pat_01', 'q_logic_pat_02',
  'q_logic_pat_03', 'q_logic_pat_04', 'q_logic_puz_01', 'q_logic_puz_02', 'q_logic_puz_03',
  'q_logic_puz_04', 'q_math_alg_01', 'q_math_alg_02', 'q_math_alg_03', 'q_math_alg_04',
  'q_math_alg_05', 'q_math_eq_01', 'q_math_eq_02', 'q_math_eq_03', 'q_math_eq_04',
  'q_math_eq_05', 'q_math_func_01', 'q_math_func_02', 'q_math_func_03', 'q_math_func_04',
  'q_math_func_05', 'q_math_func_06', 'q_math_graph_01', 'q_math_graph_02', 'q_math_graph_03',
  'q_math_graph_04', 'q_math_graph_05', 'q_math_p1', 'q_math_p2', 'q_math_p3',
  'q_math_p4', 'q_math_p5'
]);

CREATE VIEW bilimyol_private.placement_question_bank AS
SELECT q.* FROM public.questions q
WHERE q.is_placement AND NOT EXISTS (
  SELECT 1 FROM bilimyol_private.demo_placement_question_ids demo WHERE demo.question_id = q.id
);
REVOKE ALL ON bilimyol_private.placement_question_bank FROM PUBLIC, anon, authenticated;

INSERT INTO public.questions
  (id, course_id, skill_id, text, options, correct_index, difficulty, explanation, audio_sim_text, is_placement)
SELECT id, course_id, skill_id, text, options::JSONB, correct_index, difficulty, explanation, audio_sim_text, true
FROM (VALUES
  ('q_live_math_alg_distribute', 'course_math_01', 'skill_math_algebra', '4(2x − 3) ni qavsdan chiqaring.', '["8x − 3","8x − 12","6x − 12","8x + 12"]', 1, 'easy', '4 ni qavsdagi har bir hadga ko‘paytiramiz.', NULL),
  ('q_live_math_alg_square', 'course_math_01', 'skill_math_algebra', '(2x + 3)² yoyilmasida x ning koeffitsiyenti nechaga teng?', '["4","6","9","12"]', 3, 'medium', 'O‘rta had 2 × 2x × 3 = 12x.', NULL),
  ('q_live_math_alg_difference', 'course_math_01', 'skill_math_algebra', '(2a + b)² − (2a − b)² ifodani soddalashtiring.', '["8ab","4ab","4a²","2b²"]', 0, 'hard', 'Bir xil kvadrat hadlari qisqaradi. 4ab − (−4ab) = 8ab.', NULL),
  ('q_live_math_eq_balance', 'course_math_01', 'skill_math_equations', '5x − 4 = 21 tenglamani yeching.', '["4","6","5","25"]', 2, 'easy', 'Ikki tomonga 4 qo‘shib, 25 ni 5 ga bo‘lamiz.', NULL),
  ('q_live_math_eq_fraction', 'course_math_01', 'skill_math_equations', '(x + 2) / 3 = 4 bo‘lsa, x nechaga teng?', '["6","10","12","14"]', 1, 'medium', 'Ikki tomonni 3 ga ko‘paytiramiz. x + 2 = 12, demak x = 10.', NULL),
  ('q_live_math_eq_roots', 'course_math_01', 'skill_math_equations', 'x² − 7x + 10 = 0 tenglamaning ildizlari qaysi?', '["−2 va −5","−2 va 5","1 va 10","2 va 5"]', 3, 'hard', '(x − 2)(x − 5) = 0 ko‘rinishidan ildizlar 2 va 5.', NULL),
  ('q_live_math_func_value', 'course_math_01', 'skill_math_functions', 'g(x) = 3x − 2 bo‘lsa, g(4) nechaga teng?', '["10","6","12","14"]', 0, 'easy', '3 × 4 − 2 = 10.', NULL),
  ('q_live_math_func_compose', 'course_math_01', 'skill_math_functions', 'f(x) = 2x + 1 bo‘lsa, f(f(2)) ni toping.', '["5","9","11","13"]', 2, 'medium', 'Avval f(2) = 5. So‘ng f(5) = 11.', NULL),
  ('q_live_math_func_change', 'course_math_01', 'skill_math_functions', 'f(x) = x² + 2x bo‘lsa, f(a + 1) − f(a) nimaga teng?', '["2a + 1","2a + 3","a² + 1","2a² + 3"]', 1, 'hard', 'f(a + 1) = a² + 4a + 3. Undan a² + 2a ni ayiring.', NULL),
  ('q_live_math_graph_intercept', 'course_math_01', 'skill_math_graphs', 'y = 2x − 1 grafigi y o‘qini qaysi nuqtada kesadi?', '["(2, 0)","(−1, 0)","(0, 2)","(0, −1)"]', 3, 'easy', 'y o‘qidagi nuqtalarda x = 0. y = −1.', NULL),
  ('q_live_math_graph_slope', 'course_math_01', 'skill_math_graphs', '(−2, 4) va (2, −4) nuqtalardan o‘tuvchi chiziqning qiyaligi qanday?', '["−2","2","−4","0"]', 0, 'medium', 'y ning o‘zgarishi −8, x ning o‘zgarishi 4. Qiyalik −8 / 4 = −2.', NULL),
  ('q_live_math_graph_cross', 'course_math_01', 'skill_math_graphs', 'y = 3x − 2 va y = −x + 6 chiziqlari qayerda kesishadi?', '["(4, 2)","(2, 4)","(1, 5)","(3, 7)"]', 1, 'hard', '3x − 2 = −x + 6 dan x = 2, y = 4.', NULL),
  ('q_live_eng_vocab_borrow', 'course_eng_01', 'skill_eng_vocab', '«May I borrow your pen?» gapida borrow nimani anglatadi?', '["Sotib olmoq","Yo‘qotmoq","Vaqtincha olib turmoq","Birovga berib turmoq"]', 2, 'easy', 'Borrow boshqa kishidan biror narsani keyin qaytarish uchun olib turishni anglatadi.', NULL),
  ('q_live_eng_vocab_scarce', 'course_eng_01', 'skill_eng_vocab', '«Fresh water was scarce after the long drought.» Scarce so‘ziga qaysi variant yaqin?', '["Clean","Expensive","Dangerous","In short supply"]', 3, 'hard', 'Uzoq qurg‘oqchilikdan keyin chuchuk suv yetishmagan. Scarce tanqis degani.', NULL),
  ('q_live_eng_grammar_plural', 'course_eng_01', 'skill_eng_grammar', '«These books ___ mine.» Bo‘sh joyni to‘ldiring.', '["are","is","am","be"]', 0, 'easy', 'These books ko‘plikdagi ega, shuning uchun are ishlatiladi.', NULL),
  ('q_live_eng_grammar_past_condition', 'course_eng_01', 'skill_eng_grammar', '«If I had saved enough money, I ___ the laptop last month.»', '["will buy","would have bought","buy","would buy"]', 1, 'hard', 'O‘tmishda ro‘y bermagan shart uchun if + past perfect, natija uchun would have + past participle ishlatiladi.', NULL),
  ('q_live_eng_reading_notice', 'course_eng_01', 'skill_eng_reading', '«Please bring a pencil to the exam.» Imtihonga nima olib kelish kerak?', '["Daftar","Kitob","Qalam","Kalkulyator"]', 2, 'easy', 'Bring a pencil iborasi qalam olib kelishni anglatadi.', NULL),
  ('q_live_eng_reading_inference', 'course_eng_01', 'skill_eng_reading', '«Nodira had planned to cycle to school. When she saw ice on the road, she took the bus instead.» Reja nima uchun o‘zgardi?', '["Maktab yopildi","U avtobusga kech qoldi","Velosipedini sotdi","Yo‘l sirpanchiq edi"]', 3, 'hard', 'Matnda Nodira yo‘lda muzni ko‘rganidan keyin avtobusni tanlagani aytiladi.', NULL),
  ('q_live_eng_listening_time', 'course_eng_01', 'skill_eng_listening', 'Xabarni tinglang. Uchrashuv soat nechada boshlanadi?', '["9:30","10:15","11:00","12:30"]', 0, 'easy', 'Half past nine soat 9:30 degani.', 'The meeting starts at half past nine.'),
  ('q_live_eng_listening_place', 'course_eng_01', 'skill_eng_listening', 'Xabarni tinglang. O‘quvchilar qayerda uchrashadi?', '["Kutubxona ichida","Sport zali yonida","Maktabning asosiy kirishida","Avtobus bekatida"]', 2, 'medium', 'The main entrance asosiy kirish joyini anglatadi.', 'Please meet at the main entrance, not in the library.'),
  ('q_live_eng_listening_change', 'course_eng_01', 'skill_eng_listening', 'Xabarni tinglang. Sayohat hozir qachonga rejalashtirilgan?', '["Seshanba ertalab","Payshanba kuni tushdan keyin","Chorshanba ertalab","Payshanba ertalab"]', 1, 'hard', 'Xabarning ikkinchi qismida yangi vaqt Thursday afternoon deb aytilgan.', 'The trip was originally planned for Tuesday morning, but because of the weather, it will now take place on Thursday afternoon.'),
  ('q_live_it_python_filter', 'course_it', 'skill_it_python', 'sum(n for n in [2, 3, 4] if n % 2 == 0) qanday natija beradi?', '["9","4","2","6"]', 3, 'hard', 'Filtr faqat juft sonlarni, ya’ni 2 va 4 ni oladi. Ularning yig‘indisi 6.', NULL),
  ('q_live_it_web_label', 'course_it', 'skill_it_web', '<label for="email"> bilan qaysi input bog‘lanadi?', '["<input id=\"email\">","<input name=\"email\">","<input type=\"email\">","<input value=\"email\">"]', 0, 'hard', 'Label tegining for atributi input elementining id qiymatiga teng bo‘lishi kerak.', NULL),
  ('q_live_logic_puzzles_contrapositive', 'course_logic', 'skill_logic_puzzles', '«Agar A rost bo‘lsa, B rost.» B yolg‘on ekani ma’lum. A haqida nima aniq?', '["A rost","A yolg‘on","A ba’zan rost","Ma’lumot yetarli emas"]', 1, 'hard', 'A rost bo‘lganda B ham rost bo‘lishi kerak edi. B yolg‘onligi A yolg‘onligini bildiradi.', NULL),
  ('q_live_logic_patterns_square', 'course_logic', 'skill_logic_patterns', '2, 5, 10, 17, 26 ketma-ketligi uchun keyingi farq 11 bo‘lsa, keyingi had nima?', '["35","36","37","38"]', 2, 'hard', '26 + 11 = 37. Ketma-ket hadlar n² + 1 qoidasiga ham mos keladi.', NULL)
) AS authored(id, course_id, skill_id, text, options, correct_index, difficulty, explanation, audio_sim_text)
ON CONFLICT (id) DO NOTHING;

UPDATE public.questions SET difficulty = 'easy' WHERE id IN (
  'q_live_it_python_compare', 'q_live_it_web_image', 'q_live_logic_all', 'q_live_logic_pattern_three'
) AND is_placement;

CREATE TABLE bilimyol_private.placement_sessions (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  bank_revision TEXT NOT NULL,
  total_questions INT NOT NULL CHECK (total_questions BETWEEN 1 AND 100),
  question_id TEXT,
  question_started_at TIMESTAMPTZ NOT NULL,
  answers JSONB NOT NULL DEFAULT '[]'::jsonb,
  result JSONB,
  completed_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, course_id)
);
ALTER TABLE bilimyol_private.placement_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON bilimyol_private.placement_sessions FROM PUBLIC, anon, authenticated;

-- Balance coverage by skill, then adapt the next question to the last answer
-- in that skill. A skill with an exhausted bank cannot block other skills.
CREATE FUNCTION bilimyol_private.next_placement_question(p_course_id TEXT, p_answers JSONB)
RETURNS TEXT LANGUAGE sql STABLE SET search_path = ''
AS $$
  WITH history AS (
    SELECT item, position, q.skill_id, q.difficulty
    FROM jsonb_array_elements(p_answers) WITH ORDINALITY AS answers(item, position)
    JOIN public.questions q ON q.id = item->>'question_id'
  ), coverage AS (
    SELECT DISTINCT ON (skill_id) skill_id, count(*) OVER (PARTITION BY skill_id) AS answered,
      CASE difficulty WHEN 'easy' THEN 1 WHEN 'hard' THEN 3 ELSE 2 END
      + CASE WHEN (item->>'is_correct')::BOOLEAN THEN 1 ELSE -1 END AS desired
    FROM history ORDER BY skill_id, position DESC
  )
  SELECT q.id
  FROM bilimyol_private.placement_question_bank q
  JOIN public.skills s ON s.id = q.skill_id AND s.course_id = p_course_id
  LEFT JOIN coverage c ON c.skill_id = s.id
  WHERE q.course_id = p_course_id AND COALESCE(c.answered, 0) < 2
    AND NOT EXISTS (SELECT 1 FROM history h WHERE h.item->>'question_id' = q.id)
  ORDER BY COALESCE(c.answered, 0), s.order_index, s.id,
    abs((CASE q.difficulty WHEN 'easy' THEN 1 WHEN 'hard' THEN 3 ELSE 2 END)
      - LEAST(3, GREATEST(1, COALESCE(c.desired, 2)))),
    q.id
  LIMIT 1;
$$;
REVOKE ALL ON FUNCTION bilimyol_private.next_placement_question(TEXT, JSONB) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.advance_placement(
  p_course_id TEXT, p_session_id UUID DEFAULT NULL, p_question_id TEXT DEFAULT NULL,
  p_selected_index INT DEFAULT NULL, p_restart BOOLEAN DEFAULT false
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_now TIMESTAMPTZ;
  v_today DATE;
  v_session bilimyol_private.placement_sessions;
  v_question public.questions;
  v_revision TEXT;
  v_total INT;
  v_attempt JSONB;
  v_last JSONB;
  v_answers JSONB;
  v_next TEXT;
  v_reset BOOLEAN := false;
  v_new_session BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.courses WHERE id = p_course_id AND is_active)
    OR (p_session_id IS NULL AND (p_question_id IS NOT NULL OR p_selected_index IS NOT NULL))
    OR (p_session_id IS NOT NULL AND (p_question_id IS NULL OR p_selected_index IS NULL OR p_restart)) THEN
    RAISE EXCEPTION 'Diagnostika so‘rovi noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || v_uid::TEXT, 0));
  v_now := clock_timestamp();
  v_today := (v_now AT TIME ZONE 'Asia/Tashkent')::date;
  SELECT * INTO v_session FROM bilimyol_private.placement_sessions
  WHERE user_id = v_uid AND course_id = p_course_id;

  IF p_session_id IS NOT NULL AND p_session_id IS DISTINCT FROM v_session.id THEN
    RAISE EXCEPTION 'Diagnostika sessiyasini qayta yuklang.' USING ERRCODE = '42501';
  END IF;
  v_new_session := p_restart AND v_session.completed_at IS NOT NULL
    AND (v_session.completed_at AT TIME ZONE 'Asia/Tashkent')::date < v_today;

  IF v_session.completed_at IS NULL OR v_new_session THEN
    -- A bank change invalidates in-flight choices before they can be applied to
    -- reordered answers. Keep the bank stable through scoring and review.
    PERFORM 1 FROM bilimyol_private.placement_question_bank WHERE course_id = p_course_id FOR SHARE;
    SELECT COALESCE(sum(LEAST(question_count, 2)), 0), md5(string_agg(revision, '|' ORDER BY skill_id))
    INTO v_total, v_revision
    FROM (
      SELECT q.skill_id, count(*) AS question_count, md5(string_agg(md5(to_jsonb(q)::TEXT), '|' ORDER BY q.id)) AS revision
      FROM bilimyol_private.placement_question_bank q
      JOIN public.skills s ON s.id = q.skill_id AND s.course_id = p_course_id
      WHERE q.course_id = p_course_id
      GROUP BY q.skill_id
    ) bank;
    IF v_total NOT BETWEEN 1 AND 100 THEN
      RAISE EXCEPTION 'Bu fan uchun diagnostika savollari tayyor emas.' USING ERRCODE = '22023';
    END IF;

    v_reset := v_session.id IS NOT NULL AND v_session.completed_at IS NULL
      AND (v_session.bank_revision IS DISTINCT FROM v_revision
        OR v_session.question_started_at < v_now - interval '48 hours');
    IF v_session.id IS NULL OR v_new_session OR v_reset THEN
      INSERT INTO bilimyol_private.placement_sessions AS session (
        user_id, course_id, bank_revision, total_questions, question_id, question_started_at
      ) VALUES (
        v_uid, p_course_id, v_revision, v_total,
        bilimyol_private.next_placement_question(p_course_id, '[]'::jsonb), v_now
      )
      ON CONFLICT (user_id, course_id) DO UPDATE SET
        id = EXCLUDED.id, bank_revision = EXCLUDED.bank_revision, total_questions = EXCLUDED.total_questions,
        question_id = EXCLUDED.question_id, question_started_at = EXCLUDED.question_started_at,
        answers = '[]'::jsonb, result = NULL, completed_at = NULL
      RETURNING session.* INTO v_session;
    ELSIF p_session_id IS NOT NULL THEN
      v_last := v_session.answers->-1;
      IF p_question_id = v_session.question_id THEN
        SELECT * INTO STRICT v_question FROM public.questions WHERE id = p_question_id;
        IF p_selected_index < 0 OR p_selected_index >= jsonb_array_length(v_question.options) THEN
          RAISE EXCEPTION 'Tanlangan javob indeksi noto‘g‘ri.' USING ERRCODE = '22023';
        END IF;
        v_answers := v_session.answers || jsonb_build_array(jsonb_build_object(
          'question_id', v_question.id, 'selected_index', p_selected_index,
          'is_correct', p_selected_index = v_question.correct_index,
          'time_spent_seconds', LEAST(600, GREATEST(1, floor(EXTRACT(EPOCH FROM v_now - v_session.question_started_at))))
        ));

        IF jsonb_array_length(v_answers) = v_session.total_questions THEN
          v_attempt := public.save_placement_attempt(p_course_id, v_answers, 'placement-session:' || v_session.id::TEXT);
          SELECT v_attempt || jsonb_build_object('completed_at', v_now, 'answers', jsonb_agg(
            a.item || jsonb_build_object('question_text', q.text,
              'selected_option', q.options->>((a.item->>'selected_index')::INT),
              'correct_option', q.options->>q.correct_index, 'explanation', q.explanation) ORDER BY a.position
          )) INTO v_attempt
          FROM jsonb_array_elements(v_answers) WITH ORDINALITY AS a(item, position)
          JOIN public.questions q ON q.id = a.item->>'question_id';
        ELSE
          v_next := bilimyol_private.next_placement_question(p_course_id, v_answers);
          IF v_next IS NULL THEN
            RAISE EXCEPTION 'Diagnostika savollarini qayta yuklang.' USING ERRCODE = '22023';
          END IF;
        END IF;

        UPDATE bilimyol_private.placement_sessions SET
          answers = v_answers, question_id = v_next, question_started_at = v_now,
          result = v_attempt, completed_at = CASE WHEN v_attempt IS NOT NULL THEN v_now END
        WHERE user_id = v_uid AND course_id = p_course_id
        RETURNING * INTO v_session;
      ELSIF p_question_id IS DISTINCT FROM v_last->>'question_id'
        OR p_selected_index IS DISTINCT FROM (v_last->>'selected_index')::INT THEN
        RAISE EXCEPTION 'Savol o‘zgardi. Diagnostikani qayta yuklang.' USING ERRCODE = '22023';
      END IF;
    END IF;
  END IF;

  SELECT * INTO v_question FROM public.questions WHERE id = v_session.question_id;
  RETURN jsonb_build_object(
    'session_id', v_session.id, 'total_questions', v_session.total_questions,
    'question_number', LEAST(jsonb_array_length(v_session.answers) + 1, v_session.total_questions),
    'question', CASE WHEN v_question.id IS NOT NULL THEN jsonb_build_object(
      'id', v_question.id, 'course_id', v_question.course_id, 'skill_id', v_question.skill_id,
      'text', v_question.text, 'options', v_question.options, 'context_snippet', v_question.context_snippet,
      'formula_latex', v_question.formula_latex, 'audio_sim_text', v_question.audio_sim_text,
      'audio_sim_speaker', v_question.audio_sim_speaker
    ) END,
    'result', v_session.result, 'reset', v_reset,
    'can_retake', COALESCE((v_session.completed_at AT TIME ZONE 'Asia/Tashkent')::date < v_today, false)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.advance_placement(TEXT, UUID, TEXT, INT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.advance_placement(TEXT, UUID, TEXT, INT, BOOLEAN) TO authenticated;

-- The lesson grader used to accept any known question ID, including a
-- placement question under an invented lesson ID. Keep the public signature
-- and ordinary lesson/reinforcement contracts, and close this alternate path.
ALTER FUNCTION public.submit_answer_attempt(UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT)
  SET SCHEMA bilimyol_private;
REVOKE ALL ON FUNCTION bilimyol_private.submit_answer_attempt(UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
CREATE FUNCTION public.submit_answer_attempt(
  p_user_id UUID, p_course_id TEXT, p_skill_id TEXT, p_lesson_id TEXT, p_question_id TEXT,
  p_selected_index INT, p_selected_text TEXT, p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_user_id OR p_lesson_id = 'placement_test'
    OR EXISTS (SELECT 1 FROM public.questions WHERE id = p_question_id AND is_placement) THEN
    RAISE EXCEPTION 'Ushbu javobni bu yo‘l orqali topshirib bo‘lmaydi.' USING ERRCODE = '42501';
  END IF;
  RETURN bilimyol_private.submit_answer_attempt(p_user_id, p_course_id, p_skill_id,
    p_lesson_id, p_question_id, p_selected_index, p_selected_text, p_idempotency_key);
END;
$$;
REVOKE ALL ON FUNCTION public.submit_answer_attempt(UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_answer_attempt(UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT)
  TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
