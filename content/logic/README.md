# Mantiq kursi

Boshlang‘iç mantiq kursi kundalik vaziyatlardan boshlanadi. Har bosqiç ikkita 6–8 daqiqalik darsdan iborat.

| Bosqiç | Darslar | Kuzatiladigan natija |
| --- | --- | --- |
| 1. Mulohaza | Rost va yolg‘on gaplar, mulohazani inkor qilish | Tekshiriladigan gapni ajratish va inkorini tuzish |
| 2. Bog‘lovchilar | Va yoki, agar va unda | Ikki shartdan tuzilgan fikrni tekshirish |
| 3. Xulosa | Teskari xulosa, qarshi misol | Qaysi xulosa majburiyligini aniqlash va umumiy da’voni sinash |
| 4. Dalil | Dalil xaritasi, dalilning chegarasi | Da’voni dalildan farqlash va xulosani dalilga mos chegaralash |
| 5. Qonuniyat | Ketma-ketlik, bir nechta qoida | O‘zgarishni topish va raqobatdosh qoidalarni yangi ma’lumot bilan ajratish |
| 6. Tatbiq | Cheklovli jadval, yakuniy tekshiruv | Dalil, shart va qarshi misolni yangi vaziyatda birga qo‘llash |

Har darsda qisqa vaziyat, ishlangan rangli misol, ikki faol savol va mustahkamlash uchun boshqa kontekst mavjud. Savollar javobdan keyin fikrni izohlaydi. Keyingi bosqiçlarda avvalgi tushunchalar yangi vaziyatda qaytadi. Bu dars ichida va darslar orasida eslab qo‘llashdir. Taqvim bo‘yicha majburiy oraliq belgilanmagan.

## Kontent va progress

`curriculum.json` bosqiçlar, darslar va savollarning asosiy manbasi. Generator undan Web demo, Flutter demo va Supabase migratsiyasi uchun bir xil tarkib yaratadi. Oltita diagramma bitta rang palitrasiga asoslanadi va rasm alt matni bilan beriladi.

Mavjud kurs, ko‘nikma, dars va xarita identifikatorlari saqlanadi. Yangi savollar yangi identifikator oladi. Avval tugallangan darslar saqlanadi. Yöl xaritasi mavjud prerequisite mexanizmidan, javoblar Supabase baholash yo‘lidan foydalanadi. Diagnostika va kurs progressi o‘z mavjud yozuvlarida qoladi.

## Metodika manbalari

- [IES — ishlangan misollarni mustaqil masalalar bilan navbatlashtirish va grafikni matn bilan birga berish](https://ies.ed.gov/ncee/WWC/Docs/PracticeGuide/20072004.pdf)
- [Retrieval practice enhances learning in real primary school settings, 2025](https://doi.org/10.3389/fpsyg.2025.1632206)
- [After initial acquisition, problem-solving leads to better long-term performance than example study, 2024](https://doi.org/10.1016/j.learninstruc.2024.102027)
- [Cullen va boshqalar — argumentlarni grafik tasvirlash bo‘yicha kvazi-eksperiment](https://doi.org/10.1038/s41539-018-0038-5)

Yuqoridagi ishlar dars tuzilishiga asos bo‘ldi. BilimYöl kursining samarasi alohida o‘lchanadi.
