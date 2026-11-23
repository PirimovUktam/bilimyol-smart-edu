import '../entities/question.dart';

/// Input-specific mistake feedback for `q_lesson_eng_starter_quiz` matching Web
/// `InMemoryLearnerRepository` / `demoAiResponses` parity in `uz` and `ru`.
///
/// Returns `null` for generic inputs (including `'sam'`) so callers fall back
/// to `question.localizedWrongFeedback(uiLocale)`.
String? buildStarterFreeTextFeedback({
  required String questionId,
  required String rawAnswer,
  String uiLocale = 'uz',
}) {
  if (questionId != 'q_lesson_eng_starter_quiz') return null;
  final normalized = normalizeTextAnswer(rawAnswer);
  final isRu = uiLocale == 'ru';
  if (normalized == 'goodbye' ||
      normalized == 'bye' ||
      normalized == 'good bye') {
    return isRu
        ? '«Goodbye» означает прощание. На вопрос «What\'s your name?» отвечают представлением: «I\'m ...» или «My name is ...».'
        : '«Goodbye» xayrlaşuv sözi. «What\'s your name?» savoliga «I\'m ...» yoki «My name is ...» deb javob beriladi.';
  }
  if (normalized == 'hello' || normalized == 'hi') {
    return isRu
        ? 'Приветствие верное, но собеседник спросил имя. Добавьте «I\'m ...» или «My name is ...».'
        : 'Salomlaşiş töğri, lekin ismingizni ham aytişingiz kerak: «I\'m ...» yoki «My name is ...» şaklida davom ettiring.';
  }
  return null;
}
