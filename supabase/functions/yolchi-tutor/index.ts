// Supabase Edge Function: yolchi-tutor
// Real Google Gemini AI Integration for BilimYo‘l Smart Edu
// Capabilities: Error Diagnosis, Structured Question Generation, Targeted Reinforcement

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Central Model Configuration (Default: Google Gemini 3.6 Flash)
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") || "gemini-3.6-flash";

// Simple in-memory sliding window rate limiter (per user ID)
// Limit: 30 requests per minute per authenticated user
const rateLimitMap = new Map<string, { count: number; resetTime: number }>();

function checkRateLimit(userId: string, limit = 30, windowMs = 60000): boolean {
  const now = Date.now();
  const userRate = rateLimitMap.get(userId);

  if (!userRate || now > userRate.resetTime) {
    rateLimitMap.set(userId, { count: 1, resetTime: now + windowMs });
    return true;
  }

  if (userRate.count >= limit) {
    return false;
  }

  userRate.count++;
  return true;
}

// Request & Response Types
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

type TutorPayload = DiagnoseMistakeRequest | GenerateQuestionRequest | GenerateReinforcementRequest;

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

    if (authHeader && supabaseUrl && supabaseServiceKey) {
      const supabase = createClient(supabaseUrl, supabaseServiceKey);
      const token = authHeader.replace("Bearer ", "");
      const { data: { user } } = await supabase.auth.getUser(token);
      if (user) {
        userId = user.id;
      }
    }

    // 2. Rate Limiting
    if (!checkRateLimit(userId, 30, 60000)) {
      return new Response(
        JSON.stringify({
          error: "Rate limit exceeded. Please wait a minute before making more AI requests.",
          status: 429,
        }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const payload: TutorPayload = await req.json();
    const action = payload.action || "diagnose_mistake";

    // 3. Dispatch Action
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
// ACTION 1: DIAGNOSE MISTAKE
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
// ACTION 2: GENERATE QUESTION
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

  const systemPrompt = `Sen BilimYo‘l Smart Edu platformasining Matematika fani bo‘yicha professional test tuzuvchisisan.
Belgilangan ko‘nikma va qiyinchilik darajasi bo‘yicha 1 ta yangi, to‘liq tekshirilgan va matematik jihatdan 100% to‘g‘ri test savolini tuz.
Variantlar (options) ichida HECH QANDAY javob kaliti, qavsli izoh yoki ishora bo‘lmasin (faqat toza qiymatlar).
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
    // Validate output structure
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

    // If Supabase service credentials available, securely cache question in database
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
// ACTION 3: GENERATE REINFORCEMENT
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
Variantlar ichida javob kaliti yoki ishora bo‘lmasin.
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
        maxOutputTokens: 1000,
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
// DETERMINISTIC FALLBACKS
// ==========================================
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
