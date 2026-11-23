import '../../core/l10n/uzbek_alphabet.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/question.dart';
import '../../domain/personalization/starter_question_feedback.dart';
import '../datasources/demo_ai_data.dart';
import 'i_ai_tutor_service.dart';

class DemoAITutorService implements IAITutorService {
  static const Map<String, ({String uz, String ru})> _skillCoachingNotes = {
    'skill_eng_vocab': (
      uz: 'Yangi sözlarni kontekstli gap va talaffuz (IPA) bilan boğlab eslab qoling.',
      ru: 'Запоминайте новые слова в контексте предложения и вместе с произношением (IPA).',
    ),
    'skill_eng_grammar': (
      uz: 'Gapdagi ega-kesim mosligi, zamon körsatkiçi (time marker) va söz tartibini tekşiring.',
      ru: 'Проверяйте согласование подлежащего и сказуемого, маркеры времени и порядок слов.',
    ),
    'skill_eng_listening': (
      uz: 'Audioni tinglayotganda raqam, vaqt iborasi (in the morning/afternoon) va inkor sözlarga e’tibor bering.',
      ru: 'При аудировании обращайте внимание на числа, уточнения времени (in the morning/afternoon) и отрицания.',
    ),
    'skill_eng_reading': (
      uz: 'Matndagi kalit dalilni topib, javob variantini aynan öşa jumla bilan soliştiring.',
      ru: 'Найдите ключевое подтверждение в тексте и сверьте вариант ответа именно с ним.',
    ),
  };

  static const String _apostrophePattern = "['’‘`´\\u02BB\\u02BC]";

