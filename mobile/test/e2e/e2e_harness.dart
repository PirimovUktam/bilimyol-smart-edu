import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/app.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';

/// Standard test viewports and contract keys (from PROJECT.md Interface Contracts).
class E2EConfig {
  static const Size compactPhone = Size(360, 760);
  static const Size standardPhone = Size(390, 844);

  static const String keyProductTourCompleted = 'bilimyol.product_tour_completed';
  static const String keyLocale = 'bilimyol.locale';
  static const String keyThemeMode = 'bilimyol.theme_mode';
  static const String keyDemoSessionActive = 'bilimyol.demo_session_active';

  static const List<String> allSubjectsUz = [
    'Matematika',
    'Ingliz tili',
    'IT & Kodlaş',
    'Mantiq',
  ];

  static const List<String> bottomNavLabelsUz = [
    'Boş sahifa',
    'Ta’lim yöli',
    'Yölçi AI',
    'Natijalar',
    'Profil',
  ];
}

/// Locale-resilient text lookup helpers (supports Uzbek & Russian).
class L10nExpect {
  static const List<String> tourPage1Titles = [
    'Nimadan boşlaşni biling',
    'Знайте, с чего начать',
  ];
  static const List<String> tourPage2Titles = [
    'Sizga mos darsni sinab köring',
    'Попробуйте подходящий урок',
    'Попробуйте урок',
  ];
  static const List<String> tourPage3Titles = [
    'Ösişingizni körib boring',
    'Отслеживайте свой рост',
    'Следите за прогрессом',
  ];

  static const List<String> tourNext = ['Keyingi', 'Далее'];
  static const List<String> tourSkip = ['Ötkazib yuboriş', 'Пропустить'];
  static const List<String> tourFinish = ['Boşlaş', 'Начать'];

  static const List<String> demoEntry = [
    'Namuna hisobi bilan kiriş',
    'Демо',
    'демо',
  ];
  static const List<String> loginButton = ['Kiriş', 'Войти'];
  static const List<String> registerLink = [
    'Röyxatdan ötiş',
    'Регистрация',
    'Создать аккаунт',
  ];

  static const List<String> navHome = ['Boş sahifa', 'Главная'];
  static const List<String> navRoadmap = [
    'Ta’lim yöli',
    'Путь обучения',
    'Маршрут',
  ];
  static const List<String> navAi = ['Yölçi AI', 'Йолчи AI'];
  static const List<String> navProgress = [
    'Natijalar',
    'Результаты',
    'Прогресс',
  ];
  static const List<String> navProfile = ['Profil', 'Профиль'];

  // Theme, Demo & Profile Action Candidates (uz + ru + fallbacks)
  static const List<String> themeDarkCandidates = [
    'Qoronği',
    'Тёмная',
    'Qoronğu',
    'Tungi',
    'Dark',
  ];
  static const List<String> themeLightCandidates = [
    'Yoruğ',
    'Светлая',
    'Light',
  ];
  static const List<String> demoResetCandidates = [
    'Qayta boşlaş',
    'Сбросить',
    'Namuna natijalarini tiklaş',
  ];
  static const List<String> tourReplayCandidates = [
    'Taniştiruv',
    'Yöriqnoma',
    'Qayta köriş',
    'Повторить обзор',
    'Обзор',
    'Тур',
    'Tour',
  ];
  static const List<String> editNameCandidates = [
    'Ismni tahrirlaş',
    'Tahrirlaş',
    'Редактировать',
    'Изменить имя',
  ];
  static const List<String> saveCandidates = [
    'Saqlaş',
    'Сохранить',
    'Tasdiqlaş',
  ];

  // Concrete Russian copy lists (must NOT rely solely on hasCyrillicOnScreen)
  static const List<String> tourPage1TitlesRu = ['Знайте, с чего начать'];
  static const List<String> tourPage2TitlesRu = [
    'Попробуйте урок под ваш уровень',
    'Попробуйте подходящий урок',
    'Попробуйте урок',
  ];
  static const List<String> tourPage3TitlesRu = [
    'Отслеживайте свой рост',
    'Следите за прогрессом',
  ];
  static const List<String> tourNextRu = ['Далее'];
  static const List<String> tourSkipRu = ['Пропустить'];
  static const List<String> tourFinishRu = ['Начать'];

  static const List<String> loginTitleRu = ['Добро пожаловать'];
  static const List<String> loginButtonRu = ['Войти'];
  static const List<String> demoEntryRu = ['Войти с демо-аккаунтом', 'Демо'];
  static const List<String> registerHeadingRu = [
    'Регистрация',
    'Создать аккаунт',
    'Новый аккаунт',
  ];
  static const List<String> dashboardCopyRu = [
    'Что продолжить сегодня?',
    'Выберите план обучения',
    'Выбрать предмет',
    'Цель на сегодня',
    'Мои курсы',
    'Продолжить',
    'Активные',
    'Рекомендуем',
  ];
  static const List<String> coursesCopyRu = [
    'Выбрать предмет',
    'Каталог предметов',
    'Какой предмет',
  ];
  static const List<String> roadmapCopyRu = [
    'Мой путь обучения',
    'Этапы обучения',
    'Персональные этапы обучения',
    'Учебный маршрут',
    'Карта знаний',
    'Начать',
    'Практиковаться',
    'Заблокировано',
  ];
  static const List<String> aiTutorCopyRu = [
    'Ваш персональный AI-наставник',
    'Привет, я Yölçi AI',
    'Объясни проще',
  ];
  static const List<String> progressCopyRu = [
    'Мои результаты',
    'Показатели обучения',
    'Выполненные уроки',
    'Время обучения',
  ];
  static const List<String> profileCopyRu = [
    'Мой профиль',
    'Настройки обучения',
    'Язык приложения',
    'Выйти',
  ];

