// Supabase Edge Function: yolchi-tutor
// Real Google Gemini AI Integration for BilimYo‘l Smart Edu
// Capabilities: Error Diagnosis, Structured Question Generation, Targeted Reinforcement, Full Lesson Generation

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Central Model Configuration (Default: Google Gemini 3.6 Flash)
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") || "gemini-3.6-flash";

// Sliding window rate limiters (per user ID)
const generalRateLimitMap = new Map<string, { count: number; resetTime: number }>();
const lessonRateLimitMap = new Map<string, { count: number; resetTime: number }>();

function checkRateLimit(rateMap: Map<string, { count: number; resetTime: number }>, userId: string, limit = 30, windowMs = 60000): boolean {
  const now = Date.now();
  const userRate = rateMap.get(userId);

  if (!userRate || now > userRate.resetTime) {
    rateMap.set(userId, { count: 1, resetTime: now + windowMs });
    return true;
  }

  if (userRate.count >= limit) {
    return false;
  }

  userRate.count++;
  return true;
}

// Request Types
interface DiagnoseMistakeRequest {
  action?: "diagnose_mistake";
  courseId: string;
  skillId: string;
  questionId?: string;
  questionText: string;
  selectedOption: string;
  correctOption?: string;
  learnerName?: string;
  learnerScore?: number;
}

interface GenerateQuestionRequest {
  action: "generate_question";
  courseId: string;
  skillId: string;
  skillName?: string;
  difficulty: "easy" | "medium" | "hard";
  learnerScore?: number;
  recentMistakes?: string[];
}

interface GenerateReinforcementRequest {
  action: "generate_reinforcement";
  courseId: string;
  skillId: string;
  skillName?: string;
  misconceptionTitle?: string;
  previousQuestionText?: string;
  mistakeExplanation?: string;
}

interface GenerateLessonRequest {
  action: "generate_lesson";
  courseId: string;
  skillId: string;
  topic?: string;
  level?: string;
  difficulty?: "easy" | "medium" | "hard" | number;
  questionCount?: number;
  language?: string;
  learnerScore?: number;
  recentMistakes?: string[];
}

