# BilimYo‘l Smart Edu auditi

2026-yil 6-noyabr. Boshlang‘ich tarmoq `main`, commit `34ed661`. Ish papkasida veb va Flutter uchun avvalgi tuzatishlar mavjud edi.

## Boshlang‘ich holat

- Veb ilova Vite, React, Zustand va Supabase SDK asosida. `src/app/router/AppRouter.tsx` yo‘nalishlarni, `src/core/context/AuthContext.tsx` sessiya va profilni, `src/app/store/` kurs, yo‘l, diagnostika va dars holatini boshqaradi. Oflayn namuna va Supabase omborlari `src/data/repositories/` ichida ajratilgan. Domen algoritmlari `src/domain/personalization/` ichida.
- Flutter ilova `mobile/lib/app/router.dart` va `mobile/lib/app/providers.dart` orqali GoRouter, Riverpod va o‘sha Supabase shartnomasidan foydalanadi. Testlar kurs ajratilishi, dars holati, diagnostika va sessiyani qamrab oladi.
- Jonli saytning kirish ekrani, namuna bosh sahifasi va Yo‘lchi AI sahifasi brauzerda ochildi. Jonli sahifadan haqiqiy o‘quvchi hisobi bilan yozuvli sinov qilinmadi.
- Boshlang‘ich tekshiruvlar. TypeScript, build, 237 Vitest testi, Flutter tahlili va 71 Flutter testi o‘tdi. Lint bitta Fast Refresh ogohlantirishini qaytardi. PostgreSQL 17.11 da barcha 19 migratsiya, seed va uchta SQL regressiya fayli o‘tdi. Ushbu SQL sinovida Auth jadvallari va `auth.uid()` test muhiti bilan ta’minlandi.

## Jiddiy

| Dalil va takrorlash | Ta’sir va tuzatish |
| --- | --- |
| `src/app/router/AppRouter.tsx` tizimga kirgan har qanday sessiyani tiklash formasidan chiqaradi. Amaldagi recovery havolasini oching va Supabase sessiya yaratishini kuting. | Forma ko‘rinmay qoladi. `PASSWORD_RECOVERY` hodisasini provayderda ushlash, yo‘nalishni saqlash va yangilashni aynan shu sessiyaga bog‘lash. |
| `supabase/functions/yolchi-tutor/index.ts` ichida autentifikatsiyalangan so‘rov `questionId` bilan AI xato tahlilini bevosita chaqira oladi. Server avval o‘quvchi shu savolni yechganini tekshirmasdan kalitni modelga uzatadi. | Javob kalitini AI orqali olish va o‘quvchining javobi haqida uydirma kontekst berish mumkin. O‘quvchining kurs va ko‘nikmaga mos xato urinishi hamda serverdagi savolni talab qilish. |
| `supabase/migrations/20261015000001_followup_security_persistence_hardening.sql` dagi `provision_missing_profiles()` lokal katalogda anonim rolga ochiq. Anonim rolda `has_function_privilege` true qaytaradi. | Ommaviy RPC barcha hisoblarga profil yozuvlarini yaratishi va bazaga ortiqcha yuk tushirishi mumkin. Ijro huquqini xizmat roliga cheklash. |

## Yuqori