  static String _normalizeForMatch(String input) {
    return legacyUzbekSpelling(input)
        .replaceAll('\u2019', "'")
        .replaceAll('\u2018', "'")
        .replaceAll('\u02bc', "'")
        .replaceAll('\u02bb', "'")
        .replaceAll('\u00b4', "'")
        .replaceAll('`', "'")
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static final List<RegExp> _spoilerPatterns = [
    RegExp(r"to'g'ri (javob|variant)", caseSensitive: false),
    RegExp(
      r"(?:^|[^\p{L}\p{N}_])to'g'risi (nima|qaysi)(?:$|[^\p{L}\p{N}_])",
      unicode: true,
      caseSensitive: false,
    ),
    RegExp(
      r"javob(i|ini|ni)? (ayt|ber|ko'rsat|yoz|nima|qaysi)",
      caseSensitive: false,
    ),
    RegExp(r'tayyor javob', caseSensitive: false),
    RegExp(
      r"qaysi (javob|variant|biri)(?:ni)? (to'g'ri|tanlay|belgilay|bosay)",
      caseSensitive: false,
    ),
    RegExp(
      r'(?:^|[^\p{L}\p{N}_])qaysi (birini |biri |variantni |javobni )?(tanlay|belgilay|bosay)(?:$|[^\p{L}\p{N}_])',
      unicode: true,
      caseSensitive: false,
    ),
    RegExp(r'qaysi (javob|variant|biri)\s*\??$', caseSensitive: false),
    RegExp(
      r'(скажи|дай|покажи|подскажи|назови)( мне)? (правильный |верный |точный )?(ответ|вариант)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:^|[^\p{L}\p{N}_])(ответ|вариант)\s+(скажи|дай|подскажи|назови|покажи)(?:$|[^\p{L}\p{N}_])',
      unicode: true,
      caseSensitive: false,
    ),
    RegExp(
      r'(?:^|[^\p{L}\p{N}_])(правильный|верный|точный) (ответ|вариант)\s*\?',
      unicode: true,
      caseSensitive: false,
    ),
    RegExp(
      r'^(правильный|верный|точный) (ответ|вариант)\s*[.!?]*$',
      unicode: true,
      caseSensitive: false,
    ),
    RegExp(
      r'(?:^|[^\p{L}\p{N}_])что (мне |тут )?(выбрать|ответить|нажать)(?:$|[^\p{L}\p{N}_])',
      unicode: true,
      caseSensitive: false,
    ),
    RegExp(r'какой (правильный |верный )?(ответ|вариант)', caseSensitive: false),
    RegExp(r'какой вариант (правильный|верный)', caseSensitive: false),
    RegExp(r'готовый ответ', caseSensitive: false),
    RegExp(
      r'(?:just )?(?:tell|give|show|reveal)(?: me)?(?: the)?(?: correct| right)? (?:answer|option|solution)',
      caseSensitive: false,
    ),
    RegExp(
      r"what('s| is) the( correct| right)? (answer|option|solution)",
      caseSensitive: false,
    ),
    RegExp(
      r'which (answer|option|one) (is (correct|right)|should i (choose|pick|select))',
      caseSensitive: false,
    ),
    RegExp(
      r'^answer please\b|\b(correct|right) (answer|option) please\b',
      caseSensitive: false,
    ),
  ];

  static bool _isSpoilerRequest(String message) {
    final norm = _normalizeForMatch(message);
    return _spoilerPatterns.any((pattern) => pattern.hasMatch(norm));
  }

  static List<String> _collectForbiddenAnswers(Question? q) {
    if (q == null) return const <String>[];
    final forbidden = <String>{};
    void addSecret(String? raw) {
      final trimmed = raw?.trim() ?? '';
      if (trimmed.isEmpty) return;
      if (trimmed.length >= 2) forbidden.add(trimmed);
      final withoutTrailingPunct = trimmed.replaceAll(RegExp(r'[.!?]+$'), '').trim();
      if (withoutTrailingPunct.length >= 2) forbidden.add(withoutTrailingPunct);
    }

    for (final ans in q.acceptedAnswers) {
      addSecret(ans);
    }
    if (q.usesOptionSelection &&
        q.correctIndex >= 0 &&
        q.correctIndex < q.options.length) {
      addSecret(q.options[q.correctIndex]);
    }
    if (q.mode == QuestionMode.sentenceOrder && q.orderedTokens.isNotEmpty) {
      addSecret(q.orderedTokens.join(' '));
    }
    if (q.mode == QuestionMode.wordMatch && q.matchPairs.isNotEmpty) {
      for (final pair in q.matchPairs) {
        addSecret(pair.left);
        addSecret(pair.right);
        final leftTrim = pair.left.trim();
        final rightTrim = pair.right.trim();
        if (leftTrim.isNotEmpty && rightTrim.isNotEmpty) {
          addSecret('$leftTrim -> $rightTrim');
          addSecret('$leftTrim → $rightTrim');
        }
      }
    }
    addSecret(q.sampleResponse);
    final sorted = forbidden.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return sorted;
  }

  static RegExp _buildSecretBoundaryRegex(String secret) {
    final normalizedSecret = secret
        .replaceAll('\u2019', "'")
        .replaceAll('\u2018', "'")
        .replaceAll('\u02bc', "'")
        .replaceAll('\u02bb', "'")
        .replaceAll('\u00b4', "'")
        .replaceAll('`', "'");
    final escaped = RegExp.escape(normalizedSecret).replaceAll("'", _apostrophePattern);
    return RegExp(
      "(?<![\\p{L}\\p{N}_'’‘`´\\u02BB\\u02BC])$escaped(?![\\p{L}\\p{N}_'’‘`´\\u02BB\\u02BC])",
      unicode: true,
      caseSensitive: false,
    );
  }

  static bool _containsForbiddenAnswer(
    String candidate,
    List<String> forbidden,
  ) {
    if (forbidden.isEmpty || candidate.trim().isEmpty) return false;
    for (final rawAns in forbidden) {
      if (_buildSecretBoundaryRegex(rawAns).hasMatch(candidate)) {
        return true;
      }
    }
    return false;
  }

  static String _sanitizeNoSpoilers(String text, List<String> forbidden) {
    if (forbidden.isEmpty || text.trim().isEmpty) return text;
    var output = text;
    for (final rawAns in forbidden) {
      output = output.replaceAll(_buildSecretBoundaryRegex(rawAns), '[...]');
    }
    return output;
  }

  @override
  Future<AIExplanationResponse> explainMistake(
    AIExplanationRequest request,
  ) async {
    final isRu = request.language == 'ru';
    final matched = demoAiResponsesData[request.questionId];

    if (matched != null) {
      if (isRu &&
          (matched.misconceptionTitleRu ?? '').trim().isNotEmpty &&
          (matched.explanationRu ?? '').trim().isNotEmpty) {
        return AIExplanationResponse(
          tutorName: 'Yölçi AI',
          title: matched.misconceptionTitleRu!,
          explanation: matched.explanationRu!,
          remediationStep: matched.remediationStepRu ?? matched.remediationStep,
          suggestedAction: matched.suggestedActionRu ?? matched.suggestedAction,
          isDeterministicFallback: true,
        );
      }
      if (!isRu) {
        return AIExplanationResponse(
          tutorName: 'Yölçi AI',
          title: matched.misconceptionTitle,
          explanation: matched.explanation,
          remediationStep: matched.remediationStep,
          suggestedAction: matched.suggestedAction,
          isDeterministicFallback: true,
        );
      }
    }

    final qCtx = findEnglishQuestionContextById(request.questionId);
    if (request.courseId == 'course_eng_01' || qCtx.question != null) {
      final lang = isRu ? 'ru' : 'uz';
      final lessonCtx =
          qCtx.lesson ??
          findEnglishLessonByContext(
            lessonId: request.lessonId,
            skillId: request.skillId,
            topic: request.topic,
          );
      final q = qCtx.question;
      final forbidden = _collectForbiddenAnswers(q);
      final cefr = q?.cefrLevel ?? lessonCtx?.cefrLevel ?? 'A1';
      final rawTopicLabel =
          q?.topic ??
          lessonCtx?.localizedTitle(lang) ??
          request.topic ??
          (isRu ? 'Английский язык' : 'Ingliz tili');
      final topicLabel = _containsForbiddenAnswer(rawTopicLabel, forbidden)
          ? (isRu ? 'Английский язык' : 'Ingliz tili')
          : rawTopicLabel;
      final optionFeedback =
          buildStarterFreeTextFeedback(
            questionId: request.questionId,
            rawAnswer: request.selectedOption,
            uiLocale: lang,
          ) ??
          q?.localizedOptionFeedback(
            request.selectedOption,
            lang,
          );
      final isNonMcq = q != null && !q.usesOptionSelection;
      final qWrongFeedback = q?.localizedWrongFeedback(lang);
      final qExplanation = q?.localizedExplanation(lang);
      final firstConceptNotes = lessonCtx?.steps
          .where((s) => s.type == LessonStepType.concept)
          .firstOrNull
          ?.localizedHighlightNotes(lang);
      final safeConceptNote = (firstConceptNotes ?? const <String>[])
          .where(
            (note) =>
                note.trim().isNotEmpty &&
                !_containsForbiddenAnswer(note, forbidden),
          )
          .firstOrNull;
      final coachingNote =
          _skillCoachingNotes[q?.skillId ?? request.skillId];
      final localizedCoaching = isRu ? coachingNote?.ru : coachingNote?.uz;
      final canDo = lessonCtx?.localizedCanDo(lang);
      final safeCanDo =
          canDo != null &&
              canDo.trim().isNotEmpty &&
              !_containsForbiddenAnswer(canDo, forbidden)
          ? canDo.trim()
          : null;

      final List<String> diagnosisParts;
      if (isNonMcq) {
        final rawFeedback = (optionFeedback != null &&
                optionFeedback.trim().isNotEmpty)
            ? optionFeedback.trim()
            : (qWrongFeedback != null && qWrongFeedback.trim().isNotEmpty)
            ? qWrongFeedback.trim()
            : (qExplanation != null && qExplanation.trim().isNotEmpty)
            ? qExplanation.trim()
            : (isRu
                  ? 'Ответ (${request.selectedOption}) не соответствует правилу.'
                  : 'Javob (${request.selectedOption}) uşbu qoida bilan mos kelmadi.');
        diagnosisParts = [_sanitizeNoSpoilers(rawFeedback, forbidden)];
      } else {
        diagnosisParts = <String>[
          if (optionFeedback != null && optionFeedback.trim().isNotEmpty)
            optionFeedback.trim()
          else
            (isRu
                ? 'Выбранный вариант (${request.selectedOption}) не соответствует правилу.'
                : 'Tanlangan javob (${request.selectedOption}) qoidaga mos kelmadi.'),
          if (qExplanation != null &&
              qExplanation.trim().isNotEmpty &&
              qExplanation.trim() != optionFeedback?.trim())
            qExplanation.trim(),
          if (request.correctOption.trim().isNotEmpty &&
              !(qExplanation ?? '').contains(request.correctOption.trim()))
            (isRu
                ? 'Правильный ответ: ${request.correctOption}.'
                : 'Töğri javob: ${request.correctOption}.'),
        ];
      }

      final rawRemediation =
          safeConceptNote ??
          localizedCoaching ??
          safeCanDo ??
          (isRu
              ? 'Повторите правило уровня $cefr и попробуйте ещё раз.'
              : '$cefr darajasidagi qoidani takrorlab, yana urinib köring.');
      final remediation = isNonMcq
          ? _sanitizeNoSpoilers(rawRemediation, forbidden)
          : rawRemediation;

      return AIExplanationResponse(
        tutorName: 'Yölçi AI',
        title: isRu
            ? 'Разбор ошибки ($cefr · $topicLabel)'
            : 'Xato tahlili ($cefr · $topicLabel)',
        explanation: diagnosisParts.join(' '),
        remediationStep: remediation,
        suggestedAction: isRu
            ? 'Закрепите тему на дополнительном упражнении уровня $cefr.'
            : '$cefr darajasidagi qöşimça maşq orqali mavzuni mustahkamlang.',
        isDeterministicFallback: true,
      );
    }

    if (isRu) {
      return AIExplanationResponse(
        tutorName: 'Yölçi AI',
        title: 'Разбор ошибки',
        explanation:
            'Выбранный ответ (${request.selectedOption}) неверен. Правильный ответ: ${request.correctOption}.',
        remediationStep:
            'Проверьте правило шаг за шагом и попробуйте выполнить похожее задание.',
        suggestedAction:
            'Давайте закрепим этот навык на коротком дополнительном упражнении.',
        isDeterministicFallback: true,
      );
    }

    return AIExplanationResponse(
      tutorName: 'Yölçi AI',
      title: 'Xatoni tahlil qiliş',
      explanation:
          'Siz tanlagan javob (${request.selectedOption}) töğri emas. Töğri javob: ${request.correctOption}.',
      remediationStep:
          'Mavzuni töliq özlaştiriş uçun formulani qadamma-qadam tekşirib çiqing.',
      suggestedAction:
          'Keling, uşbu könikmani mustahkamlaş maşqi bilan tekşiramiz.',
      isDeterministicFallback: true,
    );
  }

  @override
  Future<GeneratedLessonResponse> generateLesson(
    GenerateLessonRequest request,
  ) async {
    final topic = request.topic ?? request.skillId;
    if (request.courseId == 'course_eng_01') {
      return GeneratedLessonResponse(
        lessonId: 'lesson_fallback_${request.skillId}_eng',
        courseId: request.courseId,
        skillId: request.skillId,
        topic: topic,
        level: request.level ?? 'A1',
        difficulty: request.difficulty ?? 'easy',
        title: '$topic böyiça ingliz tili darsi',
        summary:
            'Ingliz tili ($topic) böyiça qisqa tuşuntiriş, audio namuna va amaliy maşq.',
        objective: 'Mavzuga oid asosiy ibora va qoidani amalda qöllaş.',
        estimatedMinutes: 12,
        steps: const [
          {
            'id': 'eng_gen_step_1',
            'stepNumber': 1,
            'type': 'concept',
            'title': 'Asosiy qoida',
          },
          {
            'id': 'eng_gen_step_2',
            'stepNumber': 2,
            'type': 'visual_example',
            'title': 'Audio namuna',
            'visualModelData': {
              'type': 'audio_wave',
              'speakerName': 'Sarah (Speaker)',
              'audioTranscript':
                  'Consistent daily practice is the key to mastering English vocabulary.',
            },
          },
          {
            'id': 'eng_gen_step_3',
            'stepNumber': 3,
            'type': 'interactive_question',
            'title': 'Amaliy maşq',
          },
        ],
        questions: const [
          {
            'id': 'q_eng_gen_01',
            'courseId': 'course_eng_01',
            'text': 'Choose the natural greeting when meeting a classmate.',
            'options': ['Hello! Nice to meet you.', 'Goodbye forever.', 'Sleep well.'],
            'difficulty': 'easy',
          },
        ],
        isAiGenerated: false,
        model: 'gemini-3.6-flash',
      );
    }
    return GeneratedLessonResponse(
      lessonId: 'lesson_fallback_${request.skillId}',
      courseId: request.courseId,
      skillId: request.skillId,
      topic: topic,
      level: request.level ?? 'intermediate',
      difficulty: request.difficulty ?? 'medium',
      title: '$topic böyiça interaktiv dars',
      summary: 'Asosiy nazariy qoidalar va amaliy misollar jamlanmasi.',
      objective: 'Mavzuni töliq özlaştiriş va mustahkamlaş.',
      estimatedMinutes: 15,
      steps: const [],
      questions: const [],
      isAiGenerated: false,
      model: 'gemini-3.6-flash',
    );
  }

  @override
  Future<AskTutorResponse> askTutor(AskTutorRequest request) async {
    final isRu = request.language == 'ru';
    final lang = isRu ? 'ru' : 'uz';
    final spoilerRequested = _isSpoilerRequest(request.message);

    if (request.courseId == 'course_eng_01') {
      final qCtx = findEnglishQuestionContextById(request.questionId);
      final activeQuestion = qCtx.question;
      final forbidden = _collectForbiddenAnswers(activeQuestion);

      final lessonCtx =
          qCtx.lesson ??
          findEnglishLessonByContext(
            lessonId: request.lessonId,
            skillId: request.questionSkillId ?? request.skillId,
            topic: request.topic,
          );
      final skill = findSkillById(
        request.questionSkillId ?? request.skillId ?? lessonCtx?.skillId,
      );
      final cefr = activeQuestion?.cefrLevel ?? lessonCtx?.cefrLevel ?? 'A1';
      final rawTopicTitle =
          lessonCtx?.localizedTitle(lang) ??
          request.topic ??
          skill?.name ??
          (isRu ? 'Английский язык' : 'Ingliz tili');
      final topicTitle = _containsForbiddenAnswer(rawTopicTitle, forbidden)
          ? (isRu ? 'Английский язык' : 'Ingliz tili')
          : rawTopicTitle;

      final conceptStep = lessonCtx?.steps
          .where((s) => s.type == LessonStepType.concept)
          .firstOrNull;
      final safeHighlights = (conceptStep?.localizedHighlightNotes(lang) ??
              const <String>[])
          .where(
            (n) =>
                !_containsForbiddenAnswer(n, forbidden) &&
                !n.toLowerCase().contains('qadam-baqadam') &&
                !n.toLowerCase().contains('шаг за шагом'),
          )
          .take(2)
          .toList();
      final canDo = lessonCtx?.localizedCanDo(lang);
      final safeCanDo =
          canDo != null &&
              !_containsForbiddenAnswer(canDo, forbidden) &&
              !canDo.toLowerCase().contains('qadam-baqadam') &&
              !canDo.toLowerCase().contains('шаг за шагом')
          ? canDo
          : null;

      final wrongFeedback = activeQuestion?.localizedWrongFeedback(lang);
      final safeWrongFeedback =
          wrongFeedback != null &&
              wrongFeedback.trim().isNotEmpty &&
              !_containsForbiddenAnswer(wrongFeedback, forbidden) &&
              !wrongFeedback.toLowerCase().contains('qadam-baqadam') &&
              !wrongFeedback.toLowerCase().contains('шаг за шагом')
          ? wrongFeedback.trim()
          : null;

      final masteryParts = <String>[];
      if (request.learnerScore != null && request.learnerScore! < 70) {
        masteryParts.add(
          isRu
              ? 'Текущий уровень по навыку (${request.learnerScore}%) — отличная возможность укрепить базу.'
              : 'Joriy könikma körsatkiçi (${request.learnerScore}%) — asosni mustahkamlaş uçun qulay payt.',
        );
      }
      if (request.recentMistakes.isNotEmpty) {
        final mistakesText = request.recentMistakes.take(2).join(', ');
        if (!_containsForbiddenAnswer(mistakesText, forbidden)) {
          masteryParts.add(
            isRu
                ? 'Стоит обратить внимание на недавние ошибки: $mistakesText.'
                : 'Sönggi xatolarga e’tibor bering: $mistakesText.',
          );
        }
      }
      final masteryNote = masteryParts.isEmpty ? null : masteryParts.join(' ');

      final scaffoldHints = <String>[
        ?safeWrongFeedback,
        if (safeHighlights.isNotEmpty) safeHighlights.join(' • '),
        if (safeWrongFeedback == null &&
            safeHighlights.isEmpty &&
            safeCanDo != null)
          safeCanDo,
        ?masteryNote,
      ];

      String assembled;
      if (spoilerRequested) {
        assembled = isRu
            ? 'Я не могу сразу назвать готовый ответ. Давайте разберём вопрос по шагам (шаг за шагом) по теме «$topicTitle» ($cefr): ${scaffoldHints.isNotEmpty ? scaffoldHints.join(' ') : 'обратите внимание на грамматическую структуру и контекст предложения.'}'
            : 'Töğri javobni töğridan-töğri ayta olmayman, lekin «$topicTitle» ($cefr) böyiça qadam-baqadam yöl körsataman: ${scaffoldHints.isNotEmpty ? scaffoldHints.join(' ') : 'gapning tuzilishi va kontekstiga e’tibor bering.'}';
      } else {
        assembled = isRu
            ? 'По теме «$topicTitle» ($cefr): Давайте разберём вопрос по шагам (шаг за шагом). ${scaffoldHints.isNotEmpty ? scaffoldHints.join(' ') : 'Вспомните основное правило и проверьте его на одном примере.'}'
            : '«$topicTitle» ($cefr) mavzusi böyiça buni qadam-baqadam körib çiqamiz: ${scaffoldHints.isNotEmpty ? scaffoldHints.join(' ') : 'asosiy qoidani eslab, uni sodda misolda tekshirib ko‘ring.'}';
      }

      if (_containsForbiddenAnswer(assembled, forbidden)) {
        assembled = isRu
            ? 'Я не могу назвать готовый ответ. Давайте разберём вопрос по шагам (шаг за шагом) по теме «$topicTitle» ($cefr): проверьте структуру предложения и ключевые слова.'
            : 'Töğri javobni oşkor qila olmayman. «$topicTitle» ($cefr) böyiça qadam-baqadam tekşiring: gap tuzilişi va kalit iboralarga qarang.';
      }

      return AskTutorResponse(
        tutorName: 'Yölçi AI',
        answer: assembled,
        isAiGenerated: false,
        isDeterministicFallback: true,
      );
    }

    final topic = request.topic ?? (isRu ? 'эта тема' : 'bu mavzu');
    final answer = spoilerRequested
        ? (isRu
              ? 'Я не могу сразу назвать готовый ответ. Давайте разберём вопрос по шагам (шаг за шагом) по теме «$topic»: сначала вспомните основное правило.'
              : 'Töğri javobni töğridan-töğri ayta olmayman, lekin $topic böyiça qadam-baqadam tekşirib çiqamiz: avval asosiy qoidani eslang.')
        : (isRu
              ? 'Отличный вопрос по теме «$topic»! Давайте разберём вопрос по шагам (шаг за шагом): сначала вспомним основное правило, а затем применим его на простом примере.'
              : '$topic böyiça savolingiz juda yaxşi! Keling, birgalikda qadam-baqadam körib çiqamiz: avval asosiy qoidani eslaysizmi? Uni birgalikda misolda qöllab köramiz.');
    return AskTutorResponse(
      tutorName: 'Yölçi AI',
      answer: answer,
      isAiGenerated: false,
      isDeterministicFallback: true,
    );
  }
}
