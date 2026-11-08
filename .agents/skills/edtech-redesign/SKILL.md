---
name: edtech-redesign
description: Mavjud zerikarli ekran va komponentlarni zamonaviy interaktiv EdTech dizayniga (Hero, Feature, Course Cards va silliq animatsiyalar bilan) o'girish skill'i.
---

# EdTech UI Redesign Workflow

Foydalanuvchi biron bir sahifa yoki ekranni redesign qilishni so'raganda quyidagi 4 bosqichli jarayonni bajar:

## Step 1: Audit Current Screen
- Mavjud fayldagi barcha biznes mantiq (state management, API chaqiruvlar, routing, modellar) ro'yxatini tuzib ol. **Redesign vaqtida hech bir funksionallik buzilmasligi shart.**
- UI'ni zerikarli qilayotgan muammolarni aniqla (tekis matnlar, ajratilmagan sarlavhalar, animatsiyasiz ro'yxatlar, yomon spacing).

## Step 2: Apply Design Tokens & Theme
- Agar loyihada markazlashgan Theme/CSS variables fayli bo'lmasa yoki eskirgan bo'lsa, avval dizayn tokenlarini yangila:
  - **Primary Accent:** `#4F46E5` (Indigo)
  - **Secondary Accent:** `#0EA5E9` (Sky Blue) va `#10B981` (Emerald — muvaffaqiyat va progress uchun)
  - **Surface / Background:** `#F8FAFC` (Asosiy fon), `#FFFFFF` (Kartochka foni)
  - **Text Primary / Secondary:** `#0F172A` / `#64748B`
  - **Typography:** `Plus Jakarta Sans` yoki `Inter` (Sarlavhalar `700/800`, matnlar `400/500`).

## Step 3: Component-by-Component Transformation
1. **Header / Hero Section:** Oddiy AppBar yoki tepa qismni `.highlight` beydjli, ikki rangli sarlavhali (`.heading` + aksent `span`/`TextSpan`) va statistika pill'lariga ega Hero blokiga aylantir.
2. **Course / Subject Cards:** Oddiy `ListTile` yoki tekis `Card`larni ko'p qatlamli EdTech Course Card'larga o'gir (ikonka foni, daraja tegi, silliq progress bar, hover/tap scale effekti).
3. **Buttons (`.commonBtn`):** Barcha asosiy tugmalarga yumshoq soya (`0 8px 20px -4px rgba(79, 70, 229, 0.4)`), ikonka va bosilganda/hoverda silliq animatsiya qo'sh.

## Step 4: Add Motion & Verify
- Ro'yxatlar va kartochkalarga kirish (entrance) va scroll animatsiyalarini qo'sh.
- O'zgarishlardan so'ng kodda hech qanday sintaksis xato yoki UI overflow yo'qligini tekshir.