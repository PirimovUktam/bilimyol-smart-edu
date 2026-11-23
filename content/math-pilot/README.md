# Matematika piloti

Matematika diagnostikasi avval örta darajadagi qavs kvadratidan boşlangan. Bitta töğri javob şu könikma uçun keyingi savol qiyinligini oşirgan. Yöl xaritasi esa dars tugallanganini tayanç könikma egallanganiga tenglaştirgan. Avvalgi server qoidasida bitta savolli dars uçun bitta töğri javob yetarli edi.

## Öquv yöli

Qöşiş va ayiriş → teng guruhlar → harfli ifodalar → çiziqli tenglamalar → funksiyalar → grafiklar. Qavs kvadrati harfli ifodalardan keyin oçiladigan ixtiyoriy maşq.

- Törtta boşlanğiç diagnostika savoli qöşiş va köpaytiriş dalilini alohida saqlaydi. Darsning oçilişi dars içidagi javoblarga boğliq.
- Har bir maqsadda amalda qöllaş va xotiradan qayta qöllaş bosqiçlari bor. Boşlanğiç siyosat ikkala bosqiçda töğri dalil, kamida 5 ta alohida savol va kamida 80% aniqlik talab qiladi. Qoidani migratsiyadagi `bilimyol_private.math_pilot_policy` belgilaydi.
- Ikki yoki undan köp savolda zaif natija çiqsa, yöl xaritasi maşqni tavsiya qiladi. Işlangan misol va tayanç darslarda yönaltirilgan maşq bor. 7 kundan keyin xotiradan qayta qöllaş tavsiya qilinadi. Vaqtning özi egallangan mavzuni yopmaydi. Yangi javoblar aniqlikni çegaradan tuşirsa, mavzu qayta maşqqa ötadi.
- Avval saqlangan dars yakunlari va XP tarixda hisobga olinadi. Eski yakunlar hozirgi tekşiruv dalillari yetarli bölmaganda qayta maşq sifatida körinadi.
- Yölçi AI oçiq darsdagi maqsadga mos tuşuntiradi. Pilot maşqlari tahrirlangan bankdan olinadi. Yölçi AI javobining ta’lim yölini özgartiradigan yoziş huquqi yöq.

## Tahrir va media

Matematika darslari uçun savollar, misollar va media ssenariysi şu pilot uçun yozildi. [Manbalar katalogi](sources.json), [IES amaliy qöllanmasi](https://ies.ed.gov/ncee/wwc/PracticeGuide/1)

[Qöşiş va ayiriş ssenariysi](addition-media.json) 40 soniyalik ovoz matni va törtta sahna tavsifini öz içiga oladi. `node scripts/prepare-lesson-media.mjs` matn va WebVTT subtitrlarini `artifacts/math-pilot/media/` içiga tayyorlaydi.

Yozuv tayyor bölgaç, ovozning talaffuzi, tasvir, transkript va subtitr vaqtlarini tekşiring. Tayyor faylni `public/lesson-media/` içiga, tasdiqlangan media obyektini esa tegişli darsning `steps` qatoriga joylaştiring. Web pleyer `approved` holati, mavjud fayl yöli, til, davomiylik va transkriptni talab qiladi. Video uçun WebVTT ham kerak. Darsga qaytilganda brauzer media ijrosi töxtagan joyni tiklaydi. Özlaştiriş dalili baholangan maşqlardan olinadi.

## Sinov va çiqariş

Mahalliy PostgreSQL regressiyasi tayanç diagnostikadan baholaş, saqlaş, yöl oçilişi va takrorlaşgaça bölgan A–G holatlarni tekşiradi. Supabase brauzer va Flutter integratsiya sinovlarini işlatiş şartlari [sinov qöllanmasida](../../supabase/tests/README.md).

Masofadagi sinov relizi uçun migratsiya, `yolchi-tutor` va yangilangan web hamda Flutter mijozlari bir töplam sifatida tekşiriladi. Server eski mijozlardan kelgan yopiq dars sörovlarini ham rad etadi. Qayta baholaş hozir bir xil körib çiqilgan savollar bankidan foydalanadi. Parallel savol variantlari, usullarni taqqoslaş tahlili va Flutter ilovasida media ijrosi keyingi bosqiçda.
