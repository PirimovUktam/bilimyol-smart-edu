import '../../domain/entities/lesson.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/skill.dart';
import 'lessons_data.dart';
import 'questions_data.dart';
import 'skills_data.dart';

class AIDemoFeedbackModel {
  final String courseId;
  final String questionId;
  final String misconceptionTitle;
  final String? misconceptionTitleRu;
  final String explanation;
  final String? explanationRu;
  final String remediationStep;
  final String? remediationStepRu;
  final String suggestedAction;
  final String? suggestedActionRu;

  const AIDemoFeedbackModel({
    required this.courseId,
    required this.questionId,
    required this.misconceptionTitle,
    this.misconceptionTitleRu,
    required this.explanation,
    this.explanationRu,
    required this.remediationStep,
    this.remediationStepRu,
    required this.suggestedAction,
    this.suggestedActionRu,
  });
}

/// Deterministic, offline Yo‘lchi AI mistake explanations keyed by the real
/// assessment ids used in the bundled lesson banks. When a question id is not
/// listed here the AI service looks up A1–B1 English curriculum metadata or
/// produces a generic, still-correct explanation.
const Map<String, AIDemoFeedbackModel> demoAiResponsesData = {
  // Math lesson: selected '8' instead of '11' for f(4) = 2x + 3
  'q_math_func_01_step': AIDemoFeedbackModel(
    courseId: 'course_math_01',
    questionId: 'q_math_func_01_step',
    misconceptionTitle: 'Ozod son (+3) hisobga olinmagan',
    misconceptionTitleRu: 'Не учтён свободный член (+3)',
    explanation:
        'Siz 2 × 4 ni to‘g‘ri hisoblagansiz, lekin formuladagi +3 ozod hadini qo‘shishni unutdingiz. To‘g‘ri natija 11 bo‘ladi.',
    explanationRu:
        'Вы правильно вычислили 2 × 4, но забыли прибавить свободный член +3 из формулы. Верный ответ — 11.',
    remediationStep:
        'f(x) = ax + b ko‘rinishida avval ko‘paytirish, so‘ng qo‘shish bajariladi: f(4) = 2·4 + 3 = 11.',
    remediationStepRu:
        'В функции вида f(x) = ax + b сначала выполняется умножение, затем сложение: f(4) = 2·4 + 3 = 11.',
    suggestedAction:
        'Keling, shu qadamni qisqa mustahkamlash mashqi bilan mustahkamlaymiz.',
    suggestedActionRu:
        'Давайте закрепим этот шаг на коротком дополнительном упражнении.',
  ),

  // English listening lesson: "quarter past three" = 15:15 (in the afternoon)
  'q_eng_listening_01_step': AIDemoFeedbackModel(
    courseId: 'course_eng_01',
    questionId: 'q_eng_listening_01_step',
    misconceptionTitle: 'Vaqt iborasi noto‘g‘ri talqin qilindi',
    misconceptionTitleRu: 'Выражение времени понято неверно',
    explanation:
        '"Quarter past three" — soat uchdan 15 daqiqa o‘tganini bildiradi, ya’ni 15:15. "In the afternoon" esa kunduzgi vaqtni anglatadi.',
    explanationRu:
        '«Quarter past three» означает 15 минут после трёх, то есть 15:15. Фраза «in the afternoon» уточняет дневное время.',
    remediationStep:
        '"quarter past [hour]" = soatdan +15 daqiqa; "quarter to [hour]" = keyingi soatga 15 daqiqa qolgan.',
    remediationStepRu:
        '«quarter past [час]» = +15 минут к часу; «quarter to [час]» = без 15 минут следующий час.',
    suggestedAction:
        'Keling, vaqt iboralarini bitta qisqa mashqda mustahkamlaymiz.',
    suggestedActionRu:
        'Давайте закрепим выражения времени в одном коротком упражнении.',
  ),
  'q_eng_listening_01': AIDemoFeedbackModel(
    courseId: 'course_eng_01',
    questionId: 'q_eng_listening_01',
    misconceptionTitle: 'Vaqt iborasi noto‘g‘ri talqin qilindi',
    misconceptionTitleRu: 'Выражение времени понято неверно',
    explanation:
        '"Quarter past three" — soat uchdan 15 daqiqa o‘tganini bildiradi, ya’ni 15:15. "In the afternoon" dalili tufayli bu tonggi 03:15 emas, kunduzgi 15:15.',
    explanationRu:
        '«Quarter past three» означает 15 минут после трёх (15:15). Благодаря уточнению «in the afternoon» это 15:15 дня, а не 03:15 ночи.',
    remediationStep:
        '"quarter past [hour]" = soatdan +15 daqiqa; "in the afternoon" = kunduzi (PM).',
    remediationStepRu:
        '«quarter past [час]» = +15 минут к часу; «in the afternoon» = днём (PM).',
    suggestedAction:
        'Keling, vaqt iboralarini bitta qisqa mashqda mustahkamlaymiz.',
    suggestedActionRu:
        'Давайте закрепим выражения времени в одном коротком упражнении.',
  ),
};

({Lesson? lesson, LessonStep? step, Question? question})
findEnglishQuestionContextById(String? questionId) {
  if (questionId == null || questionId.trim().isEmpty) {
    return (lesson: null, step: null, question: null);
  }
  for (final lesson in seedLessons.values) {
    if (lesson.courseId != 'course_eng_01') continue;
    for (final step in lesson.steps) {
      if (step.interactiveQuestion?.id == questionId) {
        return (lesson: lesson, step: step, question: step.interactiveQuestion);
      }
    }
    if (lesson.reinforcementExercise.id == questionId) {
      return (lesson: lesson, step: null, question: lesson.reinforcementExercise);
    }
    if (lesson.alternateExercise?.id == questionId) {
      return (lesson: lesson, step: null, question: lesson.alternateExercise);
    }
  }
  for (final q in placementQuestionsData['course_eng_01'] ?? const <Question>[]) {
    if (q.id == questionId) {
      return (lesson: null, step: null, question: q);
    }
  }
  return (lesson: null, step: null, question: null);
}

Lesson? findEnglishLessonByContext({
  String? lessonId,
  String? skillId,
  String? topic,
}) {
  if (lessonId != null && lessonId.trim().isNotEmpty) {
    final direct = seedLessons[lessonId];
    if (direct != null && direct.courseId == 'course_eng_01') {
      return direct;
    }
  }
  final normTopic = (topic ?? '').trim().toLowerCase();
  if (normTopic.isNotEmpty) {
    for (final lesson in seedLessons.values) {
      if (lesson.courseId != 'course_eng_01') continue;
      if (lesson.title.toLowerCase().contains(normTopic) ||
          (lesson.titleRu ?? '').toLowerCase().contains(normTopic) ||
          (lesson.canDoObjective ?? '').toLowerCase().contains(normTopic)) {
        return lesson;
      }
    }
  }
  if (skillId != null && skillId.trim().isNotEmpty) {
    for (final lesson in seedLessons.values) {
      if (lesson.courseId == 'course_eng_01' && lesson.skillId == skillId) {
        return lesson;
      }
    }
  }
  return null;
}

Skill? findSkillById(String? skillId) {
  if (skillId == null || skillId.trim().isEmpty) return null;
  return seedSkills.where((s) => s.id == skillId).firstOrNull;
}
