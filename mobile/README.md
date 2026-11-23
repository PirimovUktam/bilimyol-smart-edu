# BilimYöl Smart Edu — Flutter Mobile

> Umummilliy AI Xakaton 2026 uçun native Flutter mobil ilovasi.
> "Darslik emas — şaxsiy ta’lim yöli."

BilimYöl Smart Edu — öquvçining bilim böşliqlarini aniqlab, adaptiv öquv
yölini quradigan, xatolarni Yölçi AI orqali pedagogik tahlil qiladigan mobil
platforma.

---

## Işga tuşiriş

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

Supabase kaliti berilmasa ilova **avtomatik oflayn demo rejimida** işlaydi —
barça ma’lumotlar qurilma içida, tarmoq talab qilinmaydi. Bu hackaton
namoyişi uçun tavsiya etiladi.

### Release APK

```powershell
flutter build apk --release
# Natija: build/app/outputs/flutter-apk/app-release.apk
```

Hakamlarga tarqatiş uçun tayyor APK şu yölda böladi. Örnatiş:
`adb install -r build/app/outputs/flutter-apk/app-release.apk` yoki faylni
telefonga köçirib örnatiş.

### Supabase bilan ulaş (ixtiyoriy)

```powershell
Copy-Item supabase_env.example.json supabase_env.json
# supabase_env.json içidagi qiymatlarni töldiring
flutter run --dart-define-from-file=supabase_env.json
```

`supabase_env.json` gitignore qilingan — maxfiy kalitlar commit qilinmaydi.

---

## Fanlar (törtala fan töliq işlaydi)

| Fan | Könikmalar | Darslar |
|---|---|---|
| Matematika | Algebra, Tenglamalar, Funksiyalar, Grafiklar | 3 |
| Ingliz tili | Vocabulary, Grammar, Listening, Reading | 3 |
| IT & Kodlaş | Python, Veb dasturlaş | 2 |
| Mantiq | Boşqotirmalar, Qonuniyatlar | 2 |

Har bir fan uçun diagnostika savollari, yöl xaritasi va mustahkamlaş
maşqlari mavjud.

---

## Hakamlar uçun demo oqimi

1. **Fan tanlaş** — Matematika (yoki istalgan fan).
2. **Onboarding** — maqsad, kunlik vaqt, daraja.
3. **Diagnostika** — savollarga javob bering **yoki** yuqoridagi
   **"Tezkor demo"** tugmasini bosing (adaptiv profil tayyorlanadi).
4. **Bilim xaritasi** — zaif könikma ogohlantiriş bilan körsatiladi.
5. **Yöl xaritasi** — adaptiv bosqiçlar; zaif mavzu mustahkamlaşga tuşadi.
6. **Dars** — nazariya, formula, interaktiv savol. Ataylab **xato javob**
   tanlang: Yölçi AI oynasi tanlangan javob, **töğri javob**, sabab va
   remediativ qadamni körsatadi.
7. **Mustahkamlaş** — töğri javob bering; bal va XP yangilanadi.
8. **Dashboard** — kunlik maqsad, streak, XP va keyingi qadam.
9. **Demo Reset** — dashboard yuqorisidagi qora panel orqali holatni istalgan
   vaqtda qayta boşlang.

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
- **Xavfsizlik:** server-avtoritativ baholaş kontrakti; client savol payloadida
  javob kaliti saqlanmaydi (AI xizmatlari kalitni server tomonida röyxatdan
  ötkazadi).

---

## Sifat holati

- `flutter analyze` — 0 xato, 0 ogohlantiriş.
- `flutter test` — 69/69 test ötadi.
- `flutter build apk --release` — muvaffaqiyatli.