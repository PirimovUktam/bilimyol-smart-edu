class AIDemoFeedbackModel {
  final String courseId;
  final String questionId;
  final String misconceptionTitle;
  final String explanation;
  final String remediationStep;
  final String suggestedAction;

  const AIDemoFeedbackModel({
    required this.courseId,
    required this.questionId,
    required this.misconceptionTitle,
    required this.explanation,
    required this.remediationStep,
    required this.suggestedAction,
  });
}

/// Deterministic, offline Yo‘lchi AI mistake explanations keyed by the real
/// assessment ids used in the bundled lesson banks. When a question id is not
/// listed here the AI service produces a generic, still-correct explanation
/// that includes the learner's choice and the correct option.
const Map<String, AIDemoFeedbackModel> demoAiResponsesData = {
  // Math lesson: selected '8' instead of '11' for f(4) = 2x + 3
  'q_math_func_01_step': AIDemoFeedbackModel(
    courseId: 'course_math_01',
    questionId: 'q_math_func_01_step',
    misconceptionTitle: 'Ozod son (+3) hisobga olinmagan',
    explanation:
        'Siz 2 × 4 ni to‘g‘ri hisoblagansiz, lekin formuladagi +3 ozod hadini qo‘shishni unutdingiz. To‘g‘ri natija 11 bo‘ladi.',
    remediationStep:
        'f(x) = ax + b ko‘rinishida avval ko‘paytirish, so‘ng qo‘shish bajariladi: f(4) = 2·4 + 3 = 11.',
    suggestedAction:
        'Keling, shu qadamni qisqa mustahkamlash mashqi bilan mustahkamlaymiz.',
  ),

  // English listening lesson: "quarter past three" = 15:15
  'q_eng_listening_01_step': AIDemoFeedbackModel(
    courseId: 'course_eng_01',
    questionId: 'q_eng_listening_01_step',
    misconceptionTitle: 'Vaqt iborasi noto‘g‘ri talqin qilindi',
    explanation:
        '"Quarter past three" — soat uchdan 15 daqiqa o‘tganini bildiradi, ya’ni 15:15. Siz vaqt iborasini boshqa tomonga o‘girdingiz.',
    remediationStep:
        '"quarter past [hour]" = soatdan +15 daqiqa; "quarter to [hour]" = keyingi soatga 15 daqiqa qolgan.',
    suggestedAction:
        'Keling, vaqt iboralarini bitta qisqa mashqda mustahkamlaymiz.',
  ),
};
