import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../domain/entities/course.dart';
import '../../domain/entities/skill_score.dart';
import '../../domain/personalization/skill_scoring_engine.dart';

/// Bilingual (`uz` default, `ru` supported) localization catalog for BilimYo‘l.
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
    'Moslashuvchan ta’lim platformasi',
    'Адаптивная образовательная платформа',
  );
  String get navHome => _t('Bosh sahifa', 'Главная');
  String get navRoadmap => _t('Ta’lim yo‘li', 'Путь обучения');
  String get navAiTutor => 'Yo‘lchi AI';
  String get navProgress => _t('Natijalar', 'Результаты');
  String get navProfile => _t('Profil', 'Профиль');

  // --- Common Actions & States ---
  String get back => _t('Orqaga', 'Назад');
  String get retry => _t('Qayta urinish', 'Повторить');
  String get cancel => _t('Bekor qilish', 'Отмена');
  String get save => _t('Saqlash', 'Сохранить');
  String get close => _t('Yopish', 'Закрыть');
  String get loading => _t('Yuklanmoqda...', 'Загрузка...');
  String get errorTitle =>
      _t('Ma’lumotlarni yuklab bo‘lmadi.', 'Не удалось загрузить данные.');
  String get errorSubtitle => _t(
    'Internet aloqasini tekshirib, qayta urinib ko‘ring.',
    'Проверьте подключение к интернету и попробуйте снова.',
  );
  String get demoBanner => _t(
    'Namuna rejimi. Mashg‘ulotni qayta boshlashingiz mumkin.',
    'Демо-режим. Вы можете перезапустить обучение.',
  );
  String get demoReset => _t('Qayta boshlash', 'Сбросить');
  String get demoResetSuccess =>
      _t('Demo muvaffaqiyatli tiklandi.', 'Демо-режим успешно сброшен.');
  String get demoResetFailed => _t(
    'Namuna holatini tiklab bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось сбросить демо-режим. Попробуйте ещё раз.',
  );

  // --- Product Tour (Mening bilim yo‘lim) ---
  String get tourConceptPill =>
      _t('Mening bilim yo‘lim', 'Мой путь к знаниям');
  String tourStepCounter(int current, int total) => '$current / $total';
  String get tourReplayAction =>
      _t('Tanishtiruvni qayta ko‘rish', 'Повторить обзор');
  String get tourThemeToggleTooltip => _t('Mavzuni almashtirish', 'Сменить тему');
  String get tourLanguageToggleTooltip => _t('Tilni almashtirish', 'Сменить язык');
  String get tourNext => _t('Keyingi', 'Далее');
  String get tourSkip => _t('O‘tkazib yuborish', 'Пропустить');
  String get tourFinish => _t('Boshlash', 'Начать');
  String get tourSlide1Title =>
      _t('Nimadan boshlashni biling.', 'Знайте, с чего начать.');
  String get tourSlide1Body => _t(
    'Qisqa diagnostika sizning kuchli tomonlaringiz va bo‘shliqlaringizni aniq ko‘rsatadi.',
    'Короткая диагностика точно определит ваши сильные стороны и пробелы.',
  );
  String get tourSlide1VisualTitle =>
      _t('Diagnostika nuqtani topadi', 'Диагностика находит точку старта');
  String get tourSlide1Chip1 => _t('Algebra • 82%', 'Алгебра • 82%');
  String get tourSlide1Chip2 => _t('Boshlang‘ich nuqta', 'Точка старта');
  String get tourSlide1Chip3 => _t('Funksiyalar', 'Функции');
  String get tourSlide2Title =>
      _t('Sizga mos darsni sinab ko‘ring.', 'Попробуйте урок под ваш уровень.');
  String get tourSlide2Body => _t(
    'Har bir mavzu tushunarli misol, amaliy savol va tezkor izoh bilan beriladi.',
    'Каждая тема включает понятный пример, практику и быстрый разбор.',
  );
  String get tourSlide2InteractiveHint =>
      _t('Haqiqiy darsdan kichik mashq:', 'Мини-задание из реального урока:');
  String tourSlide2MiniLessonTitle(String uzTitle) =>
      isRu ? 'Начинаем со сложения и вычитания' : uzTitle;
  String tourSlide2MiniQuestionText(String uzText) => isRu
      ? 'Если к 4 карандашам добавить ещё 2 карандаша, сколько станет всего?'
      : uzText;
  String get tourSlide2CorrectFeedback =>
      _t('To‘g‘ri! 4 ta va 2 ta qalam = 6.', 'Верно! 4 + 2 = 6.');
  String get tourSlide2WrongFeedback =>
      _t('Yana bir bor urinib ko‘ring — javobni bosing.', 'Попробуйте ещё раз — нажмите ответ.');
  String get tourSlide3Title =>
      _t('O‘sishingizni ko‘rib boring.', 'Отслеживайте свой рост.');
  String get tourSlide3Body => _t(
    'Bilim xaritasi va ta’lim yo‘lingiz har bir darsdan so‘ng avtomatik yangilanadi.',
    'Карта знаний и путь обучения обновляются автоматически после каждого урока.',
  );
  String get tourSlide3MasteredBadge => _t('Bajarildi', 'Пройдено');
  String get tourSlide3NextBadge => _t('Navbatdagi dars', 'Следующий урок');
  String get tourSlide3NextLessonTitle =>
      _t('Chiziqli funksiya: f(x) = 2x + 3', 'Линейная функция: f(x) = 2x + 3');
  String get tourSlide3XpChip => '+25 XP';

  // --- Auth ---
  String get authTagline => _t(
    'AI yordamida shaxsiylashtirilgan ta’lim',
    'Персонализированное обучение с AI',
  );
  String get authHeroHeadline1 => _t('Kelajagingni', 'Создавай будущее');
  String get authHeroHeadline2 => _t('bilim bilan yarat!', 'вместе со знаниями!');
  String get authHeroSubtitle => _t(
    'Shaxsiy ta’lim yo‘lingizni bugun boshlang',
    'Начните персональный путь обучения уже сегодня',
  );
  String get loginTitle => _t('Xush kelibsiz!', 'Добро пожаловать!');
  String get loginSubtitle => _t(
    'Shaxsiy ta’lim yo‘lingizni davom ettirish uchun tizimga kiring',
    'Войдите, чтобы продолжить персональный путь обучения',
  );
  String get emailLabel => _t('Email manzilingiz', 'Ваш email');
  String get emailHint => 'nomingiz@misol.uz';
  String get passwordLabel => _t('Parol', 'Пароль');
  String get passwordPlaceholder => '••••••••';
  String get passwordShowTooltip =>
      _t('Parolni ko‘rsatish', 'Показать пароль');
  String get passwordHideTooltip => _t('Parolni yashirish', 'Скрыть пароль');
  String get orDivider => _t('yoki', 'или');
  String get noAccountQuestion => _t('Hisobingiz yo‘qmi?', 'Нет аккаунта?');
  String get haveAccountQuestion =>
      _t('Hisobingiz bormi?', 'Уже есть аккаунт?');
  String get loginAction => _t('Kirish', 'Войти');
  String get demoEnterAction =>
      _t('Namuna hisobi bilan kirish', 'Войти с демо-аккаунтом');
  String get registerAction => _t('Ro‘yxatdan o‘tish', 'Регистрация');
  String get registerHeading =>
      _t('Yangi hisob yaratish', 'Создать новый аккаунт');
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
  String get createAccountAction => _t('Hisob Yaratish', 'Создать аккаунт');
  String get forgotPassword =>
      _t('Parolni unutdingizmi?', 'Забыли пароль?');
  String get resetPasswordTitle =>
      _t('Parolni tiklash', 'Восстановление пароля');
  String get forgotPasswordHeading =>
      _t('Parolni qayta tiklash', 'Сброс пароля');
  String get forgotPasswordSubtitle => _t(
    'Email manzilingizni kiriting — tiklash havolasini yuboramiz.',
    'Введите ваш email — мы отправим ссылку для восстановления.',
  );
  String get sendResetLinkAction =>
      _t('Tiklash havolasini yuborish', 'Отправить ссылку');
  String get resetLinkSentTitle => _t('Havola yuborildi!', 'Ссылка отправлена!');
  String resetLinkSentBody(String email) => _t(
    '$email manziliga tiklash havolasi yuborildi.',
    'Ссылка для восстановления отправлена на $email.',
  );
  String get backToLoginAction =>
      _t('Kirish sahifasiga qaytish', 'Вернуться ко входу');
  String get newPasswordHeading =>
      _t('Yangi parol belgilang', 'Задайте новый пароль');
  String get passwordUpdatedHeading =>
      _t('Parol yangilandi', 'Пароль обновлён');
  String get newPasswordLabel => _t('Yangi parol', 'Новый пароль');
  String get repeatPasswordLabel =>
      _t('Parolni takrorlang', 'Повторите пароль');
  String get savePasswordAction =>
      _t('Parolni saqlash', 'Сохранить пароль');
  String get emptyLoginFieldsError => _t(
    'Iltimos, email va parolni to‘liq kiriting.',
    'Пожалуйста, введите email и пароль полностью.',
  );
  String get emptyRegisterFieldsError => _t(
    'Iltimos, barcha majburiy maydonlarni to‘ldiring.',
    'Пожалуйста, заполните все обязательные поля.',
  );
  String get invalidEmailError => _t(
    'Email manzilini to‘g‘ri kiriting.',
    'Введите корректный адрес электронной почты.',
  );
  String get shortPassword6Error => _t(
    'Parol kamida 6 ta belgidan iborat bo‘lishi kerak.',
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
    'Hisob xizmatiga ulanib bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось подключиться к сервису авторизации. Попробуйте снова.',
  );
  String get authServiceOfflineShort => _t(
    'Hisob xizmatiga ulanib bo‘lmadi.',
    'Не удалось подключиться к сервису авторизации.',
  );
  String get demoNoRegisterError => _t(
    'Namuna rejimida yangi hisob yaratilmaydi.',
    'В демо-режиме новый аккаунт не создаётся.',
  );
  String get demoNoResetError => _t(
    'Namuna rejimida tiklash xati yuborilmaydi.',
    'В демо-режиме письмо восстановления не отправляется.',
  );
  String get registerEmailConfirmNotice => _t(
    'Hisob yaratildi. Emaildagi tasdiqlash havolasini oching va tizimga kiring.',
    'Аккаунт создан. Откройте ссылку подтверждения в письме и войдите.',
  );
  String get resetSaveFailedError => _t(
    'Parol saqlanmadi. Havolani yoki aloqani tekshirib, qayta urinib ko‘ring.',
    'Не удалось сохранить пароль. Проверьте ссылку или сеть и попробуйте снова.',
  );
  String get signOutFailedError => _t(
    'Sessiyani yakunlab bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось завершить сессию. Попробуйте ещё раз.',
  );

  // --- Dashboard & Courses ---
  String get switchSubjectTooltip => _t('Fanni almashtirish', 'Сменить предмет');
  String get profileLoadFailed => _t(
    'Profil ma’lumotlarini yuklab bo‘lmadi.',
    'Не удалось загрузить данные профиля.',
  );
  String get chooseCoursePrompt => _t(
    'Davom etish uchun mavjud fanlardan birini tanlang.',
    'Выберите один из доступных предметов, чтобы продолжить.',
  );
  String get searchCoursesHint => _t(
    'Dars, kurs yoki mavzu qidiring...',
    'Поиск курса, урока или темы...',
  );
  String streakDays(int days) => _t('$days kun', '$days дн.');
  String get defaultLearnerName => _t('O‘quvchi', 'Ученик');
  String heroGreeting(String name) =>
      _t('Assalomu alaykum, $name!', 'Здравствуйте, $name!');
  String get heroContinuePrompt =>
      _t('Bugun nimani davom ettiraman?', 'Что продолжить сегодня?');
  String get heroFocusNeedsPlan =>
      _t('O‘quv rejangizni tanlang', 'Выберите план обучения');
  String get heroSubtitleNeedsPlan => _t(
    'Fan va darajani tanlang. Keyingi darsni BilimYo‘l ko‘rsatadi.',
    'Выберите предмет и уровень — BilimYo‘l подскажет следующий урок.',
  );
  String get heroSubtitleStarter => _t(
    'Boshlang‘ich darslar: tushuntirish va ishlangan misoldan boshlang.',
    'Стартовые уроки: начните с объяснения и разобранного примера.',
  );
  String get heroSubtitleDefault => _t(
    'Bugungi maqsadni bajaring va bilimingizni yangi bosqichga olib chiqing.',
    'Выполните цель дня и выведите знания на новый уровень.',
  );
  String get openFirstLesson =>
      _t('Birinchi darsni ochish', 'Открыть первый урок');
  String get openRoadmap => _t('Ta’lim yo‘lini ochish', 'Открыть путь обучения');
  String lessonsRatio(int done, int total) =>
      _t('$done/$total dars', '$done/$total ур.');
  String dailyMinutesLabel(int minutes) =>
      _t('Kunlik $minutes daq', '$minutes мин/день');
  String get streakSubtitle => _t('ketma-ket', 'подряд');
  String completedCountLabel(int count) => _t('$count dars', '$count ур.');
  String get completedSubtitle => _t('tugallandi', 'завершено');
  String get progressLabel => _t('rivojlanish', 'прогресс');
  String get yolchiTutorHeader => _t('Yo‘lchi AI yordamchisi', 'Помощник Yo‘lchi AI');
  String get yolchiTutorDesc => _t(
    'Har qanday mavzuda savol bering, tushuntirish oling va mashq qiling.',
    'Задавайте вопросы по любой теме, получайте объяснения и практику.',
  );
  String get openChat => _t('Suhbatni ochish', 'Открыть чат');
  String get startLevelBtn => _t('Boshlash darajasi', 'Уровень старта');
  String get optionalDiagnosticBtn =>
      _t('Ixtiyoriy diagnostika', 'Диагностика');
  String get lessonLoadFailed => _t(
    'Dars yuklanmadi. Qayta urinib ko‘ring.',
    'Урок не загрузился. Попробуйте снова.',
  );
  String get continueLearning => _t('Davom etish', 'Продолжить');
  String get todayGoal => _t('Bugungi maqsad', 'Цель на сегодня');
  String get myCourses => _t('Mening kurslarim', 'Мои курсы');
  String get tabActive => _t('Aktiv', 'Активные');
  String get tabRecommended => _t('Tavsiya', 'Рекомендуем');
  String get tabAll => _t('Barchasi', 'Все');
  String get chooseSubject => _t('Fan tanlash', 'Выбрать предмет');
  String get noMatchingCourses => _t(
    'Bu bo‘limda mos kurs topilmadi',
    'В этом разделе подходящих курсов не найдено',
  );

  // --- Onboarding & Placement ---
  String get onboardingQuestion =>
      _t('Qayerdan boshlamoqchisiz?', 'С чего хотите начать?');
  String get startFromZero =>
      _t('Noldan boshlayman', 'Начну с нуля');
  String get startFirstLesson =>
      _t('Birinchi darsni boshlash', 'Начать первый урок');
  String get diagnosticTitle => _t('Diagnostika', 'Диагностика');
  String get diagnosticResultTitle =>
      _t('Diagnostika natijasi', 'Результат диагностики');
  String get placementFastTapNotice => _t(
    'Iltimos, keyingi javobni yuborishdan oldin bir lahza kuting.',
    'Пожалуйста, подождите секунду перед отправкой следующего ответа.',
  );
  String get nextQuestion => _t('Keyingi Savol', 'Следующий вопрос');
  String get viewResults =>
      _t('Natijalarni Ko‘rish', 'Посмотреть результаты');

  // --- Knowledge Map & Roadmap ---
  String get knowledgeMapTitle =>
      _t('Bilim xaritasi', 'Карта знаний');
  String get startNode => _t('Boshlash', 'Начать');
  String get practiceNode => _t('Mashq qilish', 'Практиковаться');
  String get repeatNode => _t('Takrorlash', 'Повторить');
  String get lockedNode => _t('Bloklangan', 'Заблокировано');

  // --- Lesson & Sheets ---
  String get lessonLabel => _t('Dars', 'Урок');
  String get nextStep => _t('Keyingi qadam', 'Следующий шаг');
  String get checkAnswer => _t('TEKSHIRISH', 'Проверить');
  String get askYolchiTooltip =>
      _t('Yo‘lchidan so‘rash', 'Спросить Yo‘lchi');
  String get dictionaryTooltip => _t('So‘z lug‘ati', 'Словарь');
  String get speakerDefault => _t('Ma’ruzachi', 'Диктор');
  String get audioPlayerLabel =>
      _t('Audio simulyatsiya', 'Аудиосимулятор');
  String get backToRoadmapTooltip =>
      _t('Ta’lim yo‘liga qaytish', 'Вернуться к пути обучения');
  String get lessonDataMissing =>
      _t('Dars ma’lumotlari yuklanmadi', 'Данные урока не загрузились');
  String get returnToRoadmap =>
      _t('Yo‘l xaritasiga qaytish', 'Вернуться к карте пути');
  String get crossCourseLessonError => _t(
    'Ushbu dars boshqa fanga tegishli va ko‘rsatilmaydi.\nIltimos, yo‘nalishingizni tanlab qayta urinib ko‘ring.',
    'Этот урок относится к другому предмету и не может быть показан.\nПожалуйста, выберите ваш предмет и попробуйте снова.',
  );
  String stepOf(int current, int total) =>
      _t('Qadam $current / $total', 'Шаг $current / $total');
  String get lessonFinish => _t('Yakunlash', 'Завершить');
  String get interactiveQuestionBadge =>
      _t('Interaktiv Savol', 'Интерактивный вопрос');
  String get correctOptionBadge => _t('to‘g‘ri javob', 'верный ответ');
  String get yourChoiceBadge => _t('siz tanladingiz', 'ваш выбор');
  String get selectedBadge => _t('tanlangan ✓', 'выбрано ✓');
  String youSelected(String option) =>
      _t('Siz tanladingiz: $option', 'Вы выбрали: $option');
  String correctAnswerIs(String option) =>
      _t('To‘g‘ri javob: $option', 'Правильный ответ: $option');
  String get correctAnswerToast => _t('To‘g‘ri javob!', 'Правильный ответ!');
  String get lessonCompletedToast => _t(
    'To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.',
    'Правильный ответ! Урок успешно завершён.',
  );
  String get nextStepHint => _t('Endi nima qilish kerak?', 'Что делать дальше?');
  String get nextStepWrongGuidance => _t(
    'Xatoni Yo‘lchi AI bilan tahlil qiling yoki mavzuni mustahkamlang.',
    'Разберите ошибку с Yo‘lchi AI или закрепите тему.',
  );
  String get yolchiAnalysisBtn => _t('Yo‘lchi AI tahlili', 'Разбор Yo‘lchi AI');
  String get reinforceTopicBtn =>
      _t('Mavzuni mustahkamlash', 'Закрепить тему');
  String get interactiveGraphTitle => _t(
    'Interaktiv Grafik: f(x) = 2x + 3',
    'Интерактивный график: f(x) = 2x + 3',
  );
  String get yolchiMistakeAnalysisTitle =>
      _t('Yo‘lchi bilan xato tahlili', 'Разбор ошибки с Yo‘lchi');
  String get yolchiAnalyzingLabel => _t(
    'Yo‘lchi javobni tahlil qilmoqda',
    'Yo‘lchi анализирует ответ',
  );
  String get yolchiReadyExplanation =>
      _t('Tayyor izoh', 'Готовое объяснение');
  String get yolchiAiExplanation => _t('Yo‘lchi AI izohi', 'Объяснение Yo‘lchi AI');
  String get yolchiExplanationLoadFailed => _t(
    'Yo‘lchi izohini yuklab bo‘lmadi.',
    'Не удалось загрузить объяснение Yo‘lchi.',
  );
  String get backToLesson => _t('Darsga qaytish', 'Вернуться к уроку');
  String get dictionaryTitle =>
      _t('Inglizcha so‘z lug‘ati', 'Словарь английских слов');
  String get dictionaryCloseTooltip => _t('Lug‘atni yopish', 'Закрыть словарь');
  String get dictionarySubtitle => _t(
    'Inglizcha ta’rif, talaffuz va misolni toping.',
    'Найдите определение, произношение и пример на английском.',
  );
  String get dictionaryWordLabel => _t('Inglizcha so‘z', 'Английское слово');
  String get dictionaryWordHint => 'hello';
  String get dictionarySearchAction => _t('So‘zni izlash', 'Найти слово');
  String get dictionarySearching => _t('Izlanmoqda…', 'Поиск…');
  String get dictionaryInvalidWord => _t(
    'Bitta inglizcha so‘z kiriting. Masalan: hello.',
    'Введите одно английское слово. Например: hello.',
  );
  String get dictionaryNotFound => _t(
    'Bu so‘z uchun ta’rif topilmadi.',
    'Определение для этого слова не найдено.',
  );
  String get dictionaryServerError => _t(
    'Lug‘at hozir javob bermayapti. Qayta urinib ko‘ring.',
    'Словарь временно не отвечает. Попробуйте ещё раз.',
  );
  String get dictionaryNetworkError => _t(
    'Lug‘atga ulanib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',
    'Не удалось подключиться к словарю. Проверьте сеть и попробуйте снова.',
  );
  String get dictionarySourceFooter =>
      _t('Manba: Free Dictionary API', 'Источник: Free Dictionary API');
  String get reinforcementBadge =>
      _t('Mustahkamlash Mashqi', 'Задание на закрепление');
  String get xpRewardBadge => _t('XP mukofoti', 'Награда XP');
  String get reinforcementSubtitle => _t(
    'Bilimingizni amalda sinab ko‘ring',
    'Проверьте знания на практике',
  );
  String get checkAnswerBtn => _t('Javobni Tekshirish', 'Проверить ответ');
  String get reinforcementSaveFailed => _t(
    'Natijani saqlab bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',
    'Не удалось сохранить результат. Проверьте сеть и попробуйте снова.',
  );
  String get reinforcementLoadFailed => _t(
    'Natijani olishning imkoni bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось получить результат. Попробуйте ещё раз.',
  );
  String get greatResultTitle => _t('Ajoyib Natija!', 'Отличный результат!');
  String get reinforcementSuccessBody => _t(
    'Tushuncha muvaffaqiyatli o‘zlashtirildi va bilim bali oshdi.',
    'Тема успешно усвоена, а уровень знания повысился.',
  );
  String get oldScoreLabel => _t('Eski Bal', 'Было');
  String get newScoreLabel => _t('Yangi Bal', 'Стало');
  String xpAddedBadge(int xp) => _t(
    '+$xp XP mukofoti qo‘shildi!',
    '+$xp XP начислено!',
  );
  String get nextTopicUnlockedMsg => _t(
    'Navbatdagi mavzu yo‘l xaritasida blokdan ochildi!',
    'Следующая тема открыта на вашем пути обучения!',
  );
  String get goToDashboardBtn => _t('Dashboardga O‘tish', 'На главную');
  String pageNotFound(String uri) =>
      _t('Sahifa topilmadi: $uri', 'Страница не найдена: $uri');
  String get goHomeBtn => _t('Bosh sahifaga qaytish', 'На главную');

  // --- AI Tutor & Progress ---
  String get aiTutorSubtitle =>
      _t('Shaxsiy o‘quv yordamchingiz', 'Ваш персональный AI-наставник');
  String get progressOverview =>
      _t('O‘quv ko‘rsatkichlari', 'Показатели обучения');

  // --- Profile & Settings ---
  String get myProfile => _t('Profilim', 'Мой профиль');
  String get learningSettings =>
      _t('O‘quv sozlamalari', 'Настройки обучения');
  String get languageLabel => _t('Ilova tili', 'Язык приложения');
  String get languageUz => 'O‘zbekcha';
  String get languageRu => 'Русский';
  String get themeLabel => _t('Mavzu', 'Тема');
  String get themeSystem => _t('Tizim', 'Системная');
  String get themeLight => _t('Yorug‘', 'Светлая');
  String get themeDark => _t('Qorong‘i', 'Тёмная');
  String get logout => _t('Hisobdan chiqish', 'Выйти');

  String get profileBadgeDemo => _t('Namuna', 'Демо');
  String get profileBadgeStudent => _t('O‘quvchi', 'Ученик');
  String get profileDemoAccount => _t('Namuna hisobi', 'Демо-аккаунт');
  String get profileNoEmail =>
      _t('Elektron pochta ko‘rsatilmagan', 'Email не указан');
  String get statXpLabel => _t('Tajriba', 'Опыт');
  String get statStreakLabel => _t('Ketma-ket', 'Подряд');
  String get statSubjectLabel => _t('Joriy fan', 'Текущий предмет');
  String get editNameAction => _t('Ismni tahrirlash', 'Изменить имя');
  String get editNameDialogTitle => _t('Ismni tahrirlash', 'Изменить имя');
  String get editNameFieldLabel => _t('Ismingiz', 'Ваше имя');
  String get editNameEmptyError =>
      _t('Iltimos, ismingizni kiriting.', 'Пожалуйста, введите имя.');
  String get editNameSaved => _t('Ism yangilandi.', 'Имя обновлено.');
  String get editNameFailed => _t(
    'Ismni saqlab bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось сохранить имя. Попробуйте ещё раз.',
  );
  String get switchSubjectAction => _t('Fanni o‘zgartirish', 'Сменить предмет');
  String get adjustStartLevelAction =>
      _t('Boshlash darajasini sozlash', 'Настроить уровень старта');
  String get demoResetAction =>
      _t('Namuna natijalarini tiklash', 'Сбросить демо-результаты');

  // --- Catalog (/courses) ---
  String get coursesCatalogPill => _t('Fanlar katalogi', 'Каталог предметов');
  String get coursesHeading => _t('O‘rganmoqchi bo‘lgan', 'Выберите направление');
  String get coursesHighlight => _t('faningizni tanlang', 'для обучения');
  String get coursesSubtitle => _t(
    'Yo‘nalishni tanlang — BilimYo‘l sizga mos boshlang‘ich dars yoki diagnostikani ochadi.',
    'Выберите предмет — BilimYo‘l откроет стартовый урок или диагностику под ваш уровень.',
  );
  String subjectBadgeLabel(SubjectType subject) => switch (subject) {
    SubjectType.mathematics => _t('Aniq fanlar', 'Точные науки'),
    SubjectType.english => _t('Xorijiy til', 'Иностранный язык'),
    SubjectType.it => _t('Dasturlash', 'Программирование'),
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
      _t('Hozircha fanlar topilmadi.', 'Предметы пока не найдены.');
  String get courseLoadError => _t(
    'Kurslarni yuklab bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось загрузить предметы. Попробуйте ещё раз.',
  );
  String get courseSelectError => _t(
    'Kursni tanlab bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось выбрать предмет. Попробуйте ещё раз.',
  );

  // --- Onboarding (/onboarding) ---
  String get studyPlanTitle => _t('O‘rganish rejasi', 'План обучения');
  String get onboardingSubtitle => _t(
    'Darajangiz va kunlik vaqtingizni belgilang — BilimYo‘l darslarni moslashtiradi.',
    'Укажите уровень и ежедневное время — BilimYo‘l подберёт темп обучения.',
  );
  String get levelBeginnerDesc => _t(
    'Asosiy tushunchalar va misollar bilan bosqichma-bosqich kirish.',
    'Пошаговое введение в базовые понятия с наглядными примерами.',
  );
  String get levelIntermediateTitle =>
      _t('Asoslarini bilaman', 'Знаю основы');
  String get levelIntermediateDesc => _t(
    'Qisqa diagnostika orqali bilimingizdagi bo‘shliqlarni aniqlaymiz.',
    'Короткая диагностика выявит пробелы и подскажет нужные темы.',
  );
  String get levelAdvancedTitle =>
      _t('Chuqurroq mashq qilmoqchiman', 'Хочу углублённую практику');
  String get levelAdvancedDesc => _t(
    'Yuqori darajali masalalar va tezlashtirilgan takrorlash rejimi.',
    'Задачи повышенной сложности и ускоренное повторение.',
  );
  String get levelPillBeginner => _t('Boshlang‘ich', 'Начальный');
  String get levelPillIntermediate => _t('O‘rta', 'Средний');
  String get levelPillAdvanced => _t('Yuqori', 'Продвинутый');
  String get goalLabel => _t('Maqsad', 'Цель');
  String get goalMastery => _t('Mavzularni mustahkamlash', 'Закрепить темы');
  String get goalExamPrep => _t('Imtihonga tayyorgarlik', 'Подготовка к экзамену');
  String get goalSkillsBoost =>
      _t('Ko‘nikmalarni oshirish', 'Развить навыки');
  String get dailyTimeLabel => _t('Kunlik vaqt', 'Время в день');
  String minutesOption(int minutes) => _t('$minutes daqiqa', '$minutes минут');
  String get beginnerTrackNote => _t(
    'Noldan boshlaganingiz uchun avval qisqa tayanch dars ochiladi.',
    'Для старта с нуля сначала откроется короткий базовый урок.',
  );
  String get adaptiveTrackNote => _t(
    'Bilimingizga mos yo‘l xaritasi tayyor. Xohlasangiz diagnostikadan boshlang.',
    'Персональный путь готов. При желании начните с короткой диагностики.',
  );
  String get starterLessonLoadFailed => _t(
    'Boshlang‘ich darsni ochib bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось открыть стартовый урок. Попробуйте ещё раз.',
  );
  String get planSaveFailed => _t(
    'O‘quv rejasini saqlab bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось сохранить план обучения. Попробуйте ещё раз.',
  );

  // --- Placement (/placement) ---
  String get chooseSubjectFirstPrompt => _t(
    'Diagnostika uchun avval fan tanlang.',
    'Сначала выберите предмет для диагностики.',
  );
  String get quickDemoBtn => _t('Tezkor demo', 'Быстрое демо');
  String questionCounter(int current, int total) =>
      _t('Savol $current / $total', 'Вопрос $current / $total');
  String get diffEasy => _t('Oson', 'Лёгкий');
  String get diffMedium => _t('O‘rtacha', 'Средний');
  String get diffHard => _t('Qiyin', 'Сложный');
  String get placementConfirmTitle =>
      _t('Javobni tasdiqlang', 'Подтвердите ответ');
  String get placementConfirmBody => _t(
    'Barcha diagnostika savollariga javob berdingiz. Natijalar hisoblansinmi?',
    'Вы ответили на все вопросы диагностики. Рассчитать результаты?',
  );
  String get placementConfirmSubmit =>
      _t('Topshirish', 'Да, завершить');
  String get placementSubmitError => _t(
    'Natijalarni saqlab bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось сохранить результаты. Попробуйте ещё раз.',
  );
  String get reloadSession =>
      _t('Sessiyani qayta yuklash', 'Перезагрузить сессию');
  String get diagnosticReadyBadge =>
      _t('Natija tayyor', 'Результат готов');
  String get placementDoneTitle =>
      _t('Diagnostika yakunlandi', 'Диагностика завершена');
  String placementCorrectSummary(int correct, int total) => _t(
    '$correct / $total javob to‘g‘ri.',
    'Правильных ответов: $correct из $total.',
  );
  String get diagnosticHandoffNote => _t(
    'Bilim xaritangiz va shaxsiy ta’lim yo‘lingiz natijalaringiz asosida yangilandi.',
    'Карта знаний и ваш путь обучения обновлены на основе результатов.',
  );
  String get skillBreakdownTitle =>
      _t('Ko‘nikmalar kesimi', 'Разбивка по навыкам');
  String get viewPersonalPath =>
      _t('Shaxsiy yo‘lni ko‘rish', 'Персональный путь обучения');
  String get retakePlacement =>
      _t('Diagnostikani qayta topshirish', 'Пройти диагностику снова');
  String get answersReviewTitle =>
      _t('Javoblar tahlili', 'Разбор ответов');
  String get answerCorrectTag => _t('To‘g‘ri', 'Верно');
  String get answerWrongTag => _t('Xato', 'Ошибка');
  String yourAnswerLine(String answer) =>
      _t('Sizning javobingiz: $answer', 'Ваш ответ: $answer');
  String correctAnswerLine(String answer) =>
      _t('To‘g‘ri javob: $answer', 'Правильный ответ: $answer');
  String get calculatingResults =>
      _t('Natijalar hisoblanmoqda...', 'Вычисление результатов...');
  String get buildingKnowledgeMap => _t(
    'Shaxsiy bilim xaritasi va ta’lim yo‘lingiz tuzilmoqda.',
    'Формируем карту знаний и ваш персональный путь.',
  );
  String get preparingQuestions =>
      _t('Savollar tayyorlanmoqda...', 'Подготовка вопросов...');
  String get questionsLoadFailed =>
      _t('Savollarni yuklab bo‘lmadi.', 'Не удалось загрузить вопросы.');
  String get questionsLoadingDesc => _t(
    'Moslashuvchan diagnostika yuklanmoqda.',
    'Загружается адаптивная диагностика.',
  );

  // --- Roadmap & Knowledge Map (/roadmap, /knowledge-map) ---
  String get myRoadmapTitle =>
      _t('Mening ta’lim yo‘lim', 'Мой путь обучения');
  String get roadmapPill => _t('Ta’lim yo‘li', 'Путь обучения');
  String get roadmapHeading =>
      _t('Shaxsiy o‘quv', 'Ваш персональный');
  String get roadmapHighlight => _t('xaritangiz', 'путь обучения');
  String get roadmapSubtitle => _t(
    'Har bir bosqich diagnostika va oxirgi mashqlaringiz asosida moslashadi.',
    'Каждый этап адаптируется под вашу диагностику и недавние результаты.',
  );
  String get roadmapSummaryTitle =>
      _t('Bosqichlar bajarilishi', 'Прогресс по этапам');
  String roadmapStepsProgress(int done, int total) =>
      _t('$done / $total bosqich', '$done / $total эт.');
  String get roadmapLoadError => _t(
    'Ta’lim yo‘lini yuklab bo‘lmadi.',
    'Не удалось загрузить путь обучения.',
  );
  String get roadmapEmptyTitle => _t(
    'Bu fan uchun hozircha bosqichlar topilmadi.',
    'Для этого предмета этапы пока не найдены.',
  );
  String get optionalTag => _t('Ixtiyoriy', 'Доп.');
  String stageNumLabel(int n) => _t('$n-Bosqich', 'Этап $n');
  String get statusReviewDue =>
      _t('Takrorlash vaqti', 'Пора повторить');
  String get statusReinforcement =>
      _t('Qayta mashq kerak', 'Нужна практика');
  String get statusMastered => _t('O‘zlashtirilgan', 'Освоено');
  String get statusCompleted100 =>
      _t('Bajarildi (100%)', 'Выполнено (100%)');
  String get statusActiveLesson => _t('Faol dars', 'Активный урок');
  String get statusAvailable => _t('Ochiq', 'Открыто');
  String get statusInProgress => _t('Mashq qilinyapti', 'В процессе');
  String get statusPrerequisiteNeeded =>
      _t('Oldingi mavzuni yakunlang', 'Сначала пройдите предыдущую тему');
  String minutesDuration(int m) => _t('$m daqiqa', '$m мин');
  String get overallMastery =>
      _t('Umumiy O‘zlashtirish', 'Общее освоение');
  String get knowledgeMapBannerDesc => _t(
    'Diagnostika va darslaringiz asosidagi ko‘nikmalar xaritasi.',
    'Карта навыков на основе вашей диагностики и уроков.',
  );
  String get weakLinkBadge =>
      _t('DIQQAT: Zaif Bo‘g‘in', 'ВНИМАНИЕ: Слабое место');
  String weakSkillPrompt(String name) => _t(
    '$name ko‘nikmasini mustahkamlash tavsiya etiladi.',
    'Рекомендуется укрепить навык «$name».',
  );
  String get weakSkillRoadmapNote => _t(
    'Ta’lim yo‘lingizda ushbu mavzu ustuvor qilib belgilandi.',
    'Эта тема отмечена как приоритетная на вашем пути обучения.',
  );
  String get skillsAnalysisPill =>
      _t('Ko‘nikmalar tahlili', 'Анализ навыков');
  String get skillsAnalysisTitle =>
      _t('Mavzular bo‘yicha', 'Уровень освоения');
  String get skillsAnalysisHighlight => _t('o‘zlashtirish', 'по темам');
  String get adaptiveRoadmapCta =>
      _t('Moslashuvchan Yo‘l Xaritasi', 'Персональный путь обучения');
  String get knowledgeMapEmptyPrompt => _t(
    'Ko‘nikmalar xaritasini ko‘rish uchun diagnostika yoki darsni boshlang.',
    'Пройдите диагностику или начните урок, чтобы увидеть карту навыков.',
  );
  String masteryLabel(int score, {int? attemptCount}) {
    final level = SkillScoringEngine.getMasteryLevel(
      score,
      attemptCount: attemptCount,
    );
    return switch (level) {
      MasteryLevel.needsRemediation => _t('Boshlang‘ich', 'Начальный'),
      MasteryLevel.developing => _t('Rivojlanmoqda', 'Развивается'),
      MasteryLevel.proficient => _t('O‘rta', 'Средний'),
      MasteryLevel.mastered => _t('Yuqori', 'Высокий'),
    };
  }
  String confidenceBadgeLabel(ConfidenceLevel level) => switch (level) {
    ConfidenceLevel.low => _t('Aniqlik: Dastlabki', 'Точность: Начальная'),
    ConfidenceLevel.medium => _t('Aniqlik: O‘rta', 'Точность: Средняя'),
    ConfidenceLevel.high => _t('Aniqlik: Yuqori', 'Точность: Высокая'),
  };
  String reassessmentFloorNote(String assessed, String floor) => _t(
    'Joriy diagnostika natijasi: $assessed. Oldingi o‘zlashtirilgan bosqich saqlandi: $floor.',
    'Результат текущей диагностики: $assessed. Ранее освоенный уровень сохранён: $floor.',
  );

  // --- Progress (/progress) ---
  String get progressScreenTitle => _t('Mening natijalarim', 'Мои результаты');
  String get progressPill => _t('Natijalar tahlili', 'Аналитика результатов');
  String get progressSectionTitle => _t('Ta’lim', 'Показатели');
  String get progressSectionHighlight => _t('ko‘rsatkichlari', 'обучения');
  String get progressSectionFull =>
      _t('Ta’lim ko‘rsatkichlari', 'Показатели обучения');
  String get timeframeWeek => _t('Bu hafta', 'Эта неделя');
  String get timeframeMonth => _t('Bu oy', 'Этот месяц');
  String get statCompletedLessons =>
      _t('Bajarilgan dars', 'Выполненные уроки');
  String get statMastery => _t('O‘zlashtirish', 'Освоение');
  String get statStreak => _t('Kun ketma-ket', 'Дней подряд');
  String get statXpTotal => _t('Umumiy ballar', 'Всего баллов');
  String get studyTimeTitle => _t('O‘qish vaqti', 'Время обучения');
  String get studyTimeUnit => _t('Soat / kun', 'Час / день');
  String studyTimeSummary(int days, int totalMinutes) => _t(
    '$days kun · jami $totalMinutes daqiqa',
    '$days дн. · всего $totalMinutes мин',
  );
  String get progressEmptyActivity => _t(
    'Hali o‘quv faoliyati qayd etilmagan.',
    'Учебная активность пока не зафиксирована.',
  );
  String get progressActivityLoadFailed => _t(
    'O‘qish faoliyatini yuklab bo‘lmadi. Qayta urinib ko‘ring.',
    'Не удалось загрузить учебную активность. Попробуйте ещё раз.',
  );
  List<String> get shortWeekdays => isRu
      ? const ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб']
      : const ['Yak', 'Dsh', 'Ssh', 'Chor', 'Pay', 'Jum', 'Shan'];
  String get subjectBreakdownTitle =>
      _t('Mavzular bo‘yicha natija', 'Результаты по предметам');
  String get achievementsTitle =>
      _t('Yutuqlar va nishonlar', 'Достижения и значки');
  String achievementsEarned(int earned, int total) =>
      _t('$earned/$total Olingan', 'Получено $earned/$total');
  String get badgeFirstStepTitle => _t('Birinchi qadam', 'Первый шаг');
  String get badgeFirstStepDesc =>
      _t('Ilk darsni yakunlash', 'Завершить первый урок');
  String get badge3DayStreakTitle =>
      _t('3 kunlik seriya', 'Серия 3 дня');
  String get badge3DayStreakDesc =>
      _t('3 kun ketma-ket o‘qish', 'Заниматься 3 дня подряд');
  String get badgeExpertTitle => _t('Bilimdon', 'Знаток');
  String get badgeExpertDesc =>
      _t('100+ XP to‘plash', 'Набрать 100+ XP');
  String get badgeMasterTitle => _t('Ustoz', 'Мастер');
  String get badgeMasterDesc =>
      _t('5 ta darsni tugatish', 'Пройти 5 уроков');
  String get progressBannerTitleActive =>
      _t('Ajoyib natija!', 'Отличный результат!');
  String get progressBannerTitleIdle =>
      _t('Boshlashga tayyormisiz?', 'Готовы начать?');
  String progressBannerBodyActive(int lessons, int xp) => _t(
    'Siz allaqachon $lessons ta dars yakunladingiz va $xp XP to‘pladingiz.',
    'Вы уже завершили $lessons ур. и набрали $xp XP.',
  );
  String get progressBannerBodyIdle => _t(
    'Birinchi darsni boshlang va kunlik seriyangizni yo‘lga qo‘ying.',
    'Начните первый урок и запустите свою ежедневную серию.',
  );

  // --- Yo‘lchi AI (/ai-tutor) ---
  String get aiTutorWelcomeMessage => _t(
    'Salom, men Yo‘lchi AI! Tushunmagan joyingizni yozing yoki yana bir misol so‘rang.',
    'Привет, я Yo‘lchi AI! Напишите, что непонятно, или попросите ещё один пример.',
  );
  String get aiTutorStatusDemo => _t('Namuna rejimi', 'Демо-режим');
  String get aiTutorStatusOnline =>
      _t('Pedagogik yordamchi', 'AI-наставник');
  String get aiTutorStatusOffline =>
      _t('Offline • Qayta urinib ko‘ring', 'Офлайн • Попробуйте снова');
  String get aiTutorStatusPrompt => _t('Savolingizni yozing', 'Задайте вопрос');
  List<String> get aiTutorQuickPrompts => isRu
      ? const [
          'Объясни проще',
          'Дай ещё один пример',
          'Дай тренировочный вопрос',
        ]
      : const [
          'Qoidani sodda tushuntir',
          'Yana bitta misol ber',
          'Mashq savoli ber',
        ];
  String get aiTutorInputHint => _t('Savol yozing...', 'Напишите вопрос...');
  String get aiTutorSendTooltip => _t('Yuborish', 'Отправить');
  String get aiTutorGenericError => _t(
    'Yo‘lchi AI bilan bog‘lanishda xatolik yuz berdi. Qayta urinib ko‘ring.',
    'Не удалось связаться с Yo‘lchi AI. Попробуйте ещё раз.',
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
