# BILIMYO‘L SMART EDU — ROLE, ACCESS CONTROL & MONITORING AUDIT

## 1. Topilgan Muammolar va Root Cause Tahlili

### Muammo 1: STUDENT foydalanuvchiga Ota-ona va O‘qituvchi tablari ko‘rinishi
* **Joylashuvi:** [Navbar.tsx](file:///d:/projects/Bilimyol/src/presentation/components/Navbar.tsx#L85-L125) va [useMonitoringStore.ts](file:///d:/projects/Bilimyol/src/app/store/useMonitoringStore.ts#L45-L65).
* **Root Cause:** Navbar komponentida mijoz tarafdagi oddiy `switchRole` funksiyasiga ulangan `[O‘quvchi | Ota-ona | O‘qituvchi]` toggle tugmalari qo‘yilgan edi. Bu holatda tizimga kirgan istalgan `student` roli ushbu tugmalarni bosib, `useMonitoringStore.currentRole` ni sun'iy ravishda `'parent'` yoki `'teacher'` ga o‘zgartirishi va ularning dashboardlarini ochishi mumkin edi.
* **Xavfsizlik Xavfi (Severity: High):** Rollarning mijoz (frontend) holatiga bog‘lanib qolishi va avtorizatsiyaning buzilishi (Broken Object Level Authorization / Privilege Escalation).

### Muammo 2: O‘qituvchi panelidagi "Yangi sinf ochish" ishlamasligi
* **Joylashuvi:** [TeacherDashboardView.tsx](file:///d:/projects/Bilimyol/src/features/teacher/TeacherDashboardView.tsx#L40-L50), [SupabaseMonitoringRepository.ts](file:///d:/projects/Bilimyol/src/data/repositories/SupabaseMonitoringRepository.ts#L248-L280), [20260817000003_parent_teacher_monitoring.sql](file:///d:/projects/Bilimyol/supabase/migrations/20260817000003_parent_teacher_monitoring.sql#L330-L360).
* **Root Cause:** 
  1. `create_teacher_class` RPC funksiyasi serverda `profiles.role = 'teacher'` ekanligini qat'iy tekshirmasdan faqat `auth.uid()` ni tekshirgan. Agar foydalanuvchi student bo‘lsa, xatolik bergan yoki RLS politsiyasi sababli ma'lumotlarni o‘qiy olmagan.
  2. `TeacherDashboardView.tsx` dagi modal submit handlerida xatolik ushlanmagan (`try/catch` va `isSubmitting` yo‘qligi sababli modal xato yuz berganda jim qolgan).
  3. `useMonitoringStore.ts` dagi `createTeacherClass` funksiyasi RPC javobidagi `success` flagini tekshirmasdan to‘g‘ridan-to‘g‘ri ob'ekt kutgan.
* **Xavfsizlik Xavfi (Severity: Medium):** Noto‘g‘ri rol bilan sinf yaratishga urinish va foydalanuvchiga hech qanday tushunarli xato xabari ko‘rsatmaslik.

### Muammo 3: "Ota-onaga ulanish" va "Sinfga qo‘shilish" tugmalarining xira/disabled holatda qolishi
* **Joylashuvi:** [StudentConnectionsModal.tsx](file:///d:/projects/Bilimyol/src/features/student/StudentConnectionsModal.tsx#L125-L170), [Navbar.tsx](file:///d:/projects/Bilimyol/src/presentation/components/Navbar.tsx#L110-L130), [Button.tsx](file:///d:/projects/Bilimyol/src/presentation/components/Button.tsx#L20-L55).
* **Root Cause:**
  1. `Navbar.tsx` da "Ulanish" tugmasi `hidden sm:flex` qilib qo‘yilgan, mobil ekranlarda o‘quvchiga ko‘rinmagan.
  2. `StudentConnectionsModal.tsx` dagi form submit tugmalarida lokal `isSubmitting` holati bo‘lmagani va global `isLoading` ga bog‘lanib qolishi natijasida tugmalar so‘rovdan keyin faolsiz holatda qolib ketgan.
  3. Kod kiritish maydonida 6 ta belgi kiritilmagan bo‘lsa ham submit bo‘lishi yoki xatolik haqida yorqin xabar berilmagan.

### Muammo 4: AuthContext va Ro‘yxatdan o‘tishda Role integratsiyasi yo‘qligi
* **Joylashuvi:** [AuthContext.tsx](file:///d:/projects/Bilimyol/src/core/context/AuthContext.tsx#L5-L55), [RegisterView.tsx](file:///d:/projects/Bilimyol/src/features/auth/RegisterView.tsx#L20-L60).
* **Root Cause:**
  `AuthContext.fetchProfile()` da `role` ustuni `public.profiles` dan SELECT qilinmagan; `UserProfile` interfeysida `role` mavjud bo‘lmagan. Ro‘yxatdan o‘tishda foydalanuvchi qaysi maqsadda kirayotganini (O‘quvchi / Ota-ona / O‘qituvchi) tanlash imkoniyati bo‘lmagan, barcha foydalanuvchilar avtomatik `student` qilib qo‘yilgan.

---

## 2. Xavfsizlik va Arxitektura Yechimi

1. **Authoritative Role Model:**
   * `public.profiles.role` yagona haqiqat manbai (Single Source of Truth).
   * Ruxsat etilgan qiymatlar: `'student'`, `'parent'`, `'teacher'`.
   * Mijoz (frontend) RLS orqali to‘g‘ridan-to‘g‘ri `role` ustunini o‘zboshimchalik bilan o‘zgartira olmaydi.
2. **Server-Side Authorization (RPC & RLS):**
   * `create_teacher_class` faqat `profiles.role = 'teacher'` bo‘lganda ishlaydi.
   * `create_parent_link_code` faqat `profiles.role = 'parent'` bo‘lganda ishlaydi.
   * `join_class_by_code` va `redeem_parent_link_code` faqat `profiles.role = 'student'` bo‘lganda ishlaydi.
   * RLS politsiyalari munosabatlarga asoslangan: Parent faqat o‘z farzandini, Teacher faqat o‘z sinf a'zolarini ko‘ra oladi.
3. **Frontend Role Guard & Navigation:**
   * `Navbar.tsx` dan role switcher butunlay olib tashlanadi.
   * Foydalanuvchining autentifikatsiya qilingan roliga qarab tegishli navigatsiya menyusi ko‘rsatiladi.
   * `/parent` va `/teacher` yo‘nalishlariga kirishda `AppRouter.tsx` da qat'iy Role Guard o‘rnatiladi.
4. **Ro‘yxatdan o‘tishda Rol Tanlash:**
   * `RegisterView.tsx` da foydalanuvchi hisob turini tanlaydi: O‘quvchi, Ota-ona, O‘qituvchi.
   * Tanlangan rol `raw_user_meta_data->>'role'` orqali PostgreSQL triggerida `public.profiles.role` ga xavfsiz yoziladi.
5. **Button State Machine:**
   * Har bir modal va form tugmasida lokal `isSubmitting` holati, xatolik yuz berganda darhol qayta faollashish va aniq o‘zbekcha bildirishnomalar ta'minlanadi.

---

## 3. Yangi Migratsiya Rejasi

`supabase/migrations/20260817000004_role_access_hardening.sql`:
* `public.profiles.role` ustunini himoyalash va tekshirish.
* Server-side `create_teacher_class`, `create_parent_link_code`, `redeem_parent_link_code`, `join_class_by_code` funksiyalarini rollar bo‘yicha qat'iy avtorizatsiya qilish va collision protection qo‘shish.
* RLS politsiyalarini qayta mustahkamlash.
