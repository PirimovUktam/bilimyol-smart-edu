# BILIMYO‘L SMART EDU — ADMIN ROLE & BOOTSTRAP SYSTEM AUDIT

## 1. Joriy Holat Tahlili (Current Architecture Audit)

### 1.1 Mavjud Rollar va Auth Tizimi
* `public.profiles.role` ustunida rollar saqlanadi (`student`, `parent`, `teacher`, `admin`).
* `handle_new_user()` triggeri orqali ro‘yxatdan o‘tishda foydalanuvchiga faqat `student` yoki `parent` roli beriladi.
* `profiles.role` ustuni PostgreSQL `CHECK (role IN ('student', 'parent', 'teacher', 'admin'))` cheklovi bilan himoyalangan.

### 1.2 Aniqlangan Bo‘shliqlar va Xavflar (Identified Gaps & Security Risks)
1. **Birinchi Adminni Yaratish Mexanizmi Yo‘qligi:**
   * Ro‘yxatdan o‘tishda `admin` roliga to‘g‘ridan-to‘g‘ri o‘tish imkoni yo‘q (bu xavfsizlik uchun to‘g‘ri).
   * Lekin yangi deploy qilingan ishlab chiqarish (production) muhitida birinchi adminni xavfsiz bootstrap qilish uchun standartlashtirilgan, bir martalik (one-time) va xavfsiz server mexanizmi kerak.
2. **Teacher Invitation Boshqaruvi Ruxsatlari:**
   * `create_teacher_invitation`, `list_teacher_invitations`, `revoke_teacher_invitation` funksiyalari faqat `role = 'admin'` bo‘lgan foydalanuvchilarga xizmat ko‘rsatishi shart.
3. **Admin Dashboard va Yo‘naltirish (Route Guards):**
   * `/admin` sahifasi faqat `admin` roli uchun ochilishi, boshqa barcha rollar (`student`, `parent`, `teacher`) uchun "Kirish taqiqlangan" (Access Denied) bilan to‘silishi kerak.
4. **Xizmat Kalitlari (Service Role Key) Xavfsizligi:**
   * `service_role` kaliti hech qachon mijoz (frontend/mobile) kodiga yoki ommaviy repoga yozilmasligi lozim.

---

## 2. Xavfsiz Bootstrap Modeli (Target Bootstrap Architecture)

### 2.1 Bir Martalik Xavfsiz RPC (`claim_first_admin_role`)
* **Birinchi admin tekshiruvi:**
  Agar tizimda hali birorta ham `admin` mavjud bo‘lmasa (`SELECT COUNT(*) FROM profiles WHERE role = 'admin' = 0`), autentifikatsiyadan o‘tgan birinchi qonuniy egasiga `admin` roli beriladi.
* **Qayta ishlatishni taqiqlash:**
  Agar tizimda kamida 1 ta admin mavjud bo‘lsa, keyingi har qanday bootstrap so‘rovi rad etiladi (`DENY: Bosh administrator allaqachon mavjud`).
* **Qo‘shimcha Administratorlar:**
  Keyingi adminlar faqat mavjud Admin tomonidan admin konsolidan tayinlanishi mumkin.

### 2.2 Server-Side CLI / SQL Bootstrap Usuli
* Ishlab chiqarish muhitida Supabase SQL Editor yoki `scripts/bootstrap-admin.sql` orqali to‘g‘ridan-to‘g‘ri ma'lum email egasini adminga ko‘tarish:
  ```sql
  SELECT public.promote_user_to_admin('admin@bilimyol.uz');
  ```

---

## 3. Test Rejasi (Security & Integration Test Matrix)
* **1. Ochiq ro‘yxatdan o‘tish:** `role=admin` yuborilsa ham server faqat `student` berishi.
* **2. Ruxsatsiz `/admin` yo‘li:** Student, Parent, Teacher rollari uchun `DENY`.
* **3. Bir martalik bootstrap:** Birinchi admin tayinlangach, keyingi chaqiruvlar xato berishi.
* **4. Teacher Invitation boshqaruvi:** Faqat Admin yangi kod yarata olishi, ko‘ra olishi va bekor qila olishi.
* **5. Regressiya:** Student, Parent, Teacher, Placement, Scoring va AI Tutor tizimlari to‘liq ishlashda davom etishi.
