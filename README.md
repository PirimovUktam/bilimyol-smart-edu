# BilimYöl Smart Edu

> **"Darslik emas — şaxsiy ta’lim yöli."**
>
> AI yordamida şaxsiylaştirilgan ta’lim platformasi: diagnostika → adaptiv yöl
> → interaktiv dars → mustahkamlaş → analitika. Yölçi AI xatolarni pedagogik
> tahlil qiladi va öquv yölini qayta quradi.

Uşbu repozitoriy ikkita ilovani öz içiga oladi:

| Papka | Texnologiya | Tavsif |
|---|---|---|
| `src/` | React 19 + TypeScript + Vite + Tailwind 4 + Zustand | Web platforma |
| `mobile/` | Flutter + Riverpod + GoRouter | Native mobil ilova |

---

## Asosiy imkoniyatlar

- **Adaptiv diagnostika** — fan böyiça boşlanğiç test, könikma böşliqlarini aniqlaş.
- **Şaxsiy yöl xaritasi** — `RouteEngine` natijalarga qarab bosqiçlarni ochadi/bloklaydi.
- **Interaktiv darslar** — nazariya, formula, grafik/audio simulyatsiya, test.
- **Töğri javob va izoh** — xato javobda tanlangan variant, töğri javob va sabab körsatiladi.
- **Yölçi AI** — xatoni pedagogik tahlil qiladi va remediativ qadam beradi.
- **Mustahkamlaş** — zaif mavzu uçun qisqa maşq, bal va XP yangilanadi.
- **Gamifikatsiya** — XP, streak, kunlik maqsad, natijalar analitikasi.
- **Tört fan** — Matematika, Ingliz tili, IT & Kodlaş, Mantiq (web va mobil).

---

## Web platforma

```bash
npm install
npm run dev        # http://localhost:5173
```

Sifat tekşiruvlari:

```bash
npm run typecheck  # tsc --noEmit
npm run lint       # oxlint
npm test           # vitest (232 test)
npm run build      # production build
```

Oflayn demo rejimi: Supabase sozlanmagan bölsa, ilova `Namuna hisobi bilan
kiriş` orqali töliq lokal ma’lumot bilan işlaydi.

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

Mobil ilova Supabase kalitisiz ham **oflayn demo rejimida** işlaydi. Hakamlar
uçun daşboardda **Demo Reset**, diagnostikada **Tezkor demo** mavjud.

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

- **Baholaş:** server-avtoritativ (`submit_answer_attempt` RPC / in-memory scorer);
  client savol payloadida javob kaliti saqlanmaydi.
- **AI:** `yolchi-tutor` Edge Function (Gemini) → deterministik fallback.
- **Demo rejimi:** `isDemoRuntimeActive() || !isSupabaseConfigured` →
  InMemory repozitoriylar.

---

## Maxfiylik

`.env`, `.env.local` va `mobile/supabase_env.json` gitignore qilingan. Maxfiy
kalitlarni heç qaçon commit qilmang; `*.example` fayllaridan nusxa oling.