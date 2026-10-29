# BilimYo‘l Smart Edu

> **"Darslik emas — shaxsiy ta’lim yo‘li."**
>
> AI yordamida shaxsiylashtirilgan ta’lim platformasi: diagnostika → adaptiv yo‘l
> → interaktiv dars → mustahkamlash → analitika. Yo‘lchi AI xatolarni pedagogik
> tahlil qiladi va o‘quv yo‘lini qayta quradi.

Ushbu repozitoriy ikkita ilovani o‘z ichiga oladi:

| Papka | Texnologiya | Tavsif |
|---|---|---|
| `src/` | React 19 + TypeScript + Vite + Tailwind 4 + Zustand | Web platforma |
| `mobile/` | Flutter + Riverpod + GoRouter | Native mobil ilova |

---

## Asosiy imkoniyatlar

- **Adaptiv diagnostika** — fan bo‘yicha boshlang‘ich test, ko‘nikma bo‘shliqlarini aniqlash.
- **Shaxsiy yo‘l xaritasi** — `RouteEngine` natijalarga qarab bosqichlarni ochadi/bloklaydi.
- **Interaktiv darslar** — nazariya, formula, grafik/audio simulyatsiya, test.
- **To‘g‘ri javob va izoh** — xato javobda tanlangan variant, to‘g‘ri javob va sabab ko‘rsatiladi.
- **Yo‘lchi AI** — xatoni pedagogik tahlil qiladi va remediativ qadam beradi.
- **Mustahkamlash** — zaif mavzu uchun qisqa mashq, bal va XP yangilanadi.
- **Gamifikatsiya** — XP, streak, kunlik maqsad, natijalar analitikasi.
- **To‘rt fan** — Matematika, Ingliz tili, IT & Kodlash, Mantiq (web va mobil).

---

## Web platforma

```bash
npm install
npm run dev        # http://localhost:5173
```

Sifat tekshiruvlari:

```bash
npm run typecheck  # tsc --noEmit
npm run lint       # oxlint
npm test           # vitest (232 test)
npm run build      # production build
```

Oflayn demo rejimi: Supabase sozlanmagan bo‘lsa, ilova `Namuna hisobi bilan
kirish` orqali to‘liq lokal ma’lumot bilan ishlaydi.

---

## Mobil ilova

Batafsil: [`mobile/README.md`](mobile/README.md).

```bash
cd mobile
flutter pub get
flutter analyze    # 0 issue
flutter test       # 69 test
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

Mobil ilova Supabase kalitisiz ham **oflayn demo rejimida** ishlaydi. Hakamlar
uchun dashboardda **Demo Reset**, diagnostikada **Tezkor demo** mavjud.

---

## Arxitektura (web)

```text
src/
  app/            # router, Zustand storelar
  core/           # config, context, runtime, services, utils
  domain/         # entities, personalization engine'lar, usecase'lar
  data/           # datasources, repositories (InMemory / Supabase), AI services
  features/       # auth, course-selection, onboarding, placement, knowledge-map,
                  # roadmap, lesson, ai-tutor, reinforcement, dashboard, progress,
                  # profile, admin, pitch
  presentation/   # design system komponentlari (Button, Card, Badge, ...)
```

- **Baholash:** server-avtoritativ (`submit_answer_attempt` RPC / in-memory scorer);
  client savol payloadida javob kaliti saqlanmaydi.
- **AI:** `yolchi-tutor` Edge Function (Gemini) → deterministik fallback.
- **Demo rejimi:** `isDemoRuntimeActive() || !isSupabaseConfigured` →
  InMemory repozitoriylar.

---

## Maxfiylik

`.env`, `.env.local` va `mobile/supabase_env.json` gitignore qilingan. Maxfiy
kalitlarni hech qachon commit qilmang; `*.example` fayllaridan nusxa oling.