  static Finder findAnyText(
    List<String> candidates, {
    bool skipOffstage = false,
  }) {
    for (final text in candidates) {
      final f = find.textContaining(
        text,
        findRichText: true,
        skipOffstage: skipOffstage,
      );
      if (f.evaluate().isNotEmpty) {
        return f;
      }
    }
    return find.textContaining(
      candidates.first,
      findRichText: true,
      skipOffstage: skipOffstage,
    );
  }

  static bool hasAnyText(List<String> candidates) {
    for (final text in candidates) {
      if (find
          .textContaining(text, findRichText: true)
          .evaluate()
          .isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  static void expectAnyVisible(List<String> candidates, {String? reason}) {
    expect(
      hasAnyText(candidates),
      isTrue,
      reason: reason ?? 'Expected one of $candidates to be visible in tree',
    );
  }

  static void expectNoneVisible(List<String> forbiddenTexts, {String? reason}) {
    for (final text in forbiddenTexts) {
      expect(
        find.textContaining(text, findRichText: true),
        findsNothing,
        reason: reason ?? 'Unexpected untranslated/forbidden text "$text"',
      );
    }
  }

  static bool hasCyrillicOnScreen() {
    final cyrillic = RegExp(r'[\u0400-\u04FF]{3,}');
    for (final element in find.byType(Text).evaluate()) {
      final widget = element.widget as Text;
      final value = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      if (cyrillic.hasMatch(value)) return true;
    }
    for (final element in find.byType(RichText).evaluate()) {
      final widget = element.widget as RichText;
      if (cyrillic.hasMatch(widget.text.toPlainText())) return true;
    }
    return false;
  }

  static void expectNoEnglishLeftovers() {
    const bannedExact = ['Roadmap', 'Reset', 'Speaker'];
    for (final word in bannedExact) {
      expect(
        find.text(word, findRichText: true),
        findsNothing,
        reason: 'Untranslated English leftover "$word" must not appear in UI',
      );
    }
  }
}

/// Captures error message snapshots (e.g., RenderFlex overflows, runtime exceptions)
/// without holding live Widget/Element refs (preventing Widget Inspector noise)
/// while always restoring the original FlutterError.onError handler on teardown.
class E2EErrorRecorder {
  final List<String> errors = [];
  void Function(FlutterErrorDetails)? _previousHandler;

  void install() {
    _previousHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.library != 'Flutter test framework') {
        errors.add(details.exceptionAsString());
      }
      _previousHandler?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = _previousHandler;
    });
  }

  List<String> get overflowErrors => errors
      .where(
        (e) => e.contains('RenderFlex overflowed') || e.contains('overflowed by'),
      )
      .toList(growable: false);

  void expectNoOverflow({String? reason}) {
    final summary = overflowErrors.join('\n---\n');
    expect(
      overflowErrors,
      isEmpty,
      reason: reason ?? 'Unexpected RenderFlex overflow(s):\n$summary',
    );
  }

  void expectClean({String? reason}) {
    final summary = errors.join('\n---\n');
    expect(
      errors,
      isEmpty,
      reason: reason ?? 'Unexpected FlutterError(s):\n$summary',
    );
  }
}

/// Controllable fake IAITutorService for deterministic offline/loading/error/retry testing.
class FakeControllableAITutorService implements IAITutorService {
  Completer<AskTutorResponse>? pendingAsk;
  Completer<AIExplanationResponse>? pendingExplain;
  bool failAsk = false;
  bool failExplain = false;
  int askCalls = 0;
  int explainCalls = 0;
  String askAnswer =
      'Bu mavzu böyiça qadam-baqadam yeçim: avval şartni yozing, söng formulani qöllang.';

  @override
  Future<AskTutorResponse> askTutor(AskTutorRequest request) async {
    askCalls++;
    if (pendingAsk != null) {
      return pendingAsk!.future;
    }
    if (failAsk) {
      throw StateError('AI tutor service unavailable');
    }
    return AskTutorResponse(
      tutorName: 'Yölçi AI',
      answer: askAnswer,
      isAiGenerated: false,
      isDeterministicFallback: true,
    );
  }

  @override
  Future<AIExplanationResponse> explainMistake(
    AIExplanationRequest request,
  ) async {
    explainCalls++;
    if (pendingExplain != null) {
      return pendingExplain!.future;
    }
    if (failExplain) {
      throw StateError('Mistake explanation unavailable');
    }
    return AIExplanationResponse(
      tutorName: 'Yölçi AI',
      title: 'Xatoni tahlil qiliş',
      explanation:
          'Siz tanlagan "${request.selectedOption}" örniga "${request.correctOption}" töğri.',
      remediationStep: 'Asosiy formulani yana bir bor tekşirib çiqing.',
      suggestedAction: 'Mustahkamlaş maşqini bajarib köring.',
      isDeterministicFallback: true,
    );
  }