- `record_session_heartbeat` (`supabase/migrations/20260817000003_parent_teacher_monitoring.sql`) kunni UTC bo‘yicha hisoblaydi. Bir nechta sessiya bilan bir xil vaqtni takroran hisoblash va bitta sessiyada parallel so‘rovlar xavfi mavjud. RPC huquqlarini toraytirish, o‘quvchi bo‘yicha ketma-ket hisoblash va Toshkent kuniga o‘tkazish.
- `src/app/store/useCourseStore.ts` avvalgi mahalliy kursni va server profilini alohida yuklaydi. `AppRouter.tsx` serverdagi tanlovni qayta yozib tiklaydi, yuklash band bo‘lganida esa kelgan qiymatni ko‘rilgan deb belgilashi mumkin. Server kursini avval o‘qish va faqat foydalanuvchi tanlovini yozish.
- Yo‘lchi chatida mavzu sifatida fan nomi yuboriladi, bo‘sh ball 0 yoki 50 foizga aylanadi va Gemini modeli haqida eskirgan yozuv bor. `src/features/ai-tutor/YolchiAIChatView.tsx` va Edge Function’da tasdiqlangan mavzu, daraja va yaqindagi xatolar bilan ishlash.
- Edge Function xotirasidagi limit bir ishchi jarayonga tegishli. Turli ishchi jarayonlarga tushgan parallel chaqiruvlar umumiy limitni aylanib o‘tishi mumkin. Gemini so‘rovini va pulli harakatlarni bitta server limitiga bog‘lash.
- `evaluate_placement_answer` amaldagi veb va mobil adaptiv algoritmlar uchun yuborilgan variantning to‘g‘ri yoki xatoligini qaytaradi. Ochiq diagnostika bankini API orqali variantma-variant sinash mumkin. Mustahkam yechim server boshqaradigan diagnostika sessiyasi va ikkala mijozni bosqichli ko‘chirishni talab qiladi.

## O‘rta

- Jonli bosh sahifada statistikalar va to‘rtta baland fan kartasi «Davom etish» tugmasidan oldin keladi. Bosh sahifa va ichki yo‘nalishlar turli navigatsiyadan foydalanadi. `DashboardView.tsx`, `Navbar.tsx` va `AppRouter.tsx` uchun umumiy qobiq va ustuvor harakat.
- `src/features/auth/ForgotPasswordView.tsx` namuna rejimida email yuborilganini bildiradi. Forma yorliqlari ayrim maydonlar bilan dasturiy bog‘lanmagan. Umumiy kirish qobig‘i, to‘g‘ri natija matni va klaviatura boshqaruvi.
- `tests/e2e/run.mjs` avvaldan ishga tushgan tasodifiy serverni namuna sinovi deb qabul qilishi mumkin. Alohida port va oflayn muhitni aniq tanlash.
- `mobile/lib/data/repositories/supabase_learner_repository.dart` profil yangilaganda bir nechta maydonni birga yozadi. Vebdagi qisman yozish tuzatishiga moslashtirish kerak.

## Past

- `src/main.tsx` da ekranga xos render xatolarini ushlaydigan chegara yo‘q. Qayta yuklash va xavfsiz navigatsiyaga qaytish holatini qo‘shish.
- Boshlang‘ich build kirish JS fayli 464,21 kB (gzip 141,54 kB). Oflayn katalog bo‘lagi 253,86 kB (gzip 66,87 kB), kirish tasviri 861 kB. Yo‘nalishlar allaqachon alohida yuklanadi. Katalogni namuna yo‘liga ajratish va rasmlarni o‘lchab ixchamlashtirish.

## Ruxsat va tarix

- RLS shaxsiy urinishlar, ballar, dars holati va faollikni foydalanuvchiga bog‘laydi. Admin panelidan tashqari, kontent yozuvi RLS va role tekshiruvchi RPC orqali himoyalanadi. Joriy migratsiyalarda ilovaga xos Storage chelaki yoki Storage siyosati topilmadi.
- `.env`, `.env.local` va Vercel ishlab chiqarish muhiti fayli Git tomonidan e’tiborsiz qoldiriladi. Hozirgi Git indeksida va mavjud ref tarixida `.env` yoki `.env.local` yo‘q. Eski auditda OIDC tokeni haqida yozilgan, tarixiy tarqalish ushbu checkout orqali tasdiqlanmadi. Oldingi tarqalish mustaqil tasdiqlansa, o‘sha tokenni bekor qilish yoki aylantirish kerak. Qiymatlar qayd etilmadi.
- Eski auditdagi routerda tiklash sahifasi umuman yo‘qligi, yagona 1 MB paket va IT/Mantiq uchun namuna kontenti yo‘qligi joriy kodga mos kelmaydi.

## 7-noyabr holatidagi tuzatishlar

