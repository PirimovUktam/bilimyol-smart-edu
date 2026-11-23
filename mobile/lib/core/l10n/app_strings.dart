import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../domain/entities/course.dart';
import '../../domain/entities/skill_score.dart';
import '../../domain/personalization/skill_scoring_engine.dart';

/// Bilingual (`uz` default, `ru` supported) localization catalog for BilimYöl.
class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  bool get isRu => locale.languageCode == 'ru';

  static const AppStrings uz = AppStrings(Locale('uz'));
  static const AppStrings ru = AppStrings(Locale('ru'));

  static const List<Locale> supportedLocales = [Locale('uz'), Locale('ru')];

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ?? uz;
  }

  static AppStrings forCode(String code) => code == 'ru' ? ru : uz;

  String _t(String uzText, String ruText) => isRu ? ruText : uzText;

  // --- Brand & Core Nav ---
  String get brandTag => 'Smart Edu';
  String get brandSubtitle => _t(
    'Moslaşuvçan ta’lim platformasi',
    'Адаптивная образовательная платформа',
  );
  String get navHome => _t('Boş sahifa', 'Главная');
  String get navRoadmap => _t('Ta’lim yöli', 'Путь обучения');
  String get navAiTutor => 'Yölçi AI';
  String get navProgress => _t('Natijalar', 'Результаты');
  String get navProfile => _t('Profil', 'Профиль');

  // --- Common Actions & States ---
  String get back => _t('Orqaga', 'Назад');
  String get retry => _t('Qayta uriniş', 'Повторить');
  String get cancel => _t('Bekor qiliş', 'Отмена');
  String get save => _t('Saqlaş', 'Сохранить');
  String get close => _t('Yopiş', 'Закрыть');
  String get loading => _t('Yuklanmoqda...', 'Загрузка...');
  String get errorTitle =>
      _t('Ma’lumotlarni yuklab bölmadi.', 'Не удалось загрузить данные.');
  String get errorSubtitle => _t(
    'Internet aloqasini tekşirib, qayta urinib köring.',
    'Проверьте подключение к интернету и попробуйте снова.',
  );
  String get demoBanner => _t(
    'Namuna rejimi. Maşğulotni qayta boşlaşingiz mumkin.',
    'Демо-режим. Вы можете перезапустить обучение.',
  );
  String get demoReset => _t('Qayta boşlaş', 'Сбросить');
  String get demoResetSuccess =>
      _t('Demo muvaffaqiyatli tiklandi.', 'Демо-режим успешно сброшен.');
  String get demoResetFailed => _t(
    'Namuna holatini tiklab bölmadi. Qayta urinib köring.',
    'Не удалось сбросить демо-режим. Попробуйте ещё раз.',
  );

  // --- Product Tour (Mening bilim yölim) ---
  String get tourConceptPill =>
      _t('Mening bilim yölim', 'Мой путь к знаниям');
  String tourStepCounter(int current, int total) => '$current / $total';
  String get tourReplayAction =>
      _t('Taniştiruvni qayta köriş', 'Повторить обзор');
  String get tourThemeToggleTooltip => _t('Mavzuni almaştiriş', 'Сменить тему');
  String get tourLanguageToggleTooltip => _t('Tilni almaştiriş', 'Сменить язык');
  String get tourNext => _t('Keyingi', 'Далее');
  String get tourSkip => _t('Ötkazib yuboriş', 'Пропустить');
  String get tourFinish => _t('Boşlaş', 'Начать');
  String get tourSlide1Title =>
      _t('Nimadan boşlaşni biling.', 'Знайте, с чего начать.');
  String get tourSlide1Body => _t(
    'Qisqa diagnostika sizning kuçli tomonlaringiz va böşliqlaringizni aniq körsatadi.',
    'Короткая диагностика точно определит ваши сильные стороны и пробелы.',
  );
  String get tourSlide1VisualTitle =>
      _t('Diagnostika nuqtani topadi', 'Диагностика находит точку старта');
  String get tourSlide1Chip1 => _t('Algebra • 82%', 'Алгебра • 82%');
  String get tourSlide1Chip2 => _t('Boşlanğiç nuqta', 'Точка старта');
  String get tourSlide1Chip3 => _t('Funksiyalar', 'Функции');
  String get tourSlide2Title =>
      _t('Sizga mos darsni sinab köring.', 'Попробуйте урок под ваш уровень.');
  String get tourSlide2Body => _t(
    'Har bir mavzu tuşunarli misol, amaliy savol va tezkor izoh bilan beriladi.',
    'Каждая тема включает понятный пример, практику и быстрый разбор.',
  );
  String get tourSlide2InteractiveHint =>
      _t('Haqiqiy darsdan kiçik maşq:', 'Мини-задание из реального урока:');
  String tourSlide2MiniLessonTitle(String uzTitle) =>
      isRu ? 'Начинаем со сложения и вычитания' : uzTitle;
  String tourSlide2MiniQuestionText(String uzText) => isRu
      ? 'Если к 4 карандашам добавить ещё 2 карандаша, сколько станет всего?'
      : uzText;
  String get tourSlide2CorrectFeedback =>
      _t('Töğri! 4 ta va 2 ta qalam = 6.', 'Верно! 4 + 2 = 6.');
  String get tourSlide2WrongFeedback =>
      _t('Yana bir bor urinib köring — javobni bosing.', 'Попробуйте ещё раз — нажмите ответ.');
  String get tourSlide3Title =>
      _t('Ösişingizni körib boring.', 'Отслеживайте свой рост.');
  String get tourSlide3Body => _t(
    'Bilim xaritasi va ta’lim yölingiz har bir darsdan söng avtomatik yangilanadi.',
    'Карта знаний и путь обучения обновляются автоматически после каждого урока.',
  );
  String get tourSlide3MasteredBadge => _t('Bajarildi', 'Пройдено');
  String get tourSlide3NextBadge => _t('Navbatdagi dars', 'Следующий урок');
  String get tourSlide3NextLessonTitle =>
      _t('Çiziqli funksiya: f(x) = 2x + 3', 'Линейная функция: f(x) = 2x + 3');
  String get tourSlide3XpChip => '+25 XP';

  // --- Auth ---
  String get authTagline => _t(
    'AI yordamida şaxsiylaştirilgan ta’lim',
    'Персонализированное обучение с AI',
  );
  String get authHeroHeadline1 => _t('Kelajagingni', 'Создавай будущее');
  String get authHeroHeadline2 => _t('bilim bilan yarat!', 'вместе со знаниями!');
  String get authHeroSubtitle => _t(
    'Şaxsiy ta’lim yölingizni bugun boşlang',
    'Начните персональный путь обучения уже сегодня',
  );
  String get loginTitle => _t('Xuş kelibsiz!', 'Добро пожаловать!');
  String get loginSubtitle => _t(
    'Şaxsiy ta’lim yölingizni davom ettiriş uçun tizimga kiring',
    'Войдите, чтобы продолжить персональный путь обучения',
  );
  String get emailLabel => _t('Email manzilingiz', 'Ваш email');
  String get emailHint => 'nomingiz@misol.uz';
  String get passwordLabel => _t('Parol', 'Пароль');
  String get passwordPlaceholder => '••••••••';
  String get passwordShowTooltip =>
      _t('Parolni körsatiş', 'Показать пароль');
  String get passwordHideTooltip => _t('Parolni yaşiriş', 'Скрыть пароль');
  String get orDivider => _t('yoki', 'или');
  String get noAccountQuestion => _t('Hisobingiz yöqmi?', 'Нет аккаунта?');
  String get haveAccountQuestion =>
      _t('Hisobingiz bormi?', 'Уже есть аккаунт?');
  String get loginAction => _t('Kiriş', 'Войти');
  String get demoEnterAction =>
      _t('Namuna hisobi bilan kiriş', 'Войти с демо-аккаунтом');
  String get registerAction => _t('Röyxatdan ötiş', 'Регистрация');
  String get registerHeading =>
      _t('Yangi hisob yaratiş', 'Создать новый аккаунт');
  String get firstNameLabel => _t('Ism *', 'Имя *');
  String get firstNameHint => _t('Ismingiz', 'Ваше имя');
  String get registerEmailLabel => _t('Email *', 'Email *');
  String get registerPasswordLabel => _t('Parol *', 'Пароль *');
  String get passwordMin6Hint =>
      _t('Kamida 6 ta belgi', 'Минимум 6 символов');
  String get confirmPasswordLabel =>
      _t('Parolni tasdiqlang *', 'Подтвердите пароль *');
  String get confirmPasswordHint =>
      _t('Parolni qayta kiriting', 'Повторите пароль');
  String get createAccountAction => _t('Hisob Yaratiş', 'Создать аккаунт');
  String get forgotPassword =>
      _t('Parolni unutdingizmi?', 'Забыли пароль?');
  String get resetPasswordTitle =>
      _t('Parolni tiklaş', 'Восстановление пароля');
  String get forgotPasswordHeading =>
      _t('Parolni qayta tiklaş', 'Сброс пароля');
  String get forgotPasswordSubtitle => _t(
    'Email manzilingizni kiriting — tiklaş havolasini yuboramiz.',
    'Введите ваш email — мы отправим ссылку для восстановления.',
  );
  String get sendResetLinkAction =>
      _t('Tiklaş havolasini yuboriş', 'Отправить ссылку');
  String get resetLinkSentTitle => _t('Havola yuborildi!', 'Ссылка отправлена!');
  String resetLinkSentBody(String email) => _t(
    '$email manziliga tiklaş havolasi yuborildi.',
    'Ссылка для восстановления отправлена на $email.',
  );
  String get backToLoginAction =>
      _t('Kiriş sahifasiga qaytiş', 'Вернуться ко входу');
  String get newPasswordHeading =>
      _t('Yangi parol belgilang', 'Задайте новый пароль');
  String get passwordUpdatedHeading =>
      _t('Parol yangilandi', 'Пароль обновлён');
  String get newPasswordLabel => _t('Yangi parol', 'Новый пароль');
  String get repeatPasswordLabel =>
      _t('Parolni takrorlang', 'Повторите пароль');
  String get savePasswordAction =>
      _t('Parolni saqlaş', 'Сохранить пароль');
  String get emptyLoginFieldsError => _t(
    'Iltimos, email va parolni töliq kiriting.',
    'Пожалуйста, введите email и пароль полностью.',
  );
  String get emptyRegisterFieldsError => _t(
    'Iltimos, barça majburiy maydonlarni töldiring.',
    'Пожалуйста, заполните все обязательные поля.',
  );
  String get invalidEmailError => _t(
    'Email manzilini töğri kiriting.',
    'Введите корректный адрес электронной почты.',
  );
  String get shortPassword6Error => _t(
    'Parol kamida 6 ta belgidan iborat bölişi kerak.',
    'Пароль должен содержать минимум 6 символов.',
  );
  String get shortPassword8Error => _t(
    'Kamida 8 ta belgi kiriting.',
    'Введите минимум 8 символов.',
  );
  String get passwordMismatchError => _t(
    'Kiritilgan parollar bir-biriga mos kelmadi.',
    'Введённые пароли не совпадают.',
  );
  String get authServiceUnavailable => _t(
    'Hisob xizmatiga ulanib bölmadi. Qayta urinib köring.',
    'Не удалось подключиться к сервису авторизации. Попробуйте снова.',
  );
  String get authServiceOfflineShort => _t(
    'Hisob xizmatiga ulanib bölmadi.',
    'Не удалось подключиться к сервису авторизации.',
  );
  String get demoNoRegisterError => _t(
    'Namuna rejimida yangi hisob yaratilmaydi.',
    'В демо-режиме новый аккаунт не создаётся.',
  );
  String get demoNoResetError => _t(
    'Namuna rejimida tiklaş xati yuborilmaydi.',
    'В демо-режиме письмо восстановления не отправляется.',
  );
  String get registerEmailConfirmNotice => _t(
    'Hisob yaratildi. Emaildagi tasdiqlaş havolasini oçing va tizimga kiring.',
    'Аккаунт создан. Откройте ссылку подтверждения в письме и войдите.',
  );
  String get resetSaveFailedError => _t(
    'Parol saqlanmadi. Havolani yoki aloqani tekşirib, qayta urinib köring.',
    'Не удалось сохранить пароль. Проверьте ссылку или сеть и попробуйте снова.',
  );
  String get signOutFailedError => _t(
    'Sessiyani yakunlab bölmadi. Qayta urinib köring.',
    'Не удалось завершить сессию. Попробуйте ещё раз.',
  );

  // --- Dashboard & Courses ---
  String get switchSubjectTooltip => _t('Fanni almaştiriş', 'Сменить предмет');
  String get profileLoadFailed => _t(
    'Profil ma’lumotlarini yuklab bölmadi.',
    'Не удалось загрузить данные профиля.',
  );
  String get chooseCoursePrompt => _t(
    'Davom etiş uçun mavjud fanlardan birini tanlang.',
    'Выберите один из доступных предметов, чтобы продолжить.',
  );
  String get searchCoursesHint => _t(
    'Dars, kurs yoki mavzu qidiring...',
    'Поиск курса, урока или темы...',
  );
  String streakDays(int days) => _t('$days kun', '$days дн.');
  String get defaultLearnerName => _t('Öquvçi', 'Ученик');
  String heroGreeting(String name) =>
      _t('Assalomu alaykum, $name!', 'Здравствуйте, $name!');
  String get heroContinuePrompt =>
      _t('Bugun nimani davom ettiraman?', 'Что продолжить сегодня?');
  String get heroFocusNeedsPlan =>
      _t('Öquv rejangizni tanlang', 'Выберите план обучения');
  String get heroSubtitleNeedsPlan => _t(
    'Fan va darajani tanlang. Keyingi darsni BilimYöl körsatadi.',
    'Выберите предмет и уровень — BilimYöl подскажет следующий урок.',
  );
  String get heroSubtitleStarter => _t(
    'Boşlanğiç darslar: tuşuntiriş va işlangan misoldan boşlang.',
    'Стартовые уроки: начните с объяснения и разобранного примера.',
  );
  String get heroSubtitleDefault => _t(
    'Bugungi maqsadni bajaring va bilimingizni yangi bosqiçga olib çiqing.',
    'Выполните цель дня и выведите знания на новый уровень.',
  );
  String get openFirstLesson =>
      _t('Birinçi darsni oçiş', 'Открыть первый урок');
  String get openRoadmap => _t('Ta’lim yölini oçiş', 'Открыть путь обучения');
  String lessonsRatio(int done, int total) =>
      _t('$done/$total dars', '$done/$total ур.');
  String dailyMinutesLabel(int minutes) =>
      _t('Kunlik $minutes daq', '$minutes мин/день');
  String get streakSubtitle => _t('ketma-ket', 'подряд');
  String completedCountLabel(int count) => _t('$count dars', '$count ур.');
  String get completedSubtitle => _t('tugallandi', 'завершено');
  String get progressLabel => _t('rivojlaniş', 'прогресс');
  String get yolchiTutorHeader => _t('Yölçi AI yordamçisi', 'Помощник Yölçi AI');
  String get yolchiTutorDesc => _t(
    'Har qanday mavzuda savol bering, tuşuntiriş oling va maşq qiling.',
    'Задавайте вопросы по любой теме, получайте объяснения и практику.',
  );
  String get openChat => _t('Suhbatni oçiş', 'Открыть чат');
  String get startLevelBtn => _t('Boşlaş darajasi', 'Уровень старта');
  String get optionalDiagnosticBtn =>
      _t('Ixtiyoriy diagnostika', 'Диагностика');
  String get lessonLoadFailed => _t(
    'Dars yuklanmadi. Qayta urinib köring.',
    'Урок не загрузился. Попробуйте снова.',
  );
  String get continueLearning => _t('Davom etiş', 'Продолжить');
  String get todayGoal => _t('Bugungi maqsad', 'Цель на сегодня');
  String get myCourses => _t('Mening kurslarim', 'Мои курсы');
  String get tabActive => _t('Aktiv', 'Активные');
  String get tabRecommended => _t('Tavsiya', 'Рекомендуем');
  String get tabAll => _t('Barçasi', 'Все');
  String get chooseSubject => _t('Fan tanlaş', 'Выбрать предмет');
  String get noMatchingCourses => _t(
    'Bu bölimda mos kurs topilmadi',
    'В этом разделе подходящих курсов не найдено',
  );

  // --- Onboarding & Placement ---
  String get onboardingQuestion =>
      _t('Qayerdan boşlamoqçisiz?', 'С чего хотите начать?');
  String get startFromZero =>
      _t('Noldan boşlayman', 'Начну с нуля');
  String get startFirstLesson =>
      _t('Birinçi darsni boşlaş', 'Начать первый урок');
  String get diagnosticTitle => _t('Diagnostika', 'Диагностика');
  String get diagnosticResultTitle =>
      _t('Diagnostika natijasi', 'Результат диагностики');
  String get placementFastTapNotice => _t(
    'Iltimos, keyingi javobni yuborişdan oldin bir lahza kuting.',
    'Пожалуйста, подождите секунду перед отправкой следующего ответа.',
  );
  String get nextQuestion => _t('Keyingi Savol', 'Следующий вопрос');
  String get viewResults =>
      _t('Natijalarni Köriş', 'Посмотреть результаты');

  // --- Knowledge Map & Roadmap ---
  String get knowledgeMapTitle =>
      _t('Bilim xaritasi', 'Карта знаний');
  String get startNode => _t('Boşlaş', 'Начать');
  String get practiceNode => _t('Maşq qiliş', 'Практиковаться');
  String get repeatNode => _t('Takrorlaş', 'Повторить');
  String get lockedNode => _t('Bloklangan', 'Заблокировано');

  // --- Lesson & Sheets ---
  String get lessonLabel => _t('Dars', 'Урок');
  String get nextStep => _t('Keyingi qadam', 'Следующий шаг');
  String get checkAnswer => _t('TEKŞIRIŞ', 'Проверить');
  String get askYolchiTooltip =>
      _t('Yölçidan söraş', 'Спросить Yölçi');
  String get dictionaryTooltip => _t('Söz luğati', 'Словарь');
  String get speakerDefault => _t('Ma’ruzachi', 'Диктор');
  String get audioPlayerLabel =>
      _t('Audio simulyatsiya', 'Аудиосимулятор');
  String get backToRoadmapTooltip =>
      _t('Ta’lim yöliga qaytiş', 'Вернуться к пути обучения');
  String get lessonDataMissing =>
      _t('Dars ma’lumotlari yuklanmadi', 'Данные урока не загрузились');
  String get returnToRoadmap =>
      _t('Yöl xaritasiga qaytiş', 'Вернуться к карте пути');
  String get crossCourseLessonError => _t(
    'Uşbu dars boşqa fanga tegişli va körsatilmaydi.\nIltimos, yönalişingizni tanlab qayta urinib köring.',
    'Этот урок относится к другому предмету и не может быть показан.\nПожалуйста, выберите ваш предмет и попробуйте снова.',
  );
  String stepOf(int current, int total) =>
      _t('Qadam $current / $total', 'Шаг $current / $total');
  String get lessonFinish => _t('Yakunlaş', 'Завершить');
  String get interactiveQuestionBadge =>
      _t('Interaktiv Savol', 'Интерактивный вопрос');
  String get correctOptionBadge => _t('töğri javob', 'верный ответ');
  String get yourChoiceBadge => _t('siz tanladingiz', 'ваш выбор');
  String get selectedBadge => _t('tanlangan ✓', 'выбрано ✓');
  String youSelected(String option) =>
      _t('Siz tanladingiz: $option', 'Вы выбрали: $option');
  String correctAnswerIs(String option) =>
      _t('Töğri javob: $option', 'Правильный ответ: $option');
  String get correctAnswerToast => _t('Töğri javob!', 'Правильный ответ!');
  String get lessonCompletedToast => _t(
    'Töğri javob! Dars muvaffaqiyatli yakunlandi.',
    'Правильный ответ! Урок успешно завершён.',
  );
  String get nextStepHint => _t('Endi nima qiliş kerak?', 'Что делать дальше?');
  String get nextStepWrongGuidance => _t(
    'Xatoni Yölçi AI bilan tahlil qiling yoki mavzuni mustahkamlang.',
    'Разберите ошибку с Yölçi AI или закрепите тему.',
  );
  String get yolchiAnalysisBtn => _t('Yölçi AI tahlili', 'Разбор Yölçi AI');
  String get reinforceTopicBtn =>
      _t('Mavzuni mustahkamlaş', 'Закрепить тему');
  String get interactiveGraphTitle => _t(
    'Interaktiv Grafik: f(x) = 2x + 3',
    'Интерактивный график: f(x) = 2x + 3',
  );
  String get yolchiMistakeAnalysisTitle =>
      _t('Yölçi bilan xato tahlili', 'Разбор ошибки с Yölçi');
  String get yolchiAnalyzingLabel => _t(
    'Yölçi javobni tahlil qilmoqda',
    'Yölçi анализирует ответ',
  );
  String get yolchiReadyExplanation =>
      _t('Tayyor izoh', 'Готовое объяснение');
  String get yolchiAiExplanation => _t('Yölçi AI izohi', 'Объяснение Yölçi AI');
  String get yolchiExplanationLoadFailed => _t(
    'Yölçi izohini yuklab bölmadi.',
    'Не удалось загрузить объяснение Yölçi.',
  );
  String get backToLesson => _t('Darsga qaytiş', 'Вернуться к уроку');
  String get dictionaryTitle =>
      _t('Inglizça söz luğati', 'Словарь английских слов');
  String get dictionaryCloseTooltip => _t('Luğatni yopiş', 'Закрыть словарь');
  String get dictionarySubtitle => _t(
    'Inglizça ta’rif, talaffuz va misolni toping.',
    'Найдите определение, произношение и пример на английском.',
  );
  String get dictionaryWordLabel => _t('Inglizça söz', 'Английское слово');
  String get dictionaryWordHint => 'hello';
  String get dictionarySearchAction => _t('Sözni izlaş', 'Найти слово');
  String get dictionarySearching => _t('Izlanmoqda…', 'Поиск…');
  String get dictionaryInvalidWord => _t(
    'Bitta inglizça söz kiriting. Masalan: hello.',
    'Введите одно английское слово. Например: hello.',
  );
  String get dictionaryNotFound => _t(
    'Bu söz uçun ta’rif topilmadi.',
    'Определение для этого слова не найдено.',
  );
  String get dictionaryServerError => _t(
    'Luğat hozir javob bermayapti. Qayta urinib köring.',
    'Словарь временно не отвечает. Попробуйте ещё раз.',
  );
  String get dictionaryNetworkError => _t(
    'Luğatga ulanib bölmadi. Internetni tekşirib, qayta urinib köring.',
    'Не удалось подключиться к словарю. Проверьте сеть и попробуйте снова.',
  );
  String get dictionarySourceFooter =>
      _t('Manba: Free Dictionary API', 'Источник: Free Dictionary API');
  String get reinforcementBadge =>
      _t('Mustahkamlaş Maşqi', 'Задание на закрепление');
  String get xpRewardBadge => _t('XP mukofoti', 'Награда XP');
  String get reinforcementSubtitle => _t(
    'Bilimingizni amalda sinab köring',
    'Проверьте знания на практике',
  );
  String get checkAnswerBtn => _t('Javobni Tekşiriş', 'Проверить ответ');
  String get reinforcementSaveFailed => _t(
    'Natijani saqlab bölmadi. Internetni tekşirib, qayta urinib köring.',
    'Не удалось сохранить результат. Проверьте сеть и попробуйте снова.',
  );
  String get reinforcementLoadFailed => _t(
    'Natijani olişning imkoni bölmadi. Qayta urinib köring.',
    'Не удалось получить результат. Попробуйте ещё раз.',
  );
  String get greatResultTitle => _t('Ajoyib Natija!', 'Отличный результат!');
  String get reinforcementSuccessBody => _t(
    'Tuşunça muvaffaqiyatli özlaştirildi va bilim bali oşdi.',
    'Тема успешно усвоена, а уровень знания повысился.',
  );
  String get oldScoreLabel => _t('Eski Bal', 'Было');
  String get newScoreLabel => _t('Yangi Bal', 'Стало');
  String xpAddedBadge(int xp) => _t(
    '+$xp XP mukofoti qöşildi!',
    '+$xp XP начислено!',
  );
  String get nextTopicUnlockedMsg => _t(
    'Navbatdagi mavzu yöl xaritasida blokdan oçildi!',
    'Следующая тема открыта на вашем пути обучения!',
  );
  String get goToDashboardBtn => _t('Daşboardga Ötiş', 'На главную');
  String pageNotFound(String uri) =>
      _t('Sahifa topilmadi: $uri', 'Страница не найдена: $uri');
  String get goHomeBtn => _t('Boş sahifaga qaytiş', 'На главную');

  // --- AI Tutor & Progress ---
  String get aiTutorSubtitle =>
      _t('Şaxsiy öquv yordamçingiz', 'Ваш персональный AI-наставник');
  String get progressOverview =>
      _t('Öquv körsatkiçlari', 'Показатели обучения');

  // --- Profile & Settings ---
  String get myProfile => _t('Profilim', 'Мой профиль');
  String get learningSettings =>
      _t('Öquv sozlamalari', 'Настройки обучения');
  String get languageLabel => _t('Ilova tili', 'Язык приложения');
  String get languageUz => 'Özbekça';
  String get languageRu => 'Русский';
  String get themeLabel => _t('Mavzu', 'Тема');
  String get themeSystem => _t('Tizim', 'Системная');
  String get themeLight => _t('Yoruğ', 'Светлая');
  String get themeDark => _t('Qoronği', 'Тёмная');
  String get logout => _t('Hisobdan çiqiş', 'Выйти');

  String get profileBadgeDemo => _t('Namuna', 'Демо');
  String get profileBadgeStudent => _t('Öquvçi', 'Ученик');
  String get profileDemoAccount => _t('Namuna hisobi', 'Демо-аккаунт');
  String get profileNoEmail =>
      _t('Elektron poçta körsatilmagan', 'Email не указан');
  String get statXpLabel => _t('Tajriba', 'Опыт');
  String get statStreakLabel => _t('Ketma-ket', 'Подряд');
  String get statSubjectLabel => _t('Joriy fan', 'Текущий предмет');
  String get editNameAction => _t('Ismni tahrirlaş', 'Изменить имя');
  String get editNameDialogTitle => _t('Ismni tahrirlaş', 'Изменить имя');
  String get editNameFieldLabel => _t('Ismingiz', 'Ваше имя');
  String get editNameEmptyError =>
      _t('Iltimos, ismingizni kiriting.', 'Пожалуйста, введите имя.');
  String get editNameSaved => _t('Ism yangilandi.', 'Имя обновлено.');
  String get editNameFailed => _t(
    'Ismni saqlab bölmadi. Qayta urinib köring.',
    'Не удалось сохранить имя. Попробуйте ещё раз.',
  );
  String get switchSubjectAction => _t('Fanni özgartiriş', 'Сменить предмет');
  String get adjustStartLevelAction =>
      _t('Boşlaş darajasini sozlaş', 'Настроить уровень старта');
  String get demoResetAction =>
      _t('Namuna natijalarini tiklaş', 'Сбросить демо-результаты');

  // --- Catalog (/courses) ---
  String get coursesCatalogPill => _t('Fanlar katalogi', 'Каталог предметов');
  String get coursesHeading => _t('Örganmoqçi bölgan', 'Выберите направление');
  String get coursesHighlight => _t('faningizni tanlang', 'для обучения');
  String get coursesSubtitle => _t(
    'Yönalişni tanlang — BilimYöl sizga mos boşlanğiç dars yoki diagnostikani oçadi.',
    'Выберите предмет — BilimYöl откроет стартовый урок или диагностику под ваш уровень.',
  );
  String subjectBadgeLabel(SubjectType subject) => switch (subject) {
    SubjectType.mathematics => _t('Aniq fanlar', 'Точные науки'),
    SubjectType.english => _t('Xorijiy til', 'Иностранный язык'),
    SubjectType.it => _t('Dasturlaş', 'Программирование'),
    SubjectType.logic => _t('Tafakkur', 'Логика и мышление'),
  };
  String localizedCourseTitle(Course course) {
    if (!isRu) return course.title;
    return switch (course.id) {
      'course_math_01' => 'Математика',
      'course_eng_01' => 'Английский язык',
      'course_it' => 'IT и программирование',
      'course_logic' => 'Логика',
      _ => course.title,
    };
  }
  String localizedCourseDescription(Course course) {
    if (!isRu) return course.description;
    return switch (course.id) {
      'course_math_01' =>
        'Алгебра, уравнения, функции и логическое мышление на понятных примерах.',
      'course_eng_01' =>
        'Грамматика, словарный запас и разговорная практика для повседневного общения.',
      'course_it' =>
        'Алгоритмы, структуры данных, основы кода и решение практических задач.',
      'course_logic' =>
        'Закономерности, рассуждения, дедукция и тренировка аналитического мышления.',
      _ => course.description,
    };
  }
  String get selectedBadgeLabel => _t('Tanlangan', 'Выбран');
  String lessonsXpMeta(int done, int total, int xp) =>
      _t('$done / $total dars · +$xp XP', '$done / $total ур. · +$xp XP');
  String get coursesEmptyTitle =>
      _t('Hozirça fanlar topilmadi.', 'Предметы пока не найдены.');
  String get courseLoadError => _t(
    'Kurslarni yuklab bölmadi. Qayta urinib köring.',
    'Не удалось загрузить предметы. Попробуйте ещё раз.',
  );
  String get courseSelectError => _t(
    'Kursni tanlab bölmadi. Qayta urinib köring.',
    'Не удалось выбрать предмет. Попробуйте ещё раз.',
  );

  // --- Onboarding (/onboarding) ---
  String get studyPlanTitle => _t('Örganiş rejasi', 'План обучения');
  String get onboardingSubtitle => _t(
    'Darajangiz va kunlik vaqtingizni belgilang — BilimYöl darslarni moslaştiradi.',
    'Укажите уровень и ежедневное время — BilimYöl подберёт темп обучения.',
  );
  String get levelBeginnerDesc => _t(
    'Asosiy tuşunçalar va misollar bilan bosqiçma-bosqiç kiriş.',
    'Пошаговое введение в базовые понятия с наглядными примерами.',
  );
  String get levelIntermediateTitle =>
      _t('Asoslarini bilaman', 'Знаю основы');
  String get levelIntermediateDesc => _t(
    'Qisqa diagnostika orqali bilimingizdagi böşliqlarni aniqlaymiz.',
    'Короткая диагностика выявит пробелы и подскажет нужные темы.',
  );
  String get levelAdvancedTitle =>
      _t('Çuqurroq maşq qilmoqçiman', 'Хочу углублённую практику');
  String get levelAdvancedDesc => _t(
    'Yuqori darajali masalalar va tezlaştirilgan takrorlaş rejimi.',
    'Задачи повышенной сложности и ускоренное повторение.',
  );
  String get levelPillBeginner => _t('Boşlanğiç', 'Начальный');
  String get levelPillIntermediate => _t('Örta', 'Средний');
  String get levelPillAdvanced => _t('Yuqori', 'Продвинутый');
  String get entryStart => _t("Birinçi qadamingizni tanlang", "С чего начнём?");
  String get entryIntro => _t("Avval qanday boşlaşni, söng darslarda nimaga köproq vaqt ajratişni tanlang.", "Выберите первый шаг и решите, чему уделять больше времени на занятиях.");
  String get entryGuided => _t("Dars bilan boşlaş", "Начать с урока");
  String get entryGuidedHint => _t("Misol va maşqlar bilan ketma-ket örganing.", "Разбирайте примеры и выполняйте задания по порядку.");
  String get entryMap => _t("Mavzuni özim tanlayman", "Выбрать тему");
  String get entryMapHint => _t("Kurs xaritasidan oçiq mavzuni tanlang.", "Откройте карту курса и выберите доступную тему.");
  String get entryDiagnostic => _t("Bilimimni tekşiraman", "Проверить знания");
  String get entryDiagnosticHint => _t("Qisqa savollarga javob berib, mos mavzuni toping.", "Ответьте на вопросы, чтобы подобрать подходящую тему.");
  String get entryTestFirst => _t("Avval bilimni tekşiramiz", "Сначала проверим знания");
  String get entryTestExplain => _t("Javoblaringizdan söng qaysi mavzudan davom etiş körinadi. Darslar rejasi natijaga qarab yangilanadi.", "После ответов вы увидите, с какой темы продолжить. План уроков обновится по результатам.");
  String get entryTestAction => _t("Tekşiruvni boşlaş", "Начать проверку");
  String get sharedPlanTiming => _t('Maqsad va kunlik vaqt barça fanlar uçun saqlanadi.', 'Цель и время в день сохраняются для всех предметов.');
  String get entryGoal => _t("Rejada nimaga urğu beraylik?", "На чём сделать акцент?");
  String get entryMastery => _t("Mavzuni tuşuniş", "Разобраться в теме");
  String get entryExamPrep => _t("Nazoratga tayyorlaniş", "Подготовиться к проверке");
  String get entrySkillsBoost => _t("Qiyin joylarni maşq qiliş", "Отработать трудное");
  String get entryLogic => _t("Mulohaza, dalil va xulosani kursdagi tartibda örganasiz.", "Разберёте высказывания, аргументы и выводы по порядку.");
  String get entryMathematics => _t("Misollar orqali amallarni örganişdan masala yeçişga ötasiz.", "От примеров на вычисления перейдёте к решению задач.");
  String get entryEnglish => _t("Söz va iboralarni örganib, ularni gaplarda qöllaysiz.", "Изучите слова и выражения и примените их в предложениях.");
  String get entryIt => _t("Kod misollarini tuşunib, amaliy topşiriqlarga ötasiz.", "Разберёте примеры кода и перейдёте к практическим заданиям.");
  String get entryExamHint => _t("Oçiq nazorat darsi bölsa, reja uni oldinroq körsatadi.", "Если доступна проверочная работа, она появится в плане раньше.");
  String get entryPracticeHint => _t("Natijalaringiz qiyin mavzuni körsatsa, unga oid maşqlar oldinga ötadi.", "Когда результаты покажут трудную тему, задания по ней появятся раньше.");
  String get goalLabel => _t('Maqsad', 'Цель');
  String get goalMastery => _t('Mavzularni mustahkamlaş', 'Закрепить темы');
  String get goalExamPrep => _t('Imtihonga tayyorgarlik', 'Подготовка к экзамену');
  String get goalSkillsBoost =>
      _t('Könikmalarni oşiriş', 'Развить навыки');
  String get dailyTimeLabel => _t('Kunlik vaqt', 'Время в день');
  String minutesOption(int minutes) => _t('$minutes daqiqa', '$minutes минут');
  String get beginnerTrackNote => _t(
    'Noldan boşlaganingiz uçun avval qisqa tayanç dars oçiladi.',
    'Для старта с нуля сначала откроется короткий базовый урок.',
  );
  String get adaptiveTrackNote => _t(
    'Bilimingizga mos yöl xaritasi tayyor. Xohlasangiz diagnostikadan boşlang.',
    'Персональный путь готов. При желании начните с короткой диагностики.',
  );
  String get starterLessonLoadFailed => _t(
    'Boşlanğiç darsni oçib bölmadi. Qayta urinib köring.',
    'Не удалось открыть стартовый урок. Попробуйте ещё раз.',
  );
  String get planSaveFailed => _t(
    'Öquv rejasini saqlab bölmadi. Qayta urinib köring.',
    'Не удалось сохранить план обучения. Попробуйте ещё раз.',
  );

  // --- Placement (/placement) ---
  String get chooseSubjectFirstPrompt => _t(
    'Diagnostika uçun avval fan tanlang.',
    'Сначала выберите предмет для диагностики.',
  );
  String get quickDemoBtn => _t('Tezkor demo', 'Быстрое демо');
  String questionCounter(int current, int total) =>
      _t('Savol $current / $total', 'Вопрос $current / $total');
  String get diffEasy => _t('Oson', 'Лёгкий');
  String get diffMedium => _t('Örtaça', 'Средний');
  String get diffHard => _t('Qiyin', 'Сложный');
  String get placementConfirmTitle =>
      _t('Javobni tasdiqlang', 'Подтвердите ответ');
  String get placementConfirmBody => _t(
    'Barça diagnostika savollariga javob berdingiz. Natijalar hisoblansinmi?',
    'Вы ответили на все вопросы диагностики. Рассчитать результаты?',
  );
  String get placementConfirmSubmit =>
      _t('Topşiriş', 'Да, завершить');
  String get placementSubmitError => _t(
    'Natijalarni saqlab bölmadi. Qayta urinib köring.',
    'Не удалось сохранить результаты. Попробуйте ещё раз.',
  );
  String get reloadSession =>
      _t('Sessiyani qayta yuklaş', 'Перезагрузить сессию');
  String get diagnosticReadyBadge =>
      _t('Natija tayyor', 'Результат готов');
  String get placementDoneTitle =>
      _t('Diagnostika yakunlandi', 'Диагностика завершена');
  String placementCorrectSummary(int correct, int total) => _t(
    '$correct / $total javob töğri.',
    'Правильных ответов: $correct из $total.',
  );
  String get diagnosticHandoffNote => _t(
    'Bilim xaritangiz va şaxsiy ta’lim yölingiz natijalaringiz asosida yangilandi.',
    'Карта знаний и ваш путь обучения обновлены на основе результатов.',
  );
  String get skillBreakdownTitle =>
      _t('Könikmalar kesimi', 'Разбивка по навыкам');
  String get viewPersonalPath =>
      _t('Şaxsiy yölni köriş', 'Персональный путь обучения');
  String get retakePlacement =>
      _t('Diagnostikani qayta topşiriş', 'Пройти диагностику снова');
  String get answersReviewTitle =>
      _t('Javoblar tahlili', 'Разбор ответов');
  String get answerCorrectTag => _t('Töğri', 'Верно');
  String get answerWrongTag => _t('Xato', 'Ошибка');
  String yourAnswerLine(String answer) =>
      _t('Sizning javobingiz: $answer', 'Ваш ответ: $answer');
  String correctAnswerLine(String answer) =>
      _t('Töğri javob: $answer', 'Правильный ответ: $answer');
  String get calculatingResults =>
      _t('Natijalar hisoblanmoqda...', 'Вычисление результатов...');
  String get buildingKnowledgeMap => _t(
    'Şaxsiy bilim xaritasi va ta’lim yölingiz tuzilmoqda.',
    'Формируем карту знаний и ваш персональный путь.',
  );
  String get preparingQuestions =>
      _t('Savollar tayyorlanmoqda...', 'Подготовка вопросов...');
  String get questionsLoadFailed =>
      _t('Savollarni yuklab bölmadi.', 'Не удалось загрузить вопросы.');
  String get questionsLoadingDesc => _t(
    'Moslaşuvçan diagnostika yuklanmoqda.',
    'Загружается адаптивная диагностика.',
  );

  // --- Roadmap & Knowledge Map (/roadmap, /knowledge-map) ---
  String get myRoadmapTitle =>
      _t('Mening ta’lim yölim', 'Мой путь обучения');
  String get roadmapPill => _t('Ta’lim yöli', 'Путь обучения');
  String get roadmapHeading =>
      _t('Şaxsiy öquv', 'Ваш персональный');
  String get roadmapHighlight => _t('xaritangiz', 'путь обучения');
  String get roadmapSubtitle => _t(
    'Har bir bosqiç diagnostika va oxirgi maşqlaringiz asosida moslaşadi.',
    'Каждый этап адаптируется под вашу диагностику и недавние результаты.',
  );
  String get roadmapSummaryTitle =>
      _t('Bosqiçlar bajarilişi', 'Прогресс по этапам');
  String roadmapStepsProgress(int done, int total) =>
      _t('$done / $total bosqiç', '$done / $total эт.');
  String get roadmapLoadError => _t(
    'Ta’lim yölini yuklab bölmadi.',
    'Не удалось загрузить путь обучения.',
  );
  String get roadmapEmptyTitle => _t(
    'Bu fan uçun hozirça bosqiçlar topilmadi.',
    'Для этого предмета этапы пока не найдены.',
  );
  String get optionalTag => _t('Ixtiyoriy', 'Доп.');
  String stageNumLabel(int n) => _t('$n-Bosqiç', 'Этап $n');
  String get statusReviewDue =>
      _t('Takrorlaş vaqti', 'Пора повторить');
  String get statusReinforcement =>
      _t('Qayta maşq kerak', 'Нужна практика');
  String get statusMastered => _t('Özlaştirilgan', 'Освоено');
  String get statusCompleted100 =>
      _t('Bajarildi (100%)', 'Выполнено (100%)');
  String get statusActiveLesson => _t('Faol dars', 'Активный урок');
  String get statusAvailable => _t('Oçiq', 'Открыто');
  String get statusInProgress => _t('Maşq qilinyapti', 'В процессе');
  String get statusPrerequisiteNeeded =>
      _t('Oldingi mavzuni yakunlang', 'Сначала пройдите предыдущую тему');
  String minutesDuration(int m) => _t('$m daqiqa', '$m мин');
  String get overallMastery =>
      _t('Umumiy Özlaştiriş', 'Общее освоение');
  String get knowledgeMapBannerDesc => _t(
    'Diagnostika va darslaringiz asosidagi könikmalar xaritasi.',
    'Карта навыков на основе вашей диагностики и уроков.',
  );
  String get weakLinkBadge =>
      _t('DIQQAT: Zaif Böğin', 'ВНИМАНИЕ: Слабое место');
  String weakSkillPrompt(String name) => _t(
    '$name könikmasini mustahkamlaş tavsiya etiladi.',
    'Рекомендуется укрепить навык «$name».',
  );
  String get weakSkillRoadmapNote => _t(
    'Ta’lim yölingizda uşbu mavzu ustuvor qilib belgilandi.',
    'Эта тема отмечена как приоритетная на вашем пути обучения.',
  );
  String get skillsAnalysisPill =>
      _t('Könikmalar tahlili', 'Анализ навыков');
  String get skillsAnalysisTitle =>
      _t('Mavzular böyiça', 'Уровень освоения');
  String get skillsAnalysisHighlight => _t('özlaştiriş', 'по темам');
  String get adaptiveRoadmapCta =>
      _t('Moslaşuvçan Yöl Xaritasi', 'Персональный путь обучения');
  String get knowledgeMapEmptyPrompt => _t(
    'Könikmalar xaritasini köriş uçun diagnostika yoki darsni boşlang.',
    'Пройдите диагностику или начните урок, чтобы увидеть карту навыков.',
  );
  String masteryLabel(int score) {
    final level = SkillScoringEngine.getMasteryLevel(score);
    return switch (level) {
      MasteryLevel.needsRemediation => _t('Boşlanğiç', 'Начальный'),
      MasteryLevel.developing => _t('Rivojlanmoqda', 'Развивается'),
      MasteryLevel.proficient => _t('Örta', 'Средний'),
      MasteryLevel.mastered => _t('Yuqori', 'Высокий'),
    };
  }

  // --- Progress (/progress) ---
  String get progressScreenTitle => _t('Mening natijalarim', 'Мои результаты');
  String get progressPill => _t('Natijalar tahlili', 'Аналитика результатов');
  String get progressSectionTitle => _t('Ta’lim', 'Показатели');
  String get progressSectionHighlight => _t('körsatkiçlari', 'обучения');
  String get progressSectionFull =>
      _t('Ta’lim körsatkiçlari', 'Показатели обучения');
  String get timeframeWeek => _t('Bu hafta', 'Эта неделя');
  String get timeframeMonth => _t('Bu oy', 'Этот месяц');
  String get statCompletedLessons =>
      _t('Bajarilgan dars', 'Выполненные уроки');
  String get statMastery => _t('Özlaştiriş', 'Освоение');
  String get statStreak => _t('Kun ketma-ket', 'Дней подряд');
  String get statXpTotal => _t('Umumiy ballar', 'Всего баллов');
  String get studyTimeTitle => _t('Öqiş vaqti', 'Время обучения');
  String get studyTimeUnit => _t('Soat / kun', 'Час / день');
  String studyTimeSummary(int days, int totalMinutes) => _t(
    '$days kun · jami $totalMinutes daqiqa',
    '$days дн. · всего $totalMinutes мин',
  );
  String get progressEmptyActivity => _t(
    'Hali öquv faoliyati qayd etilmagan.',
    'Учебная активность пока не зафиксирована.',
  );
  String get progressActivityLoadFailed => _t(
    'Öqiş faoliyatini yuklab bölmadi. Qayta urinib köring.',
    'Не удалось загрузить учебную активность. Попробуйте ещё раз.',
  );
  List<String> get shortWeekdays => isRu
      ? const ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб']
      : const ['Yak', 'Dsh', 'Ssh', 'Çor', 'Pay', 'Jum', 'Şan'];
  String get subjectBreakdownTitle =>
      _t('Mavzular böyiça natija', 'Результаты по предметам');
  String get achievementsTitle =>
      _t('Yutuqlar va nişonlar', 'Достижения и значки');
  String achievementsEarned(int earned, int total) =>
      _t('$earned/$total Olingan', 'Получено $earned/$total');
  String get badgeFirstStepTitle => _t('Birinçi qadam', 'Первый шаг');
  String get badgeFirstStepDesc =>
      _t('Ilk darsni yakunlaş', 'Завершить первый урок');
  String get badge3DayStreakTitle =>
      _t('3 kunlik seriya', 'Серия 3 дня');
  String get badge3DayStreakDesc =>
      _t('3 kun ketma-ket öqiş', 'Заниматься 3 дня подряд');
  String get badgeExpertTitle => _t('Bilimdon', 'Знаток');
  String get badgeExpertDesc =>
      _t('100+ XP töplaş', 'Набрать 100+ XP');
  String get badgeMasterTitle => _t('Ustoz', 'Мастер');
  String get badgeMasterDesc =>
      _t('5 ta darsni tugatiş', 'Пройти 5 уроков');
  String get progressBannerTitleActive =>
      _t('Ajoyib natija!', 'Отличный результат!');
  String get progressBannerTitleIdle =>
      _t('Boşlaşga tayyormisiz?', 'Готовы начать?');
  String progressBannerBodyActive(int lessons, int xp) => _t(
    'Siz allaqaçon $lessons ta dars yakunladingiz va $xp XP töpladingiz.',
    'Вы уже завершили $lessons ур. и набрали $xp XP.',
  );
  String get progressBannerBodyIdle => _t(
    'Birinçi darsni boşlang va kunlik seriyangizni yölga qöying.',
    'Начните первый урок и запустите свою ежедневную серию.',
  );

  // --- Yölçi AI (/ai-tutor) ---
  String get aiTutorWelcomeMessage => _t(
    'Salom, men Yölçi AI! Tuşunmagan joyingizni yozing yoki yana bir misol sörang.',
    'Привет, я Yölçi AI! Напишите, что непонятно, или попросите ещё один пример.',
  );
  String get aiTutorStatusDemo => _t('Namuna rejimi', 'Демо-режим');
  String get aiTutorStatusOnline =>
      _t('Pedagogik yordamçi', 'AI-наставник');
  String get aiTutorStatusOffline =>
      _t('Offline • Qayta urinib köring', 'Офлайн • Попробуйте снова');
  String get aiTutorStatusPrompt => _t('Savolingizni yozing', 'Задайте вопрос');
  List<String> get aiTutorQuickPrompts => isRu
      ? const [
          'Объясни проще',
          'Дай ещё один пример',
          'Дай тренировочный вопрос',
        ]
      : const [
          'Qoidani sodda tuşuntir',
          'Yana bitta misol ber',
          'Maşq savoli ber',
        ];
  String get aiTutorInputHint => _t('Savol yozing...', 'Напишите вопрос...');
  String get aiTutorSendTooltip => _t('Yuboriş', 'Отправить');
  String get aiTutorGenericError => _t(
    'Yölçi AI bilan boğlanişda xatolik yuz berdi. Qayta urinib köring.',
    'Не удалось связаться с Yölçi AI. Попробуйте ещё раз.',
  );
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'uz' || locale.languageCode == 'ru';

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(AppStrings.forCode(locale.languageCode));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