  @override
  Future<GeneratedLessonResponse> generateLesson(
    GenerateLessonRequest request,
  ) async {
    final topic = request.topic ?? request.skillId;
    return GeneratedLessonResponse(
      lessonId: 'lesson_fake_${request.skillId}',
      courseId: request.courseId,
      skillId: request.skillId,
      topic: topic,
      level: request.level ?? 'intermediate',
      difficulty: request.difficulty ?? 'medium',
      title: '$topic böyiça dars',
      summary: 'Qisqaça nazariya va amaliyot.',
      objective: 'Mavzuni mustahkamlaş.',
      estimatedMinutes: 10,
      steps: const [],
      questions: const [],
      isAiGenerated: false,
      model: 'test-fake',
    );
  }
}

/// Answer oracle entry with guaranteed correct and wrong option texts.
class QuestionAnswerPair {
  final String correct;
  final String wrong;
  const QuestionAnswerPair({required this.correct, required this.wrong});
}

/// Opaque-box oracle mapping question text snippets to known correct & wrong options
/// (permits deterministic placement & lesson answers despite option permutation).
const Map<String, QuestionAnswerPair> placementAnswerOracle = {
  // Math
  '(a + 3)²': QuestionAnswerPair(correct: 'a² + 6a + 9', wrong: 'a² + 9'),
  'x² - 25': QuestionAnswerPair(correct: '(x - 5)(x + 5)', wrong: '(x - 5)²'),
  '(2x - 3y)²': QuestionAnswerPair(correct: '-24xy', wrong: '0'),
  '(x² - 9) / (x - 3)': QuestionAnswerPair(correct: 'x + 3', wrong: 'x - 3'),
  'a + b = 7 va ab = 10': QuestionAnswerPair(correct: '29', wrong: '49'),
  '3x - 7 = 14': QuestionAnswerPair(correct: 'x = 7', wrong: 'x = 21'),
  '5(x - 2) = 3x + 4': QuestionAnswerPair(correct: 'x = 7', wrong: 'x = 3'),
  'x² - 5x + 6 = 0': QuestionAnswerPair(
    correct: 'x₁ = 2, x₂ = 3',
    wrong: 'x₁ = -2, x₂ = -3',
  ),
  'x + y = 10 va x - y = 4': QuestionAnswerPair(
    correct: 'x = 7, y = 3',
    wrong: 'x = 6, y = 4',
  ),
  '2x² - 4x + 5 = 0': QuestionAnswerPair(
    correct: 'Haqiqiy ildizi yöq (D < 0)',
    wrong: '2 ta turli ildiz',
  ),
  'f(x) = 2x + 3 berilgan': QuestionAnswerPair(correct: '11', wrong: '8'),
  'f(x) = 6 / (x - 4)': QuestionAnswerPair(correct: 'x ≠ 4', wrong: 'x > 4'),
  'f(x) = 3x - 5 bölsa': QuestionAnswerPair(correct: 'x = 7', wrong: 'x = 5'),
  'f(x) = x² - 4x + 1 bölsa': QuestionAnswerPair(correct: '-2', wrong: '4'),
  'f(g(3))': QuestionAnswerPair(correct: '19', wrong: '49'),
  'f(x) = 4x - 7': QuestionAnswerPair(
    correct: '(x + 7) / 4',
    wrong: '(x - 7) / 4',
  ),
  'y = 2x - 4': QuestionAnswerPair(correct: '(0, -4)', wrong: '(2, 0)'),
  'y = -3x + 6': QuestionAnswerPair(correct: '(2, 0)', wrong: '(0, 6)'),
  'k > 0 va b < 0': QuestionAnswerPair(
    correct: 'I, III, IV çoraklar',
    wrong: 'I, II, III çoraklar',
  ),
  'x² - 6x + 8': QuestionAnswerPair(correct: '(3, -1)', wrong: '(3, 1)'),
  'y = 2x + 1 va y = -x + 4': QuestionAnswerPair(
    correct: '(1, 3)',
    wrong: '(2, 5)',
  ),

  // English (CEFR A1-B1 placement + legacy fallback)
  'It is raining outside': QuestionAnswerPair(
    correct: 'umbrella',
    wrong: 'pillow',
  ),
  'Timur forgot his wallet': QuestionAnswerPair(
    correct: 'lend',
    wrong: 'borrow',
  ),
  'traffic jams during the morning rush': QuestionAnswerPair(
    correct: 'avoid',
    wrong: 'create',
  ),
  'three books on the teacher': QuestionAnswerPair(
    correct: 'are',
    wrong: 'is',
  ),
  'Yesterday evening, Madina': QuestionAnswerPair(
    correct: 'bought',
    wrong: 'buys',
  ),
  'Dilshod has lived in Samarkand': QuestionAnswerPair(
    correct: 'since',
    wrong: 'for',
  ),
  'music club start': QuestionAnswerPair(
    correct: '09:00 in the morning',
    wrong: '09:00 in the evening',
  ),
  'beginner swimming class this week': QuestionAnswerPair(
    correct: 'Thursday at 16:00',
    wrong: 'Wednesday at 16:00',
  ),
  'do for the morning session': QuestionAnswerPair(
    correct:
        'Send the PDF link in the group chat first and give out booklets after lunch',
    wrong: 'Ask participants to print the booklets at home',
  ),
  'Green Park Bookshop': QuestionAnswerPair(
    correct: 'On Wednesday at 11:00 AM',
    wrong: 'On Sunday at 11:00 AM',
  ),
  'Why did Anvar change the plan': QuestionAnswerPair(
    correct: 'Bad weather is expected tomorrow',
    wrong: 'The park is closed at 3:00 PM',
  ),
  'City Bike Pass members': QuestionAnswerPair(
    correct: 'Return the bike within 45 minutes',
    wrong: 'Use the bike only once a week',
  ),
  '"Essential"': QuestionAnswerPair(correct: 'Crucial', wrong: 'Optional'),
  'researcher conducted': QuestionAnswerPair(
    correct: 'thorough',
    wrong: 'careless',
  ),
  '"Ambiguous"': QuestionAnswerPair(
    correct: 'Clear and definite',
    wrong: 'Vague and uncertain',
  ),
  'Neither the manager': QuestionAnswerPair(correct: 'were', wrong: 'was'),
  'If she ____ harder': QuestionAnswerPair(
    correct: 'studied',
    wrong: 'studies',
  ),
  'inverted structure': QuestionAnswerPair(
    correct: 'Rarely have I seen such dedication in a team.',
    wrong: 'Rarely I have seen such dedication in a team.',
  ),
  'Gate 14': QuestionAnswerPair(correct: 'Gate 14', wrong: 'Gate 40'),
  'before midnight': QuestionAnswerPair(
    correct: 'Tonight before 12:00 AM',
    wrong: 'Tomorrow morning',
  ),
  'postponed from Tuesday to Friday': QuestionAnswerPair(
    correct: 'Friday',
    wrong: 'Tuesday',
  ),
  'reception desk': QuestionAnswerPair(
    correct: 'Register at the reception desk',
    wrong: 'Enter the laboratory directly',
  ),
  'cost-effective': QuestionAnswerPair(
    correct: 'Clean energy is getting cheaper to produce',
    wrong: 'Fossil fuels are disappearing',
  ),
  'initial findings seemed contradictory': QuestionAnswerPair(
    correct: 'Later rigorous tests verified the initial theory',
    wrong: 'The hypothesis was decisively proven wrong',
  ),

  // IT & Coding
  'özgaruvçi e’lon qilişning': QuestionAnswerPair(
    correct: 'x = 10',
    wrong: 'int x = 10',
  ),
  'print(3 * "ab")': QuestionAnswerPair(correct: '"ababab"', wrong: '"ab3"'),
  'range(5)': QuestionAnswerPair(correct: '0,1,2,3,4', wrong: '1,2,3,4,5'),
  'range(3)': QuestionAnswerPair(correct: '3 marta', wrong: '2 marta'),
  'eng katta sarlavha': QuestionAnswerPair(correct: '<h1>', wrong: '<h6>'),
  'matn rangini özgartiruvçi': QuestionAnswerPair(
    correct: 'color',
    wrong: 'font-color',
  ),
  'Giperhavola (link)': QuestionAnswerPair(correct: '<a>', wrong: '<link>'),
  '20px taşqi masofa': QuestionAnswerPair(
    correct: 'margin-right: 20px',
    wrong: 'padding-right: 20px',
  ),

  // Logic
  'Barça quşlar uçadi': QuestionAnswerPair(
    correct: 'Çumçu uçadi',
    wrong: 'Çumçu uça olmaydi',
  ),
  'Ali Vali’dan katta': QuestionAnswerPair(correct: 'Olim', wrong: 'Vali'),
  'yomğir yoğsa': QuestionAnswerPair(
    correct: 'Yomğir yoğmadi',
    wrong: 'Yomğir yoğdi',
  ),
  'Ali eng oldinda emas': QuestionAnswerPair(
    correct: 'Vali – Ali – Olim',
    wrong: 'Ali – Vali – Olim',
  ),
  '3, 6, 12, 24': QuestionAnswerPair(correct: '48', wrong: '36'),
  '5, 9, 17, 33': QuestionAnswerPair(correct: '65', wrong: '49'),
  '1, 4, 9, 16, 25': QuestionAnswerPair(correct: '36', wrong: '30'),
  '2, 3, 5, 9, 17': QuestionAnswerPair(correct: '33', wrong: '26'),
};