| Yo‘nalish | Amalga oshirilgan ish |
| --- | --- |
| Sessiya va fan izolyatsiyasi | `src/core/context/AuthContext.tsx` va `src/app/router/AppRouter.tsx` tiklash sessiyasini alohida boshqaradi, profil yuklangach serverdagi fanni tiklaydi va boshqa fan darsiga bevosita URL orqali kirishni bloklaydi. `src/features/profile/ProfileView.tsx` o‘rganish sozlamalari, parol va joriy qurilma yoki barcha sessiyalardan chiqishni boshqaradi. |
| Serverdagi diagnostika | `supabase/migrations/20261107114341_secure_placement_sessions.sql` savollarni o‘quvchi va fan bo‘yicha serverda saqlaydi. Namuna fayllaridagi 42 ta mos savol yangi diagnostika bankidan ajratildi. 12 ko‘nikma uchun uch darajada 36 ta server savoli mavjud. Har savol bir marta topshiriladi. Bir xil so‘rovni takrorlash xavfsiz. Yakunda ball, XP, ko‘nikma va izohlar bitta tranzaksiyada qayd qilinadi. Shu fandagi qayta topshirish keyingi Toshkent kunidan ochiladi. Eski API’ni yopish alohida migratsiyada. |
| Dars va mustahkamlash | `20261106150620_publish_curated_lesson_paths.sql` da to‘rt fan bo‘yicha 12 ta boshlang‘ich mavzuning darsi bor. To‘liq migratsiya zanjirida 12 ko‘nikmaning har biriga kamida ikki diagnostika savoli tegishli. Mustahkamlash mashqi o‘tilmagan darsga yakunlangan holatini bermaydi. Dars sahifasida formulalar, kod, amaliy savollar va server tasdiqlagan natija ko‘rinadi. |
| Yo‘lchi AI | `supabase/functions/yolchi-tutor/index.ts` serverda tasdiqlangan fan, mavzu, maqsad, daraja va so‘nggi xatolar bilan ishlaydi. Umumiy limit, so‘rov hajmi, kontekstni tekshirish va vaqt chegarasi qo‘shildi. Xato tahlili faqat hisobga tegishli urinishdan keyin ochiladi. Chat tarixini joriy brauzer sessiyasi fan bo‘yicha saqlaydi. |
| Faollik va ruxsatlar | `20261106143239_harden_tutor_and_learning_activity.sql` profilni umumiy to‘ldirish RPC huquqini xizmat roliga cheklaydi. O‘quv vaqti Toshkent kuni bo‘yicha hisoblanadi, ustma-ust sessiyalar bir vaqtni takror qo‘shmaydi. Yangi hisob tasdiqlangan o‘quv faolligidan keyin ketma-ket kun hisobini boshlaydi. |
| Veb interfeysi | Bosh sahifa, kirish va tiklash, fanlar, onboarding, diagnostika, bilim xaritasi, reja, dars, mustahkamlash, Yo‘lchi, natijalar va profil umumiy navigatsiya hamda vizual tizimga o‘tdi. `src/presentation/components/` ichida umumiy sahifa sarlavhasi, holat bloklari, avatar, tugma, parol maydoni, halqali progress va klaviatura fokusli dialog ishlatiladi. |
| Admin | `src/features/admin/AdminDashboardView.tsx` umumiy dialog va forma yorliqlaridan foydalanadi. `src/data/services/AdminContentService.ts` fan turini bazaga yozadi va sozlangan rejimdagi server xatosida namuna katalogini ko‘rsatmaydi. O‘quvchining CMS yozuvlari va javob kalitlariga kirishi cheklangan. |
| Flutter | `mobile/lib/app/providers.dart` server diagnostikasi va qisman profil yangilanishidan foydalanadi. Bosh sahifa, fan tanlash va diagnostika yangilandi. Android chiqarish manifestida internet ruxsati, Android va iOS konfiguratsiyasida parolni tiklash havolasi qo‘shildi. Namuna tugmalari mahalliy rejim bilan cheklangan. |
| Paket hajmi | Veb kirish JS hajmi 464,21 kB dan 326,23 kB gacha kamaydi. Gzip hajmi 141,54 kB dan 100,09 kB gacha kamaydi. Namuna katalogi va KaTeX kerakli yo‘nalishda yuklanadi. Kirish sahifasi oldingi 861 kB tasvirni yuklamaydi. |

