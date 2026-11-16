# Matematika piloti

Matematika diagnostikasi avval o‘rta darajadagi qavs kvadratidan boshlangan. Bitta to‘g‘ri javob shu ko‘nikma uchun keyingi savol qiyinligini oshirgan. Yo‘l xaritasi esa dars tugallanganini tayanch ko‘nikma egallanganiga tenglashtirgan. Avvalgi server qoidasida bitta savolli dars uchun bitta to‘g‘ri javob yetarli edi.

## O‘quv yo‘li

Qo‘shish va ayirish → teng guruhlar → harfli ifodalar → chiziqli tenglamalar → funksiyalar → grafiklar. Qavs kvadrati harfli ifodalardan keyin ochiladigan ixtiyoriy mashq.

- To‘rtta boshlang‘ich diagnostika savoli qo‘shish va ko‘paytirish dalilini alohida saqlaydi. Darsning ochilishi dars ichidagi javoblarga bog‘liq.
- Har bir maqsadda amalda qo‘llash va xotiradan qayta qo‘llash bosqichlari bor. Boshlang‘ich siyosat ikkala bosqichda to‘g‘ri dalil, kamida 5 ta alohida savol va kamida 80% aniqlik talab qiladi. Qoidani migratsiyadagi `bilimyol_private.math_pilot_policy` belgilaydi.
- Ikki yoki undan ko‘p savolda zaif natija chiqsa, yo‘l xaritasi mashqni tavsiya qiladi. Ishlangan misol va tayanch darslarda yo‘naltirilgan mashq bor. 7 kundan keyin xotiradan qayta qo‘llash tavsiya qilinadi. Vaqtning o‘zi egallangan mavzuni yopmaydi. Yangi javoblar aniqlikni chegaradan tushirsa, mavzu qayta mashqqa o‘tadi.
- Avval saqlangan dars yakunlari va XP tarixda hisobga olinadi. Eski yakunlar hozirgi tekshiruv dalillari yetarli bo‘lmaganda qayta mashq sifatida ko‘rinadi.
- Yo‘lchi AI ochiq darsdagi maqsadga mos tushuntiradi. Pilot mashqlari tahrirlangan bankdan olinadi. Yo‘lchi AI javobining ta’lim yo‘lini o‘zgartiradigan yozish huquqi yo‘q.

## Tahrir va media

Matematika darslari uchun savollar, misollar va media ssenariysi shu pilot uchun yozildi. [Manbalar katalogi](sources.json), [IES amaliy qo‘llanmasi](https://ies.ed.gov/ncee/wwc/PracticeGuide/1)

[Qo‘shish va ayirish ssenariysi](addition-media.json) 40 soniyalik ovoz matni va to‘rtta sahna tavsifini o‘z ichiga oladi. `node scripts/prepare-lesson-media.mjs` matn va WebVTT subtitrlarini `artifacts/math-pilot/media/` ichiga tayyorlaydi.

Yozuv tayyor bo‘lgach, ovozning talaffuzi, tasvir, transkript va subtitr vaqtlarini tekshiring. Tayyor faylni `public/lesson-media/` ichiga, tasdiqlangan media obyektini esa tegishli darsning `steps` qatoriga joylashtiring. Web pleyer `approved` holati, mavjud fayl yo‘li, til, davomiylik va transkriptni talab qiladi. Video uchun WebVTT ham kerak. Darsga qaytilganda brauzer media ijrosi to‘xtagan joyni tiklaydi. O‘zlashtirish dalili baholangan mashqlardan olinadi.

## Sinov va chiqarish

Mahalliy PostgreSQL regressiyasi tayanch diagnostikadan baholash, saqlash, yo‘l ochilishi va takrorlashgacha bo‘lgan A–G holatlarni tekshiradi. Supabase brauzer va Flutter integratsiya sinovlarini ishlatish shartlari [sinov qo‘llanmasida](../../supabase/tests/README.md).

Masofadagi sinov relizi uchun migratsiya, `yolchi-tutor` va yangilangan web hamda Flutter mijozlari bir to‘plam sifatida tekshiriladi. Server eski mijozlardan kelgan yopiq dars so‘rovlarini ham rad etadi. Qayta baholash hozir bir xil ko‘rib chiqilgan savollar bankidan foydalanadi. Parallel savol variantlari, usullarni taqqoslash tahlili va Flutter ilovasida media ijrosi keyingi bosqichda.