/// Opaque-box oracle for interactive lessons & reinforcement exercises.
const Map<String, QuestionAnswerPair> lessonAnswerOracle = {
  // Starter lessons
  '4 ta qalamga yana 2 ta qalam': QuestionAnswerPair(correct: '6', wrong: '2'),
  '6 ta daftardan 2 tasi olinsa': QuestionAnswerPair(correct: '4', wrong: '2'),
  'salomlaşiş uçun qaysi sözni': QuestionAnswerPair(
    correct: 'Hello',
    wrong: 'Goodbye',
  ),
  '«Thank you» özbekçada': QuestionAnswerPair(
    correct: 'Rahmat',
    wrong: 'Salom',
  ),
  'Yangi tanişgan döstingiz': QuestionAnswerPair(
    correct: 'Nice to meet you.',
    wrong: 'Goodbye.',
  ),
  'Keçki soat 19:30': QuestionAnswerPair(
    correct: 'Good evening, Mrs. Azizova.',
    wrong: 'Good night, Mrs. Azizova.',
  ),
  'print("Kitob")': QuestionAnswerPair(correct: 'Kitob', wrong: 'print'),
  '2 savatda jami neçta olma': QuestionAnswerPair(correct: '6', wrong: '5'),
  'I ___ a student': QuestionAnswerPair(correct: 'am', wrong: 'is'),
  'print(3 + 4)': QuestionAnswerPair(correct: '7', wrong: '34'),
  'Qaysi gap rost mulohaza': QuestionAnswerPair(
    correct: '4 + 1 = 5',
    wrong: '4 + 1 = 7',
  ),
  '«2 + 2 = 4» rost': QuestionAnswerPair(correct: 'Yolğon', wrong: 'Rost'),

  // Curated roadmap lessons & reinforcements
  '(x + 2)² yoyilmasida': QuestionAnswerPair(correct: '4', wrong: '2'),
  '(x − 5)² ni oçing': QuestionAnswerPair(
    correct: 'x² − 10x + 25',
    wrong: 'x² − 25',
  ),
  '5x − 4 = 16': QuestionAnswerPair(correct: '4', wrong: '3'),
  '3x + 8 = −4': QuestionAnswerPair(correct: '−4', wrong: '4'),
  'f(4) qiymati qança': QuestionAnswerPair(correct: '11', wrong: '8'),
  'Agar x = 2 bölsa, f(x) neçaga teng': QuestionAnswerPair(
    correct: '8',
    wrong: '6',
  ),
  'f(3) qiymatini hisoblang': QuestionAnswerPair(correct: '-2', wrong: '4'),
  'f(4) ning qiymati qança': QuestionAnswerPair(correct: '11', wrong: '19'),
  'y = -3x + 6 çiziği Ox öqini': QuestionAnswerPair(
    correct: '(2, 0)',
    wrong: '(0, 6)',
  ),
  'y = 4x - 8 çiziği Ox öqini': QuestionAnswerPair(
    correct: '(2, 0)',
    wrong: '(0, -8)',
  ),
  'ma’ruza soat neçada boşlanadi': QuestionAnswerPair(
    correct: '15:15 (quarter past three)',
    wrong: '15:30 (half past three)',
  ),
  'Half past four': QuestionAnswerPair(correct: '16:30', wrong: '16:15'),
  'closest synonym for the word "Crucial"': QuestionAnswerPair(
    correct: 'Extremely important',
    wrong: 'Very easy',
  ),
  'If she studies hard': QuestionAnswerPair(
    correct: 'will pass',
    wrong: 'passed',
  ),
  'n = 7 * 3': QuestionAnswerPair(correct: '21', wrong: '73'),
  'print(10 // 3)': QuestionAnswerPair(correct: '3', wrong: '3.333'),
  'Giperhavola (link) uçun qaysi HTML': QuestionAnswerPair(
    correct: '<a>',
    wrong: '<link>',
  ),
  'matn rangini özgartiruvçi CSS': QuestionAnswerPair(
    correct: 'color',
    wrong: 'font-color',
  ),
  'Barça quşlar uçadi. Çumçu quş.': QuestionAnswerPair(
    correct: 'Çumçu uçadi',
    wrong: 'Çumçu uça olmaydi',
  ),
  'Ali > Vali, Vali > Olim': QuestionAnswerPair(correct: 'Olim', wrong: 'Vali'),
  '5, 9, 17, 33, ...': QuestionAnswerPair(correct: '65', wrong: '49'),
  '1, 4, 9, 16, 25, ...': QuestionAnswerPair(correct: '36', wrong: '30'),
};

