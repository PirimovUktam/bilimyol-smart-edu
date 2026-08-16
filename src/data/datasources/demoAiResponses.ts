export interface AIDemoFeedback {
  courseId: string;
  questionId: string;
  misconceptionTitle: string;
  explanation: string;
  remediationStep: string;
  suggestedAction: string;
}

export const DEMO_AI_RESPONSES: Record<string, AIDemoFeedback> = {
  // Math Lesson Mistake: Chosen '8' instead of '11'
  q_math_lesson_interactive: {
    courseId: 'course_math_01',
    questionId: 'q_math_lesson_interactive',
    misconceptionTitle: 'Ozod son (+3) unutilgan',
    explanation:
      'Siz bu misolda 2 × 4 ni to‘g‘ri hisoblagansiz, lekin formuladagi +3 ozod hadini hisobga olmadingiz. To‘g‘ri natija 11 bo‘ladi.',
    remediationStep: 'Chiziqli funksiyada f(x) = ax + b tartibida har doim avval ko‘paytirish, so‘ng qo‘shish bajariladi.',
    suggestedAction: 'Keling, shu qadamni bitta qisqa mustahkamlash mashqi bilan mustahkamlaymiz.',
  },

  // English Lesson Mistake: Chosen '04:00' instead of '03:45'
  q_eng_lesson_interactive: {
    courseId: 'course_eng_01',
    questionId: 'q_eng_lesson_interactive',
    misconceptionTitle: 'Vaqt inkor iborasi e’tibordan chetda qolgan',
    explanation:
      'Siz asosiy "four" so‘zini to‘g‘ri eshitdingiz, ammo "quarter to four" (to‘rtga 15 daqiqa qoldi) va "not at four o\'clock" degan inkor iborasini noto‘g‘ri talqin qildingiz.',
    remediationStep: '"quarter to [hour]" har doim aytilgan soatdan 15 daqiqa oldingi vaqtni bildiradi.',
    suggestedAction: 'Keling, yana bitta qisqa mustahkamlash mashqini bajaramiz.',
  },
};
