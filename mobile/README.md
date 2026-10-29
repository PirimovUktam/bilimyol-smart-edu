# BilimYo‘l Smart Edu — Flutter Mobile

> Umummilliy AI Xakaton 2026 uchun native Flutter mobil ilovasi.
> "Darslik emas — shaxsiy ta’lim yo‘li."

BilimYo‘l Smart Edu — o‘quvchining bilim bo‘shliqlarini aniqlab, adaptiv o‘quv
yo‘lini quradigan, xatolarni Yo‘lchi AI orqali pedagogik tahlil qiladigan mobil
platforma.

---

## Ishga tushirish

Talablar: Flutter `>=3.44.0` (loyiha `3.45.0-0.1.pre` beta bilan qurilgan) va
Android SDK.

```powershell
cd mobile
flutter pub get
flutter analyze      # No issues found
flutter test         # 69/69 passed
flutter run          # qurilma/emulyatorda
```

### Offline demo rejimi

Supabase kaliti berilmasa ilova **avtomatik oflayn demo rejimida** ishlaydi —
barcha ma’lumotlar qurilma ichida, tarmoq talab qilinmaydi. Bu hackaton
namoyishi uchun tavsiya etiladi.

### Release APK

```powershell
flutter build apk --release
# Natija: build/app/outputs/flutter-apk/app-release.apk
```

Hakamlarga tarqatish uchun tayyor APK shu yo‘lda bo‘ladi. O‘rnatish:
`adb install -r build/app/outputs/flutter-apk/app-release.apk` yoki faylni
telefonga ko‘chirib o‘rnatish.

### Supabase bilan ulash (ixtiyoriy)

```powershell
Copy-Item supabase_env.example.json supabase_env.json
# supabase_env.json ichidagi qiymatlarni to‘ldiring
flutter run --dart-define-from-file=supabase_env.json
```

`supabase_env.json` gitignore qilingan — maxfiy kalitlar commit qilinmaydi.

---

## Fanlar (to‘rtala fan to‘liq ishlaydi)

| Fan | Ko‘nikmalar | Darslar |
|---|---|---|
| Matematika | Algebra, Tenglamalar, Funksiyalar, Grafiklar | 3 |
| Ingliz tili | Vocabulary, Grammar, Listening, Reading | 3 |
| IT & Kodlash | Python, Veb dasturlash | 2 |
| Mantiq | Boshqotirmalar, Qonuniyatlar | 2 |

Har bir fan uchun diagnostika savollari, yo‘l xaritasi va mustahkamlash
mashqlari mavjud.

---

## Hakamlar uchun demo oqimi

1. **Fan tanlash** — Matematika (yoki istalgan fan).
2. **Onboarding** — maqsad, kunlik vaqt, daraja.
3. **Diagnostika** — savollarga javob bering **yoki** yuqoridagi
   **"Tezkor demo"** tugmasini bosing (adaptiv profil tayyorlanadi).
4. **Bilim xaritasi** — zaif ko‘nikma ogohlantirish bilan ko‘rsatiladi.
5. **Yo‘l xaritasi** — adaptiv bosqichlar; zaif mavzu mustahkamlashga tushadi.
6. **Dars** — nazariya, formula, interaktiv savol. Ataylab **xato javob**
   tanlang: Yo‘lchi AI oynasi tanlangan javob, **to‘g‘ri javob**, sabab va
   remediativ qadamni ko‘rsatadi.
7. **Mustahkamlash** — to‘g‘ri javob bering; bal va XP yangilanadi.
8. **Dashboard** — kunlik maqsad, streak, XP va keyingi qadam.
9. **Demo Reset** — dashboard yuqorisidagi qora panel orqali holatni istalgan
   vaqtda qayta boshlang.

---

## Arxitektura

```text
lib/
  app/            # MaterialApp.router, GoRouter, Riverpod providers
  core/           # constants, theme, errors, widgets (AppButton, AppCard, ...)
  domain/         # entities, personalization (scoring/route engines), usecases
  data/           # datasources (seed content), repositories, AI services
  features/       # auth, course_selection, onboarding, placement, knowledge_map,
                  # roadmap, lesson, ai_tutor, reinforcement, dashboard, progress, profile
```

- **State:** Riverpod (`StateNotifier`), generation-guarded async flows.
- **Routing:** GoRouter (`/courses`, `/onboarding`, `/placement`, `/knowledge-map`,
  `/roadmap`, `/lesson`, `/dashboard`, `/progress`, `/ai-tutor`, `/profile`).
- **Scoring:** `SkillScoringEngine`, `RouteEngine`, `ProgressEngine` — deterministik.
- **Xavfsizlik:** server-avtoritativ baholash kontrakti; client savol payloadida
  javob kaliti saqlanmaydi (AI xizmatlari kalitni server tomonida ro‘yxatdan
  o‘tkazadi).

---

## Sifat holati

- `flutter analyze` — 0 xato, 0 ogohlantirish.
- `flutter test` — 69/69 test o‘tadi.
- `flutter build apk --release` — muvaffaqiyatli.