/// Configures viewport, text scale, platform brightness, reduced motion,
/// keyboard viewInsets, offline flags, and SharedPreferences, then pumps BilimYolApp.
Future<E2EErrorRecorder> pumpBilimYolApp(
  WidgetTester tester, {
  Size viewport = E2EConfig.standardPhone,
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
  bool disableAnimations = true,
  double keyboardBottomInset = 0.0,
  bool initialDemoSession = false,
  String initialRoute = '/welcome',
  Map<String, Object> mockPrefs = const {},
  List<Override> overrides = const [],
  bool recordErrors = true,
  bool settle = true,
}) async {
  final previousAllowFetching = GoogleFonts.config.allowRuntimeFetching;
  GoogleFonts.config.allowRuntimeFetching = false;
  SupabaseConfig.isConfigured = false;
  SupabaseConfig.hasRemoteConfiguration = false;
  final seededPrefs = Map<String, Object>.from(mockPrefs);
  if (initialDemoSession) {
    seededPrefs.putIfAbsent(E2EConfig.keyDemoSessionActive, () => true);
    seededPrefs.putIfAbsent(E2EConfig.keyProductTourCompleted, () => true);
  }
  demoSessionActive.value =
      initialDemoSession ||
      (seededPrefs[E2EConfig.keyDemoSessionActive] == true);
  productTourCompleted.value =
      seededPrefs[E2EConfig.keyProductTourCompleted] == true;

  SharedPreferences.setMockInitialValues(seededPrefs);
  final prefs = await SharedPreferences.getInstance();

  void onDemoSessionChanged() {
    unawaited(
      prefs.setBool(E2EConfig.keyDemoSessionActive, demoSessionActive.value),
    );
  }

  void onProductTourChanged() {
    unawaited(
      prefs.setBool(
        E2EConfig.keyProductTourCompleted,
        productTourCompleted.value,
      ),
    );
  }

  demoSessionActive.addListener(onDemoSessionChanged);
  productTourCompleted.addListener(onProductTourChanged);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  if (keyboardBottomInset > 0) {
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardBottomInset);
  }
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  if (disableAnimations) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  }

  addTearDown(() {
    demoSessionActive.removeListener(onDemoSessionChanged);
    productTourCompleted.removeListener(onProductTourChanged);
    GoogleFonts.config.allowRuntimeFetching = previousAllowFetching;
    demoSessionActive.value = false;
    productTourCompleted.value = false;
    SupabaseConfig.isConfigured = false;
    SupabaseConfig.hasRemoteConfiguration = false;
    appRouter.go('/welcome');
    tester.platformDispatcher.clearAllTestValues();
    tester.view.reset();
    SharedPreferences.setMockInitialValues({});
  });

  final recorder = E2EErrorRecorder();
  if (recordErrors) {
    recorder.install();
  }

  appRouter.go(initialRoute);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lessonAudioControllerFactoryProvider.overrideWithValue(
          () => FakeLessonAudioController(),
        ),
        ...overrides,
      ],
      child: const BilimYolApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  return recorder;
}

/// Simulates a cold app restart by disposing the current ProviderScope (wiping
/// all RAM/Riverpod state) WITHOUT resetting the in-memory SharedPreferences store.
Future<void> restartBilimYolApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
  String initialRoute = '/welcome',
  bool settle = true,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  final prefs = await SharedPreferences.getInstance();
  productTourCompleted.value =
      prefs.getBool(E2EConfig.keyProductTourCompleted) ?? false;
  demoSessionActive.value =
      !SupabaseConfig.hasRemoteConfiguration &&
      (prefs.getBool(E2EConfig.keyDemoSessionActive) ?? false);
  appRouter.go(initialRoute);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lessonAudioControllerFactoryProvider.overrideWithValue(
          () => FakeLessonAudioController(),
        ),
        ...overrides,
      ],
      child: const BilimYolApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Finds a vertical scrollable if one exists, scrolls target into view, taps it, and settles.
Future<void> scrollAndTap(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  if (finder.evaluate().isEmpty) {
    final verticalScrollable = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    if (verticalScrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: verticalScrollable.last,
      );
    }
  }
  expect(finder, findsWidgets);
  final target = finder.first;
  await tester.ensureVisible(target);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  await tester.tap(target);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Taps a localized candidate text if present and settles.
Future<void> tapAnyVisible(
  WidgetTester tester,
  List<String> candidates, {
  bool settle = true,
}) async {
  final finder = L10nExpect.findAnyText(candidates);
  await scrollAndTap(tester, finder, settle: settle);
}

/// Walks through the 3-page Product Tour via "Keyingi" -> "Boşlaş".
Future<void> completeProductTour(WidgetTester tester) async {
  L10nExpect.expectAnyVisible(L10nExpect.tourPage1Titles);
  await tapAnyVisible(tester, L10nExpect.tourNext);
  L10nExpect.expectAnyVisible(L10nExpect.tourPage2Titles);
  await tapAnyVisible(tester, L10nExpect.tourNext);
  L10nExpect.expectAnyVisible(L10nExpect.tourPage3Titles);
  await tapAnyVisible(tester, L10nExpect.tourFinish);
}

/// Skips the Product Tour via "Ötkazib yuboriş".
Future<void> skipProductTour(WidgetTester tester) async {
  await tapAnyVisible(tester, L10nExpect.tourSkip);
}

/// Enters Demo mode from `/welcome` (skipping tour if shown) or `/login`.
Future<void> enterDemoMode(WidgetTester tester) async {
  if (L10nExpect.hasAnyText(L10nExpect.tourSkip)) {
    await skipProductTour(tester);
  }
  if (L10nExpect.hasAnyText(L10nExpect.demoEntry)) {
    await tapAnyVisible(tester, L10nExpect.demoEntry);
    return;
  }
  // If Welcome still shows direct auth choices without tour:
  if (L10nExpect.hasAnyText(L10nExpect.loginButton)) {
    await tapAnyVisible(tester, L10nExpect.loginButton);
  }
  await tapAnyVisible(tester, L10nExpect.demoEntry);
}

/// Selects a course by exact Uzbek title (e.g. 'Matematika', 'Ingliz tili', 'IT & Kodlaş', 'Mantiq').
Future<void> selectCourse(WidgetTester tester, String courseTitle) async {
  final courseFinder = find.text(courseTitle, findRichText: true);
  await scrollAndTap(tester, courseFinder);
}

