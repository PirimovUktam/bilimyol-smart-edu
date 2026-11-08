---
description: Modern EdTech UI/UX Design System Rules
trigger: always_on
---

# EdTech Visual Design & UI Standards

Barcha UI ekranlar va komponentlarni yaratish yoki qayta dizayn qilishda quyidagi qoidalarga qat'iy amal qil:

1. **Zerikarlilikdan qochish (Anti-Boring UI):**
   - Hech qachon tekis kulrang fon ustida oddiy qora ramkali qutilar ishlatma.
   - Asosiy fon uchun `#F8FAFC` (Slate 50) yoki `#F4F7FE` kabi juda och, ko'zni charchatmaydigan zamonaviy tuslardan foydalan.
   - Kartochkalar foni `#FFFFFF`, chegarasi `1px solid rgba(226, 232, 240, 0.8)`, burchaklari `16px` dan `24px` gacha yumaloq va soyasi tarqoq (`0 12px 32px -4px rgba(15, 23, 42, 0.06)`) bo'lsin.

2. **Videodagi kabi Tipografik Urg'u (Highlight & Split Heading):**
   - Asosiy bo'lim sarlavhalari (`.heading` yoki Header Widget) tepasida doim kichik Pill Badge (`.highlight`: `background: rgba(79, 70, 229, 0.1)`, `color: #4F46E5`, `padding: 6px 14px`, `border-radius: 999px`, `font-weight: 600`) bo'lsin.
   - Sarlavhalarda asosiy matn `#0F172A` (to'q ko'k-qora), asosiy urg'u beriladigan kalit so'z esa aksent rangda (`#4F46E5` Indigo yoki `#10B981` Emerald) yoki gradientda ajratib ko'rsatilsin.

3. **Course & Module Card Arxitekturasi:**
   - Har bir fan, test yoki o'quv moduli kartochkasida:
     a) Yuqori qismda rangli ikonka konteyneri yoki illyustratsiya + kategoriya beydji;
     b) O'rta qismda aniq sarlavha, qisqa 2 qatorli izoh va vizual progress ko'rsatkichi;
     c) Pastki qismda meta-ma'lumotlar (darslar soni, XP/daraja) va aniq harakat tugmasi (`.commonBtn`) bo'lsin.

4. **Mikro-interaksiyalar va Animatsiya:**
   - Web uchun: AOS (Animate On Scroll) yoki Framer Motion orqali elementlar sahifada `fade-up` (`translateY(20px)` -> `0`) va `stagger` (ketma-ket `100ms` kechikish) bilan chiqsin. Kartochka ustiga borilganda `transform: translateY(-6px)` ishlashi shart.
   - Flutter uchun: `flutter_animate` yoki `AnimatedContainer` yordamida kartochkalar ekranga chiqishda `.fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0)` effekti bilan jonlansin.