## Tekshirilgan holat

- `npm run typecheck`, `npm run lint`, `npm test`, `npm run build` va `npm run test:e2e` bajarildi. 36 fayldagi 231 Vitest testi o‘tdi. Lint avvaldan mavjud `AuthContext.tsx` Fast Refresh ogohlantirishini qaytardi.
- Playwright namuna oqimi kurs va dars ajratilishi, savol, dars yakuni, Yo‘lchi suhbat tarixi, klaviatura fokusi, mobil navigatsiya va brauzerning orqaga qaytishini tekshirdi. 360, 390, 768, 1024, 1440 va 1920 piksellarda jami 60 ta maket tekshiruvi o‘tdi.
- Alohida mahalliy muhitdagi GoTrue, PostgreSQL 17.11, PostgREST, Mailpit va Deno bilan ro‘yxatdan o‘tish, kurs va sessiyani tiklash, darsdan 22 XP, to‘liq diagnostika, shaxsiy reja, profil sozlamalari, parolni tiklash, boshqa hisob izolyatsiyasi va admin fan yaratishi sinovdan o‘tdi. Yo‘lchi uchun provayder mavjud bo‘lmagandagi xabar va qayta urinish tekshirildi.
- Toza mahalliy bazada 23 migratsiya va boshlang‘ich ma’lumotlar o‘rnatildi. Beshta SQL regressiya fayli o‘tdi. Yo‘lchi Edge Function `deno check --no-lock` tekshiruvidan o‘tdi.
- Flutter SDK’ning ajratilgan Supabase sinovi real foydalanuvchi, to‘rt savolli Mantiq diagnostikasi, pochta orqali PKCE kodi va yangi parol bilan qayta kirishni tasdiqladi.
- `flutter analyze` ogohlantirishsiz yakunlandi. Standart to‘plamdagi 71 test va alohida ishga tushirilgan bitta Supabase integratsiya testi o‘tdi. `flutter build apk --release` 52,8 MB sinov paketini yaratdi.

## Chiqarish shartlari va qolgan tekshiruvlar