/// On /onboarding, selects a non-beginner level ('Asoslarini bilaman' or
/// 'Çuqurroq maşq qilmoqçiman') and settles before tapping 'Ixtiyoriy diagnostika'.
Future<void> openOptionalDiagnostic(WidgetTester tester) async {
  final intermediate = find.textContaining(
    'Asoslarini bilaman',
    findRichText: true,
  );
  final advanced = find.textContaining(
    'Çuqurroq maşq qilmoqçiman',
    findRichText: true,
  );
  final levelFinder = intermediate.evaluate().isNotEmpty
      ? intermediate
      : advanced;
  await scrollAndTap(tester, levelFinder);
  await scrollAndTap(
    tester,
    find.textContaining('Ixtiyoriy diagnostika', findRichText: true),
  );
}

/// Verifies both ThemeData brightness AND the actual rendered Scaffold background
/// luminance (< 0.2 for dark, > 0.7 for light) so hardcoded colors cannot pass.
void expectScaffoldThemeBrightness(WidgetTester tester, Brightness expected) {
  final scaffoldFinder = find.byType(Scaffold);
  expect(scaffoldFinder, findsWidgets);
  final scaffold = tester.widget<Scaffold>(scaffoldFinder.first);
  final ctx = tester.element(scaffoldFinder.first);
  expect(Theme.of(ctx).brightness, expected);
  final bg = scaffold.backgroundColor ?? Theme.of(ctx).scaffoldBackgroundColor;
  final luminance = bg.computeLuminance();
  if (expected == Brightness.dark) {
    expect(
      luminance,
      lessThan(0.2),
      reason: 'Expected dark Scaffold background (luminance < 0.2), got $bg ($luminance)',
    );
  } else {
    expect(
      luminance,
      greaterThan(0.7),
      reason: 'Expected light Scaffold background (luminance > 0.7), got $bg ($luminance)',
    );
  }
}

/// Matches the currently rendered question against an answer oracle map and taps
/// either the correct or wrong option widget.
Future<bool> _selectOracleOption(
  WidgetTester tester,
  Map<String, QuestionAnswerPair> oracle, {
  required bool correct,
  Finder? scope,
}) async {
  Finder scoped(Finder inner) =>
      scope == null ? inner : find.descendant(of: scope, matching: inner);

  QuestionAnswerPair? matched;
  for (final entry in oracle.entries) {
    if (scoped(find.textContaining(entry.key, findRichText: true))
        .evaluate()
        .isNotEmpty) {
      matched = entry.value;
      break;
    }
  }
  if (matched == null) return false;
  final targetText = correct ? matched.correct : matched.wrong;

  // Prefer matching inside an option InkWell to avoid colliding with prompt text.
  Finder optionFinder = find.ancestor(
    of: scoped(find.text(targetText)),
    matching: scoped(find.byType(InkWell)),
  );
  if (optionFinder.evaluate().isEmpty) {
    optionFinder = scoped(find.text(targetText));
  }
  if (optionFinder.evaluate().isEmpty) {
    optionFinder = scoped(
      find.textContaining(targetText, findRichText: true),
    );
  }
  if (optionFinder.evaluate().isEmpty) return false;

  await scrollAndTap(tester, optionFinder.last);
  return true;
}

/// Completes the active placement test dynamically using [placementAnswerOracle].
/// Paces submissions >= 850ms wall-clock time to clear PlacementStateNotifier's
/// 800ms rate limit cleanly.
Future<void> completePlacement(
  WidgetTester tester, {
  required bool highAccuracy,
}) async {
  for (var step = 0; step < 12; step++) {
    if (find
        .textContaining('Diagnostika yakunlandi', findRichText: true)
        .evaluate()
        .isNotEmpty) {
      break;
    }

    final selected = await _selectOracleOption(
      tester,
      placementAnswerOracle,
      correct: highAccuracy,
    );
    expect(
      selected,
      isTrue,
      reason: 'Could not match current placement question in oracle',
    );

    // Wait >800ms real wall-clock time for PlacementStateNotifier rate-limit check.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 850)),
    );

    final finishBtn = find.textContaining(
      'Natijalarni Köriş',
      findRichText: true,
    );
    if (finishBtn.evaluate().isNotEmpty) {
      await scrollAndTap(tester, finishBtn);
      final confirmBtn = find.text('Topşiriş');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.last);
        await tester.pumpAndSettle();
      }
      break;
    }

    final nextBtn = find.textContaining('Keyingi Savol', findRichText: true);
    expect(nextBtn, findsWidgets);
    await scrollAndTap(tester, nextBtn);
  }

  expect(
    find.textContaining('Diagnostika yakunlandi', findRichText: true),
    findsOneWidget,
  );
}

