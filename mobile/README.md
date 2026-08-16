# BilimYo‘l Smart Edu — Flutter Mobile (Checkpoint 1)

> **Umummilliy AI Xakaton 2026 — Qarshi bosqichi**
> Moslashuvchan va Shaxsiylashtirilgan Ta’lim Platformasining Native Flutter Mobil Ilovasi.

---

## 📱 Loyiha Haqida

BilimYo‘l Smart Edu — o‘quvchilarning individual bilim bo‘shliqlarini aniqlab, ularga moslashuvchan o‘quv traektoriyasini shakllantiruvchi intellektual mobil platforma.

Ushbu ilova **Checkpoint 1: Core Intelligence Loop** talablari asosida ishlab chiqilgan bo‘lib, to‘liq **offline**, **deterministic** va yuqori darajadagi mobil UX arxitekturasida ishlaydi.

---

## 🏛️ Arxitektura (Clean Architecture + Riverpod)

Loyiha Clean Architecture tamoyillariga qat'iy asoslangan:

```text
lib/
├── app/
│   ├── app.dart               # MaterialApp.router va Theme integratsiyasi
│   ├── router.dart            # GoRouter deklarativ marshrutlash tizimi
│   └── providers.dart         # Riverpod StateNotifier va UseCase provayderlari
│
├── core/
│   ├── constants/             # Adaptiv chegaralar (AdaptiveThresholds), ranglar (AppColors)
│   ├── theme/                 # GoogleFonts Plus Jakarta Sans Material 3 yorug' mavzusi
│   ├── errors/                # DomainError va maxsus xatolik klasslari
│   └── widgets/               # Logo, AppButton, AppCard, AppBadge, DemoControlBar
│
├── domain/
│   ├── entities/              # Course, Skill, SkillScore, LearnerProfile, Question, Lesson, LearningPath
│   ├── personalization/       # SkillScoringEngine, RouteEngine, RecommendationEngine, ProgressEngine
│   ├── repositories/          # ICourseRepository, ILessonRepository, ILearnerRepository
│   └── usecases/              # 8 ta toza domen usecase'lari
│
├── data/
│   ├── datasources/           # courses_data, skills_data, questions_data, lessons_data, roadmaps_data, demo_ai_data
│   ├── services/              # IAITutorService va DemoAITutorService
│   └── repositories/          # InMemoryCourseRepository, InMemoryLessonRepository, InMemoryLearnerRepository
│
└── features/
    ├── course_selection/      # Fan tanlash ekrani (Matematika & Ingliz tili)
    ├── onboarding/            # 3 bosqichli onboarding so'rovnomasi
    ├── placement/             # 5 ta savolli deterministic diagnostik test + "Tezkor Demo"
    ├── knowledge_map/         # Bilim xaritasi va "DIQQAT: Zaif bo'g'in" ogohlantirish banneri
    ├── roadmap/               # Vertikal adaptiv yo'l xaritasi va mustahkamlash qadami
    ├── lesson/                # Interaktiv dars, Grafik simulyatori va Audio to'lqin pleyeri
    ├── ai_tutor/              # Yo'lchi AI pedagogik xato diagnostikasi modali
    ├── reinforcement/         # Qisqa mustahkamlash mashqi va 41% -> 63% bal yangilanishi
    └── dashboard/             # Kunlik ko'rsatkichlar, joriy fokus va navbatdagi qadam
```

---

## 🚀 Ishga Tushirish va Komandalar

### Talablar:
- **Flutter SDK:** `>=3.13.0` (Tizimda: `3.45.0`)
- **Dart SDK:** `>=3.0.0` (Tizimda: `3.13.0`)
- **Android SDK:** `API 34+`

### Loyiha katalogiga kirish:
```powershell
cd D:\projects\Bilimyol\mobile
```

### Paketlarni yuklab olish:
```powershell
flutter pub get
```

### Statik tahlil (Linter):
```powershell
flutter analyze
# Natija: No issues found! (0 xato, 0 ogohlantirish)
```

### Barcha testlarni ishga tushirish:
```powershell
flutter test
# Natija: All 12 tests passed!
```

### Ilovani ishga tushirish:
```powershell
flutter run
```

### Android APK yig‘ish:
```powershell
# Debug APK:
flutter build apk --debug
# Fayl: build/app/outputs/flutter-apk/app-debug.apk

# Release APK:
flutter build apk --release
# Fayl: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔄 Checkpoint 1 Demo Oqimi (Matematika & Ingliz tili)

1. **Fan Tanlash (`/courses`):** `Matematika` (Asosiy) yoki `Ingliz tili` tanlanadi.
2. **Onboarding (`/onboarding`):** Maqsad, Kunlik vaqt (15 daqiqa) va O‘rta daraja belgilanadi.
3. **Placement Test (`/placement`):** 5 ta savolga javob beriladi (yoki hakamlar uchun yuqoridagi `Tezkor Demo` tugmasi bosiladi).
4. **Knowledge Map (`/knowledge-map`):** Barcha ko‘nikmalar baholanadi. Matematika uchun **Funksiyalar — 41%** (Ingliz tili uchun **Listening — 43%**) zaif bo‘g‘in sifatida ogohlantirish bilan ko‘rsatiladi.
5. **Yo‘l Xaritasi (`/roadmap`):** Funksiyalar darsi `Mustahkamlash` holatiga o‘tadi, keyingi `Grafiklar` mavzusi bloklanadi.
6. **Interaktiv Dars (`/lesson`):** Tushuncha, formula, interaktiv grafik modeli orqali o‘rganilib, 4-savolda `Xato javobni tanlash` (8) bosiladi.
7. **Yo‘lchi AI Modali:** Noto‘g‘ri javob berilgach, sun’iy intellekt xatoning pedagogik sababini tushuntiradi.
8. **Mustahkamlash Mashqi:** $f(x)=3x+2, x=2$ savoliga to‘g‘ri javob (**8**) beriladi.
9. **Balning Yangilanishi:** Ball **41% dan 63% ga** oshadi, **+30 XP** beriladi va **Grafiklar** mavzusi blokdan ochiladi.
10. **Dashboard (`/dashboard`):** Kunlik reja, joriy fokus (63%), streak va yangi ochilgan navbatdagi qadam ko‘rsatiladi.
11. **Demo Reset:** Yuqori qora nazorat panelidagi `Reset` tugmasi orqali demo istalgan vaqtda qayta ishga tushiriladi.