- Hostingdagi `bilimyol-staging` Supabase loyihasi tekshiruv vaqtida `INACTIVE` edi. Mahalliy Supabase sinovi hostingdagi ishga tushirishni almashtirmaydi. Gemini kaliti sozlangan sinov muhitida haqiqiy model javobi, kvota va mavzuga mos tushuntirish sifatini tekshirish qolgan.
- Tashqi chiqarishda `20261107114341_secure_placement_sessions.sql` gacha migratsiya qilinadi. Veb va mobil mijozlar `advance_placement` ga o‘tgandan keyin `20261107121558_retire_legacy_placement_access.sql` qo‘llanadi. Eski APK diagnostikasi ikkinchi bosqichdan keyin yangilanishi kerak.
- Mobil pochta havolasi uchun Supabase Auth ruxsat etilgan yo‘nalishlariga `uz.bilimyol.mobile://auth/reset-password` kiritiladi. Mahalliy SDK sinovi haqiqiy PKCE kodini shu URI’ga uzatadi. Android emulyatori tizim darajasida beqaror bo‘lgani uchun to‘liq qurilma UI oqimi, iOS havolasi va do‘kon imzosi alohida tekshiriladi. [Supabase mobil havolalari](https://supabase.com/docs/guides/auth/native-mobile-deep-linking?platform=flutter)
- 12 ta mavzu boshlang‘ich o‘quv yo‘lini qamrab oladi. 5–11-sinflar bo‘yicha to‘liq o‘quv dasturi hamda Gemini yaratgan kontentning pedagogik tekshiruvi ushbu bosqichdan keyingi ish.

## 2026-11-08 — Jonli AI ulanishi

- `jlqbenwojcgbloamfyis` loyihasi `ACTIVE_HEALTHY`, `yolchi-tutor` 9-versiyasi `ACTIVE`. Jonli funksiyaning avvalgi API shartnomasi saqlanib, serverdagi `AI_BASE_URL`, `AI_MODEL`, `AI_API_KEY` bilan OpenAI-compatible transport ulangan. Model `claude-sonnet-4-6`.
- Provayderning haqiqiy API sinovi va ilovadan ajratilgan transport sinovi o‘zbekcha JSON javob qaytardi. Jonli endpoint sayt originiga OPTIONS 200 va sessiyasiz POST 401 qaytardi. Haqiqiy foydalanuvchi sessiyasi bilan jonli chat javobi hali tasdiqlanmadi. Brauzerda kirish sahifasi ochiq, foydalanuvchi kirishi talab qilinadi. Sun’iy `example.com` sinov hisobini odatiy ro‘yxatdan o‘tkazish email tekshiruvida rad etildi, autentifikatsiya chetlab o‘tilmadi.
- Jonli bazaga mos mobil paket Git HEAD `34ed661` asosidan vaqtinchalik katalogda yig‘ildi. Internet ruxsati qo‘shildi, kirish boshlang‘ich sahifa qilindi va sozlangan backend ishga tushmasa router autentifikatsiya talab qiladi. Ishchi katalogdagi yangi curriculum va diagnostika migratsiyalari ushbu chiqarishda production’ga qo‘llanmadi.
- Shu mobil manbada `flutter analyze` muammosiz tugadi. Yangi kirish xulqiga moslashtirilgan smoke test bilan 69 ta test o‘tdi. `flutter build apk --release` muvaffaqiyatli yakunlandi. APK 52,8 MB, lokal Android Debug sertifikati bilan imzolangan. Qurilmada o‘rnatish va akkaunt bilan mobil AI so‘rovi tekshirilmagan.
- `artifacts/releases/20261108/BilimYol-live.apk` haqiqiy Supabase manzilini o‘z ichiga olishi va maxfiy Vyce AI kaliti native kutubxonalarda yo‘qligi tekshirildi. SHA256 `93BC4FC45AC62352FA7524D699C078DFCDE765458A5AAD8F22BEAF60B8CDF012`.
- Qayta yig‘ish uchun aynan shu manba va ommaviy Supabase sozlamalari `artifacts/releases/20261108/mobile-live-source.zip` ichida saqlangan. Buyruq `flutter build apk --release --dart-define-from-file=production-defines.json`. Serverning maxfiy AI kaliti arxivga kiritilmagan.

## 2026-11-08 — Jonli kirish va ro‘yxatdan o‘tish tuzatishi

Joriy tasdiqlangan nuqsonlar:
- Supabase Auth signup `over_email_send_rate_limit` (429); mavjud 3 hisobning emaili tasdiqlanmagan. SMTP ulanmagan; standart yuboruvchi oddiy mijozlarga xizmat qilish uchun mos emas.
- Jonli `Site URL` noto‘g‘ri `http://localhost:3000`, allowlist esa faqat eski preview URL edi. Jonli sayt va `/reset-password` uchun aniq URLlar saqlandi. Email confirmation o‘chirilmagan, hisoblar qo‘lda tasdiqlanmagan.
- Ishlab turgan `34ed661` routeri `isAuthLoading` vaqtida login/register formalarini unmount qilgan. Server xatosi, email, parol va signup confirmation holati yo‘qolgan. Haqiqiy invalid-credentials so‘rovi bilan brauzerda qayta hosil qilindi; auth formalarini saqlash bilan tuzatildi. Zamonaviy working-tree routerida bu guard allaqachon workspace sahifalarigagina tegishli.

Chiqarilgan o‘zgarishlar:
- Vercel dpl_Dv7RGsTACHRtSGSXyQL3c5Uam6tS production domeniga promote qilindi.
- Manba: `34ed6619bfe54cd29098e960b9a92107782ef873` ustiga faqat auth hotfix. Aniq fayllar `artifacts/releases/20261108/auth-hotfix/` ichida. To‘liq working tree va kutilayotgan SQL migratsiyalar deploy qilinmagan.
- O‘zbekcha provider xatolari, tasdiqlash xatini qayta so‘rash, muvaffaqiyatsiz resend uchun rost xabar va 60 soniya kutish; registerda eskirgan refreshProfile closure o‘rniga signUp authoritative natijasi ishlatiladi.
- Working-tree web ham shu xabar/resend bilan yangilandi. Mobile manbasida kirish, signup, reset xatolari mahalliylashtirildi; ushbu mobil o‘zgarishlar oldingi APKga hali kiritilmagan.

Tekshiruv:
- Working tree: npm run typecheck PASS; npm run lint PASS, bitta mavjud React fast-refresh ogohlantirishi; npm test 234/234 PASS.
- Ajratilgan jonli hotfix: npm run build va Vercel remote build PASS. Bundle hajmi ogohlantirishi saqlanadi.
- `node tests/e2e/auth-form-regression.mjs`: 3 holat PASS. Faqat localhost, Auth javoblari test fixture: login/unconfirmed + resend limit, signup email limit va input saqlanishi, confirmation holati. SMTP yetkazilishi bu testlarga kirmaydi. Dastlab fixture API-versiya headerini browserga expose qilmagani uchun ikki sinov timeout bo‘ldi; fixture haqiqiy SDK protokoliga moslangach uchalasi o‘tdi.
- flutter analyze PASS; flutter test test/features/auth_flow_test.dart 2/2 PASS (bu testlar haqiqiy SMTP/signup E2E emas).
- Haqiqiy pochta yetkazilishi, foydalanuvchining muvaffaqiyatli login/signup va login ortidagi jonli AI end-to-end HALI TEKSHIRILMAGAN. Pochta xizmati va jo‘natuvchi domen/hisob sozlanishi kerak. Foydalanuvchida hozir SMTP/Resend hisobi yo‘q; domen haqidagi javob kutilmoqda.

## 2026-11-08 — Tasdiqlangan hisob bilan jonli AI va arxitektura tekshiruvi

- **Jonli web PASS.** Resend orqali yuborilgan tasdiqlash xatining havolasi sinov o‘quvchisini haqiqiy Supabase sessiyasiga kiritdi. Yo‘lchi AI sahifasida 3/4 + 1/8 so‘rovi 7/8 natijasini va umumiy maxraj sababini o‘zbekcha tushuntirdi. Serverning `askTutor` auditi HTTP 200 va 42 050 ms ko‘rsatdi. Xuddi shu funksiyada javob AI tomonidan ishlab chiqarilgani belgilangandagina web ekrani `ONLINE` holatiga o‘tadi. Sinov oxirida hisobdan chiqildi.
- **Yuqori — backend vakolati.** Jonli `public.provision_missing_profiles()` `SECURITY DEFINER` bilan barcha yetishmayotgan profillarni yozadi. `has_function_privilege` tekshiruvida `anon` ham, `authenticated` ham uni chaqirishga ruxsatli. Funksiya chaqirilmadi. Tuzatish `supabase/migrations/20261106143239_harden_tutor_and_learning_activity.sql` da mavjud, jonli bazaga hali qo‘llanmagan.
- **Yuqori — AI konteksti.** Jonli `yolchi-tutor` v9 JWT va Supabase foydalanuvchisini tekshiradi, lekin `askTutor` ball va mavzuni so‘rov tanasidan oladi, ball yo‘q bo‘lsa 50% deb taxmin qiladi. `diagnose_mistake` savol identifikatori bo‘yicha xizmat roli orqali javobni o‘qiydi va o‘quvchining topshirilgan urinishini bu nuqtada tekshirmaydi. `src/` va Flutter serverga ulanadi, ammo ishonchli pedagogik kontekst hamda barqaror limit uchun `supabase/functions/yolchi-tutor/index.ts` va uning migratsiyasi birga tekshirilishi kerak.
- **O‘rta — jonli suhbat va tezlik.** Yo‘lchi AI → Profil → Yo‘lchi AI navigatsiyasi oldingi savol va javobni yo‘qotdi. Ishchi nusxa suhbatni hisob va fan kesimida saqlaydi. Jonli frontend `ONLINE // GEMINI` matnini qattiq belgilagan, bu provayderni aniqlash uchun dalil emas. Sinovda server javobi 42 soniya oldi.
- **Ajratish va migratsiyalar.** Jonli profil, o‘quvchi profili va dars urinishlarida RLS yoqilgan, egaga bog‘langan siyosatlar mavjud. `authenticated` roli `questions.correct_index` ustunini to‘g‘ridan-to‘g‘ri o‘qiy olmaydi. To‘liq foydalanuvchilararo RLS testini bu bosqich tasdiqlamaydi. Jonli migratsiya tarixi `20261018000001` da, oltita noyabr migratsiyasi ishchi nusxada. Zamonaviy kodni shu sxemaga bevosita chiqarish moslikni buzishi mumkin.
- **Ishchi nusxa tekshiruvlari.** TypeScript PASS, Vitest 234/234 PASS. `flutter analyze` PASS, `flutter test` 71 PASS, lokal Supabase va Mailpit talab qiluvchi 1 integratsiya sinovi o‘tkazilmadi. ADB’da qurilma yo‘q edi, Android APK orqali jonli AI va dars generatsiyasi sinovdan o‘tmadi.

## 2026-11-08 — O‘quvchi yo‘lini qayta qurish

`main` dagi mavjud o‘zgarishlar ustida ishlandi. Jonli versiya, ishchi nusxa va mahalliy Supabase sxemasi alohida tekshirildi. Jonli saytga kirishda avval forma chiqardi, bosh sahifada fan tanlash, statistika, reklama va darsni boshlash bir-biri bilan raqobat qilardi. Ishchi nusxada ham fan katalogidan tanlash va bosh sahifadan tanlash ikki xil keyingi qadamga olib borardi. Sahifani qayta yuklashda darsning o‘qish qadami yo‘qolar, dars ichidagi AI yordami faqat xato javobdan so‘ng ochilardi.

| Qism | Yangi oqim | O‘zgargan fayllar |
| --- | --- | --- |
| Kirish | Tanishuv → hisob yaratish yoki kirish → profil tayyor bo‘lgach fan katalogi yoki shaxsiy bosh sahifa. Yangi o‘quvchiga birinchi fan avtomatik tanlanmaydi. | `src/features/auth/WelcomeView.tsx`, `LoginView.tsx`, `RegisterView.tsx`, `src/app/router/AppRouter.tsx`, `mobile/lib/features/auth/welcome_screen.dart`, `mobile/lib/app/router.dart` |
| Navigatsiya va fan | Bosh sahifa, ta’lim yo‘li, Yo‘lchi, natijalar va profil. Fan konteksti alohida almashadi. Bitta tanlov saqlanadi, keyin tanlangan fan uchun rejaga yoki davom etishga o‘tiladi. | `src/presentation/components/Navbar.tsx`, `src/app/store/useCourseStore.ts`, `src/features/course-selection/CourseSelectionView.tsx`, `mobile/lib/core/widgets/bilimyol_bottom_nav.dart`, `mobile/lib/features/course_selection/course_selection_screen.dart`, `mobile/lib/app/providers.dart` |
| Reja va bosh sahifa | Daraja asosiy tanlov, maqsad va vaqt ixtiyoriy sozlama. Bosh sahifada bitta davom etish amali, amaldagi fan darslari natijasi, yordam va reja bor. Keyingi darsni tanlash qoidasi reja, bosh sahifa va boshqa ekranlarda umumiy. | `src/features/onboarding/OnboardingView.tsx`, `src/features/dashboard/DashboardView.tsx`, `src/app/router/lessonResolution.ts`, `mobile/lib/features/dashboard/dashboard_screen.dart` |
| Ta’lim yo‘li va dars | Bog‘langan bosqichlar, boshlang‘ich darslarning haqiqiy tartibi, joriy va tugallangan holatlar. Darsda asosiy navigatsiya yashiriladi, yakunlashdan keyin yo‘l ochiladi. Web o‘qish qadami hisob, fan va dars bo‘yicha brauzer tabida saqlanadi. Qayta yuklashda server tasdiqlamagan javoblar tiklanmaydi. | `src/features/roadmap/RoadmapView.tsx`, `src/features/lesson/InteractiveLessonView.tsx`, `readingPosition.ts`, `LessonCompletionModal.tsx`, `src/index.css`, `mobile/lib/features/lesson/interactive_lesson_screen.dart` |
| Yo‘lchi va lug‘at | Dars ichidan fan va ko‘nikma konteksti bilan yordam ochiladi. Yopilganda dars va tanlangan javob joyida qoladi. Inglizcha lug‘at bitta so‘zni Free Dictionary API’ga yuboradi, ta’rif yoki aniq xato holatini ko‘rsatadi. | `src/features/ai-tutor/YolchiAIChatView.tsx`, `src/features/dictionary/DictionaryLookup.tsx`, `mobile/lib/features/ai_tutor/ai_tutor_screen.dart`, `mobile/lib/data/services/i_ai_tutor_service.dart`, `supabase_ai_tutor_service.dart`, `mobile/lib/features/lesson/dictionary_sheet.dart`, `mobile/pubspec.yaml`, `mobile/pubspec.lock` |

Profil sozlamalari, natijalar hisoboti, admin sahifasi va mavjud Supabase shartnomalari saqlandi. Bu bosqichda yangi migratsiya kerak bo‘lmadi. Ishchi nusxada avvaldan mavjud oltita migratsiya jonli versiya bilan moslik uchun hali sinovdan chiqarish tartibini talab qiladi. Git commit, push va jonli deploy qilinmadi.

Vizual taqqoslash `artifacts/reconstruction/` katalogida: `before-welcome-{390,1440}.png`, `after-welcome-{390,1440}.png`, `before-learn-{390,1440}.png`, `after-learn-{390,1440}.png`, `ilk-ingliz-darsi-390.png` va `dictionary-live.png`. Bir xil viewport kengligida olingan, dars natijalari sinov bosqichiga qarab farq qiladi. Keyingi tekshiruvlar uchun `.agents/skills/bilimyol-journey-qa/SKILL.md` qo‘shildi va validatsiyadan o‘tdi.

## 2026-11-09 — Jonli veb interfeysi

- Vercel’dagi `dpl_2EXyFLvqweNEGB3oohaUcnrsBNza` yig‘ilmasi jonli manzilga ulandi. U `34ed661` bazasidagi autentifikatsiya tuzatishlari bilan yangi tanishuv, navigatsiya, bosh sahifa, fan katalogi va o‘rganish rejasini birlashtiradi. `artifacts/releases/20261109/web-ui/source-overlay.zip` ichida bazaviy commitga qo‘shilgan 19 ta manba va sinov fayli bor.
- Jonli Supabase’da oxirgi migratsiya `20261018000001`. Yangi diagnostika va boshlang‘ich darslar mahalliy yangi sxemaga bog‘liq. Jonli versiya katalog va natijalarni mavjud xavfsiz ko‘rinishdan oladi. Fanda dars chop etilmagan bo‘lsa, Yo‘lchi yordamini taklif qiladi. Boshlang‘ich daraja tanlanganda diagnostika majburiy ochilmaydi.
- Ishlab chiqarish buildi va statik fayllarni maxfiy qiymatlar bo‘yicha tekshirish o‘tdi. Playwright jonli saytda 1440 va 390 piksellarda tanishuv, kirish, ro‘yxatdan o‘tish, parolni tiklash sahifalari, namuna hisobi, fan tanlash va Yo‘lchi sahifasini ochdi. Auth xizmati ataylab noto‘g‘ri hisob ma’lumotiga kutilgan javobni qaytardi. Ekran tasvirlari `artifacts/releases/20261109/web-ui/` katalogida.