/// Advances through non-quiz steps of the open lesson, selects the correct or wrong
/// quiz option via [lessonAnswerOracle], and taps 'TEKŞIRIŞ'.
Future<void> submitLessonQuiz(
  WidgetTester tester, {
  required bool correct,
}) async {
  for (var i = 0; i < 6; i++) {
    final checkBtn = find.textContaining('TEKŞIRIŞ', findRichText: true);
    if (checkBtn.evaluate().isNotEmpty) {
      final freeTextFinder = find.byKey(const Key('free_text_answer_input'));
      if (freeTextFinder.evaluate().isNotEmpty) {
        final isSamIntro = find
            .textContaining('Sam', findRichText: true)
            .evaluate()
            .isNotEmpty;
        final textValue = isSamIntro
            ? (correct ? 'My name is Sam' : 'Sam')
            : (correct ? 'am' : 'wrong');
        await tester.ensureVisible(freeTextFinder);
        await tester.enterText(freeTextFinder, textValue);
        await tester.pumpAndSettle();
        await scrollAndTap(tester, checkBtn);
        return;
      }

      if (find
          .textContaining('Çapdan sözni tanlang', findRichText: true)
          .evaluate()
          .isNotEmpty) {
        const pairs = [
          ('Good morning', 'Xayrli tong'),
          ('Good evening', 'Xayrli keç'),
          ('How are you?', 'Ahvolingiz qanday?'),
          ("I'm fine, thanks.", 'Yaxşiman, rahmat.'),
        ];
        final rightValues = correct
            ? pairs.map((e) => e.$2).toList()
            : [pairs[1].$2, pairs[0].$2, pairs[2].$2, pairs[3].$2];
        for (var idx = 0; idx < pairs.length; idx++) {
          await scrollAndTap(tester, find.text(pairs[idx].$1).first);
          await scrollAndTap(tester, find.text(rightValues[idx]).first);
        }
        await scrollAndTap(tester, checkBtn);
        return;
      }

      final selected = await _selectOracleOption(
        tester,
        lessonAnswerOracle,
        correct: correct,
      );
      expect(
        selected,
        isTrue,
        reason: 'Could not match current lesson quiz question in oracle',
      );
      await scrollAndTap(tester, checkBtn);
      return;
    }
    final nextStep = find.textContaining('Keyingi qadam', findRichText: true);
    if (nextStep.evaluate().isNotEmpty) {
      await scrollAndTap(tester, nextStep);
    } else {
      break;
    }
  }
  fail('Reached end of lesson loop without finding TEKŞIRIŞ button');
}

/// Solves the open ReinforcementSheet using [lessonAnswerOracle].
Future<void> solveReinforcementSheet(WidgetTester tester) async {
  final sheetScope = find.byType(BottomSheet).last;
  expect(
    find.descendant(
      of: sheetScope,
      matching: find.textContaining('Mustahkamlaş Maşqi', findRichText: true),
    ),
    findsWidgets,
  );
  final selected = await _selectOracleOption(
    tester,
    lessonAnswerOracle,
    correct: true,
    scope: sheetScope,
  );
  expect(
    selected,
    isTrue,
    reason: 'Could not match reinforcement question in oracle',
  );
  await scrollAndTap(
    tester,
    find.descendant(
      of: sheetScope,
      matching: find.textContaining('Javobni Tekşiriş', findRichText: true),
    ),
  );
  expect(
    find.descendant(
      of: sheetScope,
      matching: find.textContaining('Ajoyib Natija!', findRichText: true),
    ),
    findsOneWidget,
  );
}

/// Taps a BilimYolBottomNav destination by Uzbek/Russian candidate labels.
Future<void> tapBottomNav(WidgetTester tester, List<String> candidates) async {
  final finder = L10nExpect.findAnyText(candidates);
  expect(finder, findsWidgets);
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

/// On Math /roadmap, locates the 'Funksiyalar' node card and taps its
/// actionable CTA ('Maşq qiliş', 'Boşlaş', or 'Takrorlaş') so tests
/// reliably open `lesson_math_functions_01` instead of falling back to another node.
Future<void> openMathFunctionsLessonFromRoadmap(WidgetTester tester) async {
  final funcTitle = find.text('Funksiyalar', findRichText: true);
  if (funcTitle.evaluate().isEmpty) {
    final verticalScrollable = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    if (verticalScrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        funcTitle,
        180,
        scrollable: verticalScrollable.last,
      );
    }
  }
  expect(funcTitle, findsWidgets);

  Finder? nodeCta;
  final ancestors = find.ancestor(
    of: funcTitle.first,
    matching: find.byWidgetPredicate((_) => true),
  );
  for (final element in ancestors.evaluate()) {
    final scoped = find.byWidget(element.widget);
    final hasOtherNodes =
        find
            .descendant(
              of: scoped,
              matching: find.text('Algebra asoslari', findRichText: true),
            )
            .evaluate()
            .isNotEmpty ||
        find
            .descendant(
              of: scoped,
              matching: find.text('Tenglamalar', findRichText: true),
            )
            .evaluate()
            .isNotEmpty ||
        find
            .descendant(
              of: scoped,
              matching: find.text('Grafiklar', findRichText: true),
            )
            .evaluate()
            .isNotEmpty;
    if (hasOtherNodes) continue;

    for (final label in ['Maşq qiliş', 'Boşlaş', 'Takrorlaş']) {
      final cta = find.descendant(
        of: scoped,
        matching: find.textContaining(label, findRichText: true),
      );
      if (cta.evaluate().isNotEmpty) {
        nodeCta = cta.first;
        break;
      }
    }
    if (nodeCta != null) break;
  }

  expect(
    nodeCta,
    isNotNull,
    reason:
        'Funksiyalar node on /roadmap must expose an actionable CTA (Maşq qiliş / Boşlaş / Takrorlaş)',
  );
  await scrollAndTap(tester, nodeCta!);
}
