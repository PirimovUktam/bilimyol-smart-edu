// Supabase Edge Function: yolchi-tutor
// Secure Server-Side Gemini AI integration for BilimYo‘l Smart Edu

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface TutorRequest {
  courseId: string;
  skillId: string;
  questionId: string;
  questionText: string;
  selectedOption: string;
  correctOption: string;
  learnerName?: string;
}

interface TutorResponse {
  tutorName: string;
  title: string;
  explanation: string;
  remediationStep: string;
  suggestedAction: string;
  recommendedNextSkill?: string;
  motivation?: string;
  isDeterministicFallback: boolean;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: TutorRequest = await req.json();
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");

    // If no API key is set in environment, safely return calibrated deterministic response
    if (!geminiApiKey) {
      return new Response(
        JSON.stringify(getDeterministicFallback(payload)),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Call Google Gemini API
    const systemPrompt = `Sen BilimYo‘l Smart Edu platformasining Yo‘lchi AI nomli intellektual pedagogik ustozisan. 
O‘quvchi test/dars savolida xato qildi. 
Sening vazifang unga to‘g‘ri javobni shunchaki aytish emas, balki uning xatosini pedagogik tushunib, nima uchun adashganini va to‘g‘ri yo‘lni tushuntirishdir.
Javobingni FAQAT quyidagi JSON formatida qaytar, qo‘shimcha matn yozma:
{
  "title": "Xatoning qisqa pedagogik sarlavhasi (masalan: Ozod son (+3) unutilgan)",
  "explanation": "O‘quvchi qayerda adashgani haqida 2-3 jumlada tushuntirish",
  "remediationStep": "To‘g‘ri qoidani eslatish (1-2 jumla)",
  "suggestedAction": "Keyingi mustahkamlash qadami tavsiyasi",
  "motivation": "O‘quvchini ruhlantiruvchi qisqa so‘z"
}`;

    const userPrompt = `Kurs: ${payload.courseId}
Ko‘nikma: ${payload.skillId}
Savol: "${payload.questionText}"
O‘quvchi tanlagan noto‘g‘ri javob: "${payload.selectedOption}"
To‘g‘ri javob: "${payload.correctOption}"
O‘quvchi ismi: ${payload.learnerName || "O‘quvchi"}`;

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiApiKey}`;

    const geminiRes = await fetch(geminiUrl, {
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
          maxOutputTokens: 800,
          responseMimeType: "application/json",
        },
      }),
    });

    if (!geminiRes.ok) {
      console.warn("Gemini API error, falling back to deterministic response", await geminiRes.text());
      return new Response(
        JSON.stringify(getDeterministicFallback(payload)),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiData = await geminiRes.json();
    const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!rawText) {
      return new Response(
        JSON.stringify(getDeterministicFallback(payload)),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Clean and parse JSON
    const parsed = JSON.parse(rawText.replace(/```json/g, "").replace(/```/g, "").trim());

    const result: TutorResponse = {
      tutorName: "Yo‘lchi AI",
      title: parsed.title || "Xatoni tahlil qilish",
      explanation: parsed.explanation || `Siz ${payload.selectedOption} ni tanladingiz. To‘g‘ri javob esa ${payload.correctOption}.`,
      remediationStep: parsed.remediationStep || "Mavzuni qadamma-qadam takrorlash tavsiya etiladi.",
      suggestedAction: parsed.suggestedAction || "Keling, ushbu mavzuni qisqa mashq bilan mustahkamlaymiz.",
      motivation: parsed.motivation || "Har bir xato — yangi bilim uchun imkoniyatdir!",
      isDeterministicFallback: false,
    };

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Yo‘lchi AI error:", error);
    return new Response(
      JSON.stringify(getDeterministicFallback({
        courseId: "course_math_01",
        skillId: "skill_math_functions",
        questionId: "generic",
        questionText: "",
        selectedOption: "",
        correctOption: "",
      })),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

function getDeterministicFallback(payload: TutorRequest): TutorResponse {
  if (payload.questionId === "q_math_lesson_interactive" || payload.selectedOption.includes("8")) {
    return {
      tutorName: "Yo‘lchi AI",
      title: "Ozod son (+3) unutilgan",
      explanation: "Siz bu misolda 2 × 4 = 8 ni to‘g‘ri hisoblagansiz, lekin formuladagi +3 ozod hadini qo‘shishni unutingiz. To‘g‘ri natija 11 bo‘ladi.",
      remediationStep: "Chiziqli funksiyada f(x) = ax + b tartibida har doim avval ko‘paytirish, so‘ng qo‘shish bajariladi.",
      suggestedAction: "Keling, shu qadamni bitta qisqa mustahkamlash mashqi bilan mustahkamlaymiz.",
      motivation: "Ko‘paytirishni to‘g‘ri bajardingiz, endi faqat oxirgi qo‘shish qadamini e’tibordan qochirmang!",
      isDeterministicFallback: true,
    };
  }

  if (payload.questionId === "q_eng_lesson_interactive" || payload.selectedOption.includes("04:00")) {
    return {
      tutorName: "Yo‘lchi AI",
      title: "Vaqt inkor iborasi e’tibordan chetda qolgan",
      explanation: "Siz asosiy 'four' so‘zini to‘g‘ri eshitdingiz, ammo 'quarter to four' (03:45) va 'not at four o'clock' degan inkor iborasini noto‘g‘ri talqin qildingiz.",
      remediationStep: "'quarter to [hour]' har doim aytilgan soatdan 15 daqiqa oldingi vaqtni bildiradi.",
      suggestedAction: "Keling, yana bitta qisqa mustahkamlash mashqini bajaramiz.",
      motivation: "Listeningda inkor so‘zlariga e’tibor qaratish ko‘nikmasini rivojlantiramiz!",
      isDeterministicFallback: true,
    };
  }

  return {
    tutorName: "Yo‘lchi AI",
    title: "Xatoni tahlil qilish",
    explanation: `Siz tanlagan javob (${payload.selectedOption}) to‘g‘ri emas. To‘g‘ri javob: ${payload.correctOption}.`,
    remediationStep: "Mavzuni to‘liq o‘zlashtirish uchun qoidalarni qadamma-qadam tekshirib chiqing.",
    suggestedAction: "Keling, ushbu ko‘nikmani mustahkamlash mashqi bilan sinaymiz.",
    motivation: "Xatolar — bu o‘rganish yo‘lidagi eng yaxshi darslardir!",
    isDeterministicFallback: true,
  };
}