type TutorPayload =
  | DiagnoseMistakeRequest
  | GenerateQuestionRequest
  | GenerateReinforcementRequest
  | GenerateLessonRequest;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const requestId = crypto.randomUUID();

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");

    // 1. Authorization: Extract & verify JWT token
    const authHeader = req.headers.get("Authorization");
    let userId = "anonymous";
    let isAuthenticated = false;

    if (authHeader && supabaseUrl && supabaseServiceKey) {
      const supabase = createClient(supabaseUrl, supabaseServiceKey);
      const token = authHeader.replace("Bearer ", "");
      const { data: { user } } = await supabase.auth.getUser(token);
      if (user) {
        userId = user.id;
        isAuthenticated = true;
      }
    }

    const payload: TutorPayload = await req.json();
    const action = payload.action || "diagnose_mistake";

    // 2. Auth Check for Lesson Generation (Authenticated Users Only)
    if (action === "generate_lesson" && !isAuthenticated) {
      return new Response(
        JSON.stringify({
          error: "Autentifikatsiyadan o‘tilmagan. Dars yaratish uchun tizimga kiring.",
          status: 401,
        }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Rate Limiting (5 lessons/min, 30 general/min)
    if (action === "generate_lesson") {
      if (!checkRateLimit(lessonRateLimitMap, userId, 5, 60000)) {
        return new Response(
          JSON.stringify({
            error: "Dars yaratish bo‘yicha so‘rovlar chegarasidan oshildi. Iltimos, 1 daqiqadan so‘ng qayta urinib ko‘ring.",
            status: 429,
          }),
          { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } else {
      if (!checkRateLimit(generalRateLimitMap, userId, 30, 60000)) {
        return new Response(
          JSON.stringify({
            error: "So‘rovlar soni oshib ketdi. Iltimos, 1 daqiqadan so‘ng qayta urinib ko‘ring.",
            status: 429,
          }),
          { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 4. Dispatch Action
    if (action === "generate_lesson") {
      const res = await handleGenerateLesson(
        payload as GenerateLessonRequest,
        userId,
        geminiApiKey,
        supabaseUrl,
        supabaseServiceKey
      );
      logAudit({ requestId, userId, action, latency: Date.now() - startTime, status: 200 });
      return new Response(JSON.stringify(res), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (action === "generate_question") {
      const res = await handleGenerateQuestion(payload as GenerateQuestionRequest, geminiApiKey, supabaseUrl, supabaseServiceKey);
      logAudit({ requestId, userId, action, latency: Date.now() - startTime, status: 200 });
      return new Response(JSON.stringify(res), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (action === "generate_reinforcement") {
      const res = await handleGenerateReinforcement(payload as GenerateReinforcementRequest, geminiApiKey, supabaseUrl, supabaseServiceKey);
      logAudit({ requestId, userId, action, latency: Date.now() - startTime, status: 200 });
      return new Response(JSON.stringify(res), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Default action: diagnose_mistake
    const res = await handleDiagnoseMistake(payload as DiagnoseMistakeRequest, geminiApiKey);
    logAudit({ requestId, userId, action, latency: Date.now() - startTime, status: 200 });
    return new Response(JSON.stringify(res), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (error: any) {
    console.error(`[Yo‘lchi AI] Error (Request: ${requestId}):`, error?.message || error);
    const fallback = getDeterministicDiagnosisFallback({
      courseId: "course_math_01",
      skillId: "skill_math_functions",
      questionText: "",
      selectedOption: "",
      correctOption: "",
    });
    logAudit({ requestId, userId: "unknown", action: "error", latency: Date.now() - startTime, status: 500 });
    return new Response(JSON.stringify(fallback), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});

// ==========================================
// ACTION: GENERATE FULL LESSON
// ==========================================
async function handleGenerateLesson(
  payload: GenerateLessonRequest,
  userId: string,
  geminiApiKey?: string,
  supabaseUrl?: string,
  supabaseServiceKey?: string
) {
  const normalizedDifficulty = typeof payload.difficulty === "number"
    ? payload.difficulty <= 2 ? "easy" : payload.difficulty >= 4 ? "hard" : "medium"
    : (payload.difficulty || "medium");
  const normalizedLevel = payload.level || "intermediate";
  const normalizedTopic = payload.topic || payload.skillId;
  const questionCount = Math.min(10, Math.max(3, payload.questionCount || 5));

  // 1. Cache Check: Reuse cached lesson if exists
  if (supabaseUrl && supabaseServiceKey) {
    try {
      const supabase = createClient(supabaseUrl, supabaseServiceKey);
      const { data: cachedLesson } = await supabase
        .from("generated_lessons")
        .select("*")
        .eq("course_id", payload.courseId)
        .eq("skill_id", payload.skillId)
        .eq("topic", normalizedTopic)
        .eq("level", normalizedLevel)
        .eq("difficulty", normalizedDifficulty)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (cachedLesson && cachedLesson.questions && Array.isArray(cachedLesson.questions)) {
        // Return sanitized client payload (WITHOUT correct answers)
        return sanitizeLessonForClient(cachedLesson);
      }
    } catch (cacheErr) {
      console.warn("[Yo‘lchi AI] Cache check notice:", cacheErr);
    }
  }

  // 2. If Gemini API key is missing, return deterministic fallback lesson
  if (!geminiApiKey) {
    return getDeterministicLessonFallback(payload.courseId, payload.skillId, normalizedTopic, normalizedDifficulty);
  }

  // 3. Prompt Engineering for Google Gemini 3.6 Flash
  const systemPrompt = `Sen O‘zbekistondagi eng ilg‘or ta’lim platformasi bo‘lgan "BilimYo‘l Smart Edu"ning bosh metodist va sun'iy intellekt o‘qituvchisisan.
Sening vazifang berilgan fan va mavzu bo‘yicha to‘liq, pedagogik jihatdan mukammal, o‘quvchiga tushunarli va interaktiv dars yaratishdir.

MUHIM TALABLAR:
1. Dars o‘zbek tilida (lotin alifbosida), juda ravon va qiziqarli yozilishi shart.
2. Dars bosqichlari (steps):
   - 1-qadam: Asosiy tushuncha va ta'rif (type: "concept")
   - 2-qadam: Asosiy qoida yoki formula (type: "formula")
   - 3-qadam: Batafsil yechilgan misol (type: "concept")
   - 4-qadam: Interaktiv vizual namuna yoki tushuntirish (type: "visual_example")
   - 5-qadam: Yakuniy mustahkamlash savoli (type: "interactive_question")
3. Savollar (questions) ro‘yxati:
   - Aniq ${questionCount} ta ko‘p variantli test savoli bo‘lishi shart.
   - Har bir savolda aynan 4 ta variant (options) bo‘lishi lozim.
   - Variantlar ichida javob kaliti, A/B/C/D harfi yoki ishora yozilmasin.
   - correctIndex 0 dan 3 gacha bo‘lgan bitta to‘g‘ri indeks bo‘lishi kerak.
   - explanation maydonida to‘liq yechim berilsin.

Javobingni FAQAT quyidagi JSON schema formatida qaytar:
{
  "title": "Dars sarlavhasi (masalan: Chiziqli funksiyalar va ularning grafigi)",
  "topic": "${normalizedTopic}",
  "level": "${normalizedLevel}",
  "difficulty": "${normalizedDifficulty}",
  "objective": "Ushbu darsdan ko‘zlangan asosiy pedagogik maqsad",
  "summary": "Darsning 2-3 jumlali qisqacha mazmuni",
  "estimatedMinutes": 15,
  "steps": [
    {
      "id": "step_1",
      "stepNumber": 1,
      "type": "concept",
      "title": "Mavzu bilan tanishish",
      "content": "Batafsil tushuntirish...",
      "highlightNotes": ["Muhim qoida 1", "Muhim qoida 2"]
    },
    {
      "id": "step_2",
      "stepNumber": 2,
      "type": "formula",
      "title": "Asosiy formula",
      "content": "Formula tushuntirishi",
      "formulaData": {
        "latex": "f(x) = kx + b",
        "description": "Chiziqli funksiyaning umumiy ko‘rinishi",
        "variables": [
          {"symbol": "k", "meaning": "Burchak koeffitsiyenti"},
          {"symbol": "b", "meaning": "Ozod had"}
        ]
      }
    },
    {
      "id": "step_3",
      "stepNumber": 3,
      "type": "concept",
      "title": "Misol tahlili",
      "content": "Misol: f(x) = 2x + 3 berilgan..."
    },
    {
      "id": "step_4",
      "stepNumber": 4,
      "type": "visual_example",
      "title": "Grafik ko‘rinishi",
      "content": "Funksiya grafigining fazodagi holati",
      "visualModelData": {
        "type": "function_graph",
        "functionExpr": "2x + 3"
      }
    },
    {
      "id": "step_5",
      "stepNumber": 5,
      "type": "interactive_question",
      "title": "Mustahkamlash savoli",
      "content": "O‘rganganlaringizni tekshiring"
    }
  ],
  "questions": [
    {
      "id": "q1",
      "text": "Savol matni",
      "formulaLatex": "f(x) = 2x + 3",
      "options": ["Variant 1", "Variant 2", "Variant 3", "Variant 4"],
      "correctIndex": 0,
      "difficulty": "${normalizedDifficulty}",
      "explanation": "To‘liq yechim"
    }
  ]
}`;

  const userPrompt = `Fan: ${payload.courseId}
Ko‘nikma: ${payload.skillId}
Mavzu: ${normalizedTopic}
O‘quvchi darajasi: ${normalizedLevel}
Qiyinchilik darajasi: ${normalizedDifficulty}
O‘quvchi o‘zlashtirish balli: ${payload.learnerScore ?? 50}%
Talab etiladigan savollar soni: ${questionCount}`;

  const rawJson = await callGeminiAPI(systemPrompt, userPrompt, geminiApiKey);
  if (!rawJson) {
    return getDeterministicLessonFallback(payload.courseId, payload.skillId, normalizedTopic, normalizedDifficulty);
  }

  try {
    const parsed = JSON.parse(rawJson);

    // 4. Strict Schema & Pedagogical Validation
    if (
      !parsed.title ||
      !Array.isArray(parsed.steps) ||
      parsed.steps.length < 3 ||
      !Array.isArray(parsed.questions) ||
      parsed.questions.length < 3
    ) {
      console.warn("[Yo‘lchi AI] AI output failed structural validation, using fallback");
      return getDeterministicLessonFallback(payload.courseId, payload.skillId, normalizedTopic, normalizedDifficulty);
    }

    // Validate and sanitize questions
    const validQuestions = [];
    for (let i = 0; i < parsed.questions.length; i++) {
      const q = parsed.questions[i];
      if (
        q.text &&
        Array.isArray(q.options) &&
        q.options.length === 4 &&
        typeof q.correctIndex === "number" &&
        q.correctIndex >= 0 &&
        q.correctIndex <= 3
      ) {
        const qId = `q_ai_${Date.now()}_${i + 1}`;
        validQuestions.push({
          id: qId,
          course_id: payload.courseId,
          skill_id: payload.skillId,
          text: q.text,
          formula_latex: q.formulaLatex || null,
          options: q.options,
          correct_index: q.correctIndex,
          difficulty: q.difficulty || normalizedDifficulty,
          explanation: q.explanation || "To‘g‘ri yechim.",
        });
      }
    }

    if (validQuestions.length < 3) {
      return getDeterministicLessonFallback(payload.courseId, payload.skillId, normalizedTopic, normalizedDifficulty);
    }

    const lessonId = `lesson_ai_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    // 5. Persist to Database with Server-Side Correct Answers
    if (supabaseUrl && supabaseServiceKey) {
      try {
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        // Store in generated_lessons
        await supabase.from("generated_lessons").insert({
          id: lessonId,
          course_id: payload.courseId,
          skill_id: payload.skillId,
          topic: normalizedTopic,
          level: normalizedLevel,
          difficulty: normalizedDifficulty,
          title: parsed.title,
          summary: parsed.summary || parsed.title,
          objective: parsed.objective || "Mavzuni to‘liq o‘zlashtirish",
          estimated_minutes: parsed.estimatedMinutes || 15,
          steps: parsed.steps,
          questions: validQuestions,
          generation_model: GEMINI_MODEL,
          created_by: userId !== "anonymous" ? userId : null,
        });

        // Also insert questions into public.questions for anti-cheat verification
        for (const vq of validQuestions) {
          await supabase.from("questions").upsert({
            id: vq.id,
            course_id: vq.course_id,
            skill_id: vq.skill_id,
            text: vq.text,
            formula_latex: vq.formula_latex,
            options: vq.options,
            correct_index: vq.correct_index,
            difficulty: vq.difficulty,
            explanation: vq.explanation,
            is_placement: false,
          });
        }
      } catch (dbErr) {
        console.warn("[Yo‘lchi AI] Lesson persistence notice:", dbErr);
      }
    }

    // 6. Return Sanitized Payload (WITHOUT correctIndex to prevent client cheating)
    return {
      lessonId,
      courseId: payload.courseId,
      skillId: payload.skillId,
      topic: normalizedTopic,
      level: normalizedLevel,
      difficulty: normalizedDifficulty,
      title: parsed.title,
      summary: parsed.summary || parsed.title,
      objective: parsed.objective || "Mavzuni to‘liq o‘zlashtirish",
      estimatedMinutes: parsed.estimatedMinutes || 15,
      steps: parsed.steps,
      questions: validQuestions.map((q) => ({
        id: q.id,
        courseId: q.course_id,
        skillId: q.skill_id,
        text: q.text,
        formulaLatex: q.formula_latex,
        options: q.options,
        difficulty: q.difficulty,
        isAiGenerated: true,
      })),
      isAiGenerated: true,
      model: GEMINI_MODEL,
    };
  } catch {
    return getDeterministicLessonFallback(payload.courseId, payload.skillId, normalizedTopic, normalizedDifficulty);
  }
}

// ==========================================
// ACTION: DIAGNOSE MISTAKE
// ==========================================
async function handleDiagnoseMistake(payload: DiagnoseMistakeRequest, geminiApiKey?: string) {
  if (!geminiApiKey) {
    return getDeterministicDiagnosisFallback(payload);
  }

  const systemPrompt = `Sen BilimYo‘l Smart Edu platformasining Yo‘lchi AI nomli intellektual pedagogik ustozisan.
O‘quvchi test yoki dars savolida xato qildi.
Sening vazifang unga to‘g‘ri javobni shunchaki aytish emas, balki xatoning mohiyatini pedagogik tushunib, nima uchun adashganini va to‘g‘ri qoidani tushuntirishdir.
Javobingni FAQAT quyidagi JSON formatida qaytar:
{
  "tutorName": "Yo‘lchi AI",
  "title": "Xatoning qisqa pedagogik sarlavhasi (masalan: Ozod son unutilgan)",
  "explanation": "O‘quvchi qayerda adashgani haqida 2-3 jumlada tushuntirish",
  "remediationStep": "To‘g‘ri matematik qoidani eslatish (1-2 jumla)",
  "suggestedAction": "Keyingi mustahkamlash qadami tavsiyasi",
  "motivation": "O‘quvchini ruhlantiruvchi qisqa so‘z",
  "reinforcementNeeded": true
}`;

  const userPrompt = `Fan: ${payload.courseId}
Ko‘nikma: ${payload.skillId}
Savol: "${payload.questionText}"
O‘quvchi tanlagan noto‘g‘ri javob: "${payload.selectedOption}"
To‘g‘ri javob: "${payload.correctOption || 'Noma‘lum'}"
O‘quvchi ismi: ${payload.learnerName || 'O‘quvchi'}`;

  const rawJson = await callGeminiAPI(systemPrompt, userPrompt, geminiApiKey);
  if (!rawJson) {
    return getDeterministicDiagnosisFallback(payload);
  }

  try {
    const parsed = JSON.parse(rawJson);
    if (!parsed.title || !parsed.explanation) {
      return getDeterministicDiagnosisFallback(payload);
    }
    return {
      tutorName: "Yo‘lchi AI",
      title: parsed.title,
      explanation: parsed.explanation,
      remediationStep: parsed.remediationStep || "Mavzuni qadamma-qadam takrorlash tavsiya etiladi.",
      suggestedAction: parsed.suggestedAction || "Keling, ushbu mavzuni qisqa mashq bilan mustahkamlaymiz.",
      motivation: parsed.motivation || "Har bir xato — yangi bilim uchun imkoniyatdir!",
      reinforcementNeeded: parsed.reinforcementNeeded ?? true,
      isDeterministicFallback: false,
    };
  } catch {
    return getDeterministicDiagnosisFallback(payload);
  }
}

// ==========================================
// ACTION: GENERATE QUESTION
// ==========================================
async function handleGenerateQuestion(
  payload: GenerateQuestionRequest,
  geminiApiKey?: string,
  supabaseUrl?: string,
  supabaseServiceKey?: string
) {
  if (!geminiApiKey) {
    return getDeterministicQuestionFallback(payload.skillId, payload.difficulty);
  }

  const systemPrompt = `Sen BilimYo‘l Smart Edu platformasining professional test tuzuvchisisan.
Belgilangan ko‘nikma va qiyinchilik darajasi bo‘yicha 1 ta yangi, to‘liq tekshirilgan va 100% to‘g‘ri test savolini tuz.
Variantlar (options) ichida HECH QANDAY javob kaliti yoki ishora bo‘lmasin.
Javobingni FAQAT quyidagi JSON formatida qaytar:
{
  "text": "Savol matni (O‘zbek tilida)",
  "formulaLatex": "Matematik formula (ixtiyoriy, masalan: f(x) = 3x - 2)",
  "options": ["Toza variant 1", "Toza variant 2", "Toza variant 3", "Toza variant 4"],
  "correctIndex": 0,
  "difficulty": "${payload.difficulty}",
  "explanation": "To‘g‘ri yechim va pedagogik tushuntirish"
}`;

  const userPrompt = `Ko‘nikma ID: ${payload.skillId}
Ko‘nikma nomi: ${payload.skillName || payload.skillId}
Qiyinchilik darajasi: ${payload.difficulty}
O‘quvchi balli: ${payload.learnerScore ?? 50}%`;

  const rawJson = await callGeminiAPI(systemPrompt, userPrompt, geminiApiKey);
  if (!rawJson) {
    return getDeterministicQuestionFallback(payload.skillId, payload.difficulty);
  }

  try {
    const parsed = JSON.parse(rawJson);
    if (
      !parsed.text ||
      !Array.isArray(parsed.options) ||
      parsed.options.length !== 4 ||
      typeof parsed.correctIndex !== "number" ||
      parsed.correctIndex < 0 ||
      parsed.correctIndex > 3 ||
      !parsed.explanation
    ) {
      return getDeterministicQuestionFallback(payload.skillId, payload.difficulty);
    }

    const questionId = `q_gen_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    if (supabaseUrl && supabaseServiceKey) {
      try {
        const supabase = createClient(supabaseUrl, supabaseServiceKey);
        await supabase.from("questions").insert({
          id: questionId,
          course_id: payload.courseId,
          skill_id: payload.skillId,
          text: parsed.text,
          options: parsed.options,
          correct_index: parsed.correctIndex,
          difficulty: payload.difficulty,
          explanation: parsed.explanation,
          formula_latex: parsed.formulaLatex || null,
          is_placement: false,
        });
      } catch (dbErr) {
        console.warn("[Yo‘lchi AI] Question caching notice:", dbErr);
      }
    }

    // Return to client WITHOUT correctIndex for security
    return {
      id: questionId,
      courseId: payload.courseId,
      skillId: payload.skillId,
      text: parsed.text,
      formulaLatex: parsed.formulaLatex || null,
      options: parsed.options,
      difficulty: payload.difficulty,
      isAiGenerated: true,
    };
  } catch {
    return getDeterministicQuestionFallback(payload.skillId, payload.difficulty);
  }
}

// ==========================================
// ACTION: GENERATE REINFORCEMENT
// ==========================================
async function handleGenerateReinforcement(
  payload: GenerateReinforcementRequest,
  geminiApiKey?: string,
  supabaseUrl?: string,
  supabaseServiceKey?: string
) {
  if (!geminiApiKey) {
    return getDeterministicQuestionFallback(payload.skillId, "easy");
  }

  const systemPrompt = `Sen BilimYo‘l Smart Edu tizimining mustahkamlovchi mashq tuzuvchi pedagogik intellektisan.
O‘quvchi oldingi misolda xato qildi. Ushbu xatoni bartaraf etish uchun moslashtirilgan 1 ta sodda mustahkamlash misolini tuz.
Variantlar ichida javob kaliti bo‘lmasin.
Javobingni FAQAT quyidagi JSON formatida qaytar:
{
  "text": "Mustahkamlash savoli matni",
  "formulaLatex": "Formula",
  "options": ["Variant 1", "Variant 2", "Variant 3", "Variant 4"],
  "correctIndex": 0,
  "difficulty": "easy",
  "explanation": "Qisqa tushuntirish"
}`;

  const userPrompt = `Ko‘nikma: ${payload.skillId}
Aniqlangan xatolik: ${payload.misconceptionTitle || 'Umumiy xatolik'}
Oldingi savol: ${payload.previousQuestionText || ''}`;

  const rawJson = await callGeminiAPI(systemPrompt, userPrompt, geminiApiKey);
  if (!rawJson) {
    return getDeterministicQuestionFallback(payload.skillId, "easy");
  }

  try {
    const parsed = JSON.parse(rawJson);
    if (!parsed.text || !Array.isArray(parsed.options) || parsed.options.length !== 4) {
      return getDeterministicQuestionFallback(payload.skillId, "easy");
    }

    const questionId = `q_reinf_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    if (supabaseUrl && supabaseServiceKey) {
      try {
        const supabase = createClient(supabaseUrl, supabaseServiceKey);
        await supabase.from("questions").insert({
          id: questionId,
          course_id: payload.courseId,
          skill_id: payload.skillId,
          text: parsed.text,
          options: parsed.options,
          correct_index: parsed.correctIndex,
          difficulty: "easy",
          explanation: parsed.explanation,
          formula_latex: parsed.formulaLatex || null,
          is_placement: false,
        });
      } catch (dbErr) {
        console.warn("[Yo‘lchi AI] Reinforcement caching notice:", dbErr);
      }
    }

    return {
      id: questionId,
      courseId: payload.courseId,
      skillId: payload.skillId,
      text: parsed.text,
      formulaLatex: parsed.formulaLatex || null,
      options: parsed.options,
      difficulty: "easy",
      isAiGenerated: true,
    };
  } catch {
    return getDeterministicQuestionFallback(payload.skillId, "easy");
  }
}

// ==========================================
// GEMINI HTTP API CALLER
// ==========================================
async function callGeminiAPI(systemPrompt: string, userPrompt: string, apiKey: string): Promise<string | null> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [{ text: `${systemPrompt}\n\n${userPrompt}` }],
        },
      ],
      generationConfig: {
        temperature: 0.2,
        maxOutputTokens: 2500,
        responseMimeType: "application/json",
      },
    }),
  });

  if (!res.ok) {
    console.warn(`[Yo‘lchi AI] Gemini API returned status ${res.status}:`, await res.text());
    return null;
  }

  const data = await res.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) return null;

  return text.replace(/```json/g, "").replace(/```/g, "").trim();
}

// ==========================================
// SANITIZE LESSON FOR CLIENT (ANTI-CHEAT)
// ==========================================
function sanitizeLessonForClient(dbLesson: any) {
  const sanitizedQuestions = Array.isArray(dbLesson.questions)
    ? dbLesson.questions.map((q: any) => ({
        id: q.id,
        courseId: q.course_id || dbLesson.course_id,
        skillId: q.skill_id || dbLesson.skill_id,
        text: q.text,
        formulaLatex: q.formula_latex || q.formulaLatex || null,
        options: q.options,
        difficulty: q.difficulty || dbLesson.difficulty,
        isAiGenerated: true,
      }))
    : [];

  return {
    lessonId: dbLesson.id,
    courseId: dbLesson.course_id,
    skillId: dbLesson.skill_id,
    topic: dbLesson.topic,
    level: dbLesson.level,
    difficulty: dbLesson.difficulty,
    title: dbLesson.title,
    summary: dbLesson.summary,
    objective: dbLesson.objective,
    estimatedMinutes: dbLesson.estimated_minutes,
    steps: dbLesson.steps,
    questions: sanitizedQuestions,
    isAiGenerated: true,
    model: dbLesson.generation_model || GEMINI_MODEL,
  };
}

// ==========================================
// DETERMINISTIC FALLBACKS
// ==========================================
function getDeterministicLessonFallback(courseId: string, skillId: string, topic: string, difficulty: string) {
  return {
    lessonId: `lesson_fallback_${skillId}`,
    courseId,
    skillId,
    topic,
    level: "intermediate",
    difficulty,
    title: `${topic || 'Mavzu'} bo‘yicha interaktiv dars`,
    summary: "Asosiy matematik qoidalar, tushunchalar va amaliy misollar jamlanmasi.",
    objective: "Mavzu bo‘yicha nazariy qoidalarni tushunish va amaliy misollar bilan mustahkamlash.",
    estimatedMinutes: 15,
    steps: [
      {
        id: "step_1",
        stepNumber: 1,
        type: "concept",
        title: "Asosiy tushuncha",
        content: "Chiziqli funksiya f(x) = kx + b ko‘rinishida ifodalanadi. Bu yerda k — burchak koeffitsiyenti, b esa ozod haddir.",
        highlightNotes: ["Har doim avval ko‘paytirish amali bajariladi", "Ozod had grafikning Y o‘qini kesish nuqtasini ko‘rsatadi"],
      },
      {
        id: "step_2",
        stepNumber: 2,
        type: "formula",
        title: "Hisoblash formulasi",
        content: "Agar f(x) = 2x + 3 va x = 4 bo‘lsa, f(4) = 2(4) + 3 = 8 + 3 = 11 bo‘ladi.",
        formulaData: {
          latex: "f(x) = 2x + 3",
          description: "Chiziqli bog‘lanish formulasiga son qo‘yish",
          variables: [
            { symbol: "x", meaning: "Erkli o‘zgaruvchi (argument)" },
            { symbol: "f(x)", meaning: "Funksiya qiymati" },
          ],
        },
      },
      {
        id: "step_3",
        stepNumber: 3,
        type: "concept",
        title: "Amaliy namunalar",
        content: "Kundalik hayotda masofa, vaqt va tezlik munosabatlari to‘g‘ri chiziqli funksiyalar yordamida oson ifodalanadi.",
      },
      {
        id: "step_4",
        stepNumber: 4,
        type: "visual_example",
        title: "Grafik tasviri",
        content: "To‘g‘ri chiziq grafigi koordinata o‘qlarida bitta aniq to‘g‘ri chiziqni hosil qiladi.",
        visualModelData: {
          type: "function_graph",
          functionExpr: "2x + 3",
        },
      },
      {
        id: "step_5",
        stepNumber: 5,
        type: "interactive_question",
        title: "O‘zlashtirishni tekshirish",
        content: "Quyidagi savolga to‘g‘ri javob berib, darsni yakunlang.",
      },
    ],
    questions: [
      {
        id: "q_fallback_1",
        courseId,
        skillId,
        text: "f(x) = 2x + 3 funksiya berilgan. Agar x = 4 bo‘lsa, f(4) ning qiymatini toping:",
        formulaLatex: "f(4) = 2(4) + 3",
        options: ["11", "8", "14", "9"],
        difficulty,
        isAiGenerated: false,
      },
      {
        id: "q_fallback_2",
        courseId,
        skillId,
        text: "f(x) = 3x - 1 funksiya berilgan. x = 3 bo‘lganda f(3) nechaga teng?",
        formulaLatex: "f(3) = 3(3) - 1",
        options: ["8", "10", "6", "9"],
        difficulty,
        isAiGenerated: false,
      },
      {
        id: "q_fallback_3",
        courseId,
        skillId,
        text: "Chiziqli funksiya f(x) = kx + b da burchak koeffitsiyenti qaysi harf bilan belgilanadi?",
        formulaLatex: null,
        options: ["k", "b", "x", "f"],
        difficulty,
        isAiGenerated: false,
      },
    ],
    isAiGenerated: false,
    isDeterministicFallback: true,
  };
}

function getDeterministicDiagnosisFallback(payload: DiagnoseMistakeRequest) {
  if (payload.questionId === "q_math_func_01" || payload.selectedOption.includes("8")) {
    return {
      tutorName: "Yo‘lchi AI",
      title: "Ozod son (+3) unutilgan",
      explanation: "Siz bu misolda 2 × 4 = 8 ni to‘g‘ri hisoblagansiz, lekin formuladagi +3 ozod hadini qo‘shishni unutingiz. To‘g‘ri natija 11 bo‘ladi.",
      remediationStep: "Chiziqli funksiyada f(x) = ax + b tartibida har doim avval ko‘paytirish, so‘ng qo‘shish bajariladi.",
      suggestedAction: "Keling, shu qadamni bitta qisqa mustahkamlash mashqi bilan mustahkamlaymiz.",
      motivation: "Ko‘paytirishni to‘g‘ri bajardingiz, endi faqat oxirgi qo‘shish qadamini e’tibordan qochirmang!",
      reinforcementNeeded: true,
      isDeterministicFallback: true,
    };
  }

  return {
    tutorName: "Yo‘lchi AI",
    title: "Xatoni tahlil qilish",
    explanation: `Siz tanlagan javob (${payload.selectedOption}) to‘g‘ri emas. To‘g‘ri natija: ${payload.correctOption || 'aniqlandi'}.`,
    remediationStep: "Mavzuni to‘liq o‘zlashtirish uchun qoidalarni qadamma-qadam tekshirib chiqing.",
    suggestedAction: "Keling, ushbu ko‘nikmani mustahkamlash mashqi bilan sinaymiz.",
    motivation: "Xatolar — bu o‘rganish yo‘lidagi eng yaxshi darslardir!",
    reinforcementNeeded: true,
    isDeterministicFallback: true,
  };
}

function getDeterministicQuestionFallback(skillId: string, difficulty: string) {
  return {
    id: `q_fallback_${skillId}_${difficulty}`,
    courseId: "course_math_01",
    skillId,
    text: "f(x) = 3x + 2 funksiyasi berilgan. Agar x = 2 bo‘lsa, f(2) ning qiymatini toping:",
    formulaLatex: "f(2) = 3(2) + 2",
    options: ["8", "6", "7", "5"],
    difficulty,
    isAiGenerated: false,
    isDeterministicFallback: true,
  };
}

// ==========================================
// AUDIT LOGGING HELPER (No Sensitive Data)
// ==========================================
function logAudit(meta: { requestId: string; userId: string; action: string; latency: number; status: number }) {
  console.log(`[Yo‘lchi AI Audit] req=${meta.requestId} user=${meta.userId} action=${meta.action} latency=${meta.latency}ms status=${meta.status}`);
}
