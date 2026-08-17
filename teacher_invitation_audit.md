# BILIMYO‘L SMART EDU — TEACHER INVITATION CODE SYSTEM AUDIT

## 1. Joriy Holat Tahlili (Current Implementation & Audit)

### 1.1 Mavjud Holat
* **Rol boshqaruvi:** `public.profiles.role` ustunida rollar saqlanadi (`student`, `parent`, `teacher`).
* **O‘qituvchi ro‘yxatdan o‘tishi:** O‘qituvchi sifatida hisob yaratilganda, server orqali `redeem_teacher_invitation_code` RPC chaqiriladi.
* **Mavjud cheklov:** Avvalgi migratsiyada 3 ta ochiq kod test uchun ochiq matnda (`USTOZ-2026-ALPHA`, `BILIMYO-USTOZ-77`) saqlangan edi.

### 1.2 Aniqlangan Kamchiliklar va Xavflar (Missing Components & Security Risks)
1. **Ochiq matn (Plaintext) xavfi:**
   Kodlar bazada ochiq matnda saqlansa, ma'lumotlar sizib chiqishida barcha taklif kodlari fosh bo‘ladi.
   *Yechim:* Kodlar bazada faqat kriptografik **SHA-256 xesh** (`code_hash`) va xavfsiz ko‘rinadigan prefiks (`code_prefix`, masalan `USTOZ-7K4P...`) ko‘rinishida saqlanishi kerak.
2. **Kodlarni boshqarish (Admin Management) tizimi yo‘qligi:**
   Platforma administratori yoki maktab rahbari yangi taklif kodlarini yarata oladigan, muddatini (1, 7, 30 kun) va foydalanish sonini (1, 5, 10, 50) belgilay oladigan, zarur bo‘lganda bekor qila oladigan (`revoke`) ma'muriy boshqaruv mavjud emas edi.
3. **Brute-force va Rate-limiting xavfi:**
   Hujumchi tasodifiy kodlarni millionlab marta sinab ko‘rmasligi uchun urinishlar sonini cheklovchi (`teacher_invitation_attempts` / rate limit) himoya mexanizmi talab etiladi.
4. **Tranzaksiya xavfsizligi va Race Condition:**
   Bir martalik kodga bir vaqtda 2 ta parallel so‘rov kelganda, ikkala so‘rov ham o‘tib ketmasligi uchun qator darajasidagi qulflash (`SELECT ... FOR UPDATE`) va `used_count >= max_uses` holatida statusni avtomatik `exhausted` ga o‘tkazish zarur.

---

## 2. Tavsiya Etilayotgan Arxitektura (Target Design)

### 2.1 Ma'lumotlar Bazasi Modeli (`teacher_invitation_codes`)
```sql
CREATE TABLE public.teacher_invitation_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code_hash TEXT UNIQUE NOT NULL,
  code_prefix TEXT NOT NULL,
  school_name TEXT NOT NULL DEFAULT 'BilimYo‘l Smart School',
  school_id TEXT,
  created_by UUID REFERENCES auth.users(id),
  max_uses INT NOT NULL DEFAULT 1,
  used_count INT NOT NULL DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'revoked', 'exhausted')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 2.2 Kriptografik Kod Generatsiyasi va Xavfsiz Taqdimot
* Format: `USTOZ-XXXX-YYYY` (masalan: `USTOZ-7K4P-2M9X`, 14 ta belgi, 60+ bit entropiya).
* Admin kod yaratganda to‘liq plain text kod faqat bir marta javobda qaytariladi va nusxalab olish tavsiya etiladi.
* Bazada faqat `SHA-256(UPPER(TRIM(code)))` saqlanadi.

### 2.3 Xavfsiz RPC Funksiyalari
1. `create_teacher_invitation(school_name, max_uses, validity_days)` $\to$ Faqat Admin.
2. `list_teacher_invitations()` $\to$ Faqat Admin (faqat prefiks va statistikani ko‘rsatadi).
3. `revoke_teacher_invitation(id)` $\to$ Faqat Admin.
4. `redeem_teacher_invitation_code(code)` $\to$ Har qanday autentifikatsiyadan o‘tgan foydalanuvchi; rate limit bilan himoyalangan, tranzaksiyada xeshni tekshiradi va rolni `teacher` ga ko‘taradi.

---

## 3. Test Strategiyasi (Test Plan)
* **Admin ruxsati:** Oddiy o‘quvchi/o‘qituvchi yangi kod yarata olmasligi yoki bekor qila olmasligi.
* **Xesh tekshiruvi:** `USTOZ-7K4P-2M9X` kodi to‘g‘ri xeshlangan holda tekshirilib rolni oshirishi.
* **Muddati o‘tgan (Expired) kod:** Rad etilishi.
* **Bekor qilingan (Revoked) kod:** Rad etilishi.
* **Limitiga yetgan (Exhausted) kod:** `max_uses = 1` bo‘lganda ikkinchi urinish rad etilishi.
* **Rate limit / Brute-force:** Ketma-ket 5 ta xato urinishdan so‘ng bloklash.
* **Cross-platform Web & Mobile:** Ikkala platformada bir xil RPC va xatolik matnlari.
