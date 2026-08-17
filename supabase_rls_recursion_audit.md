# BILIMYO‘L SMART EDU - SUPABASE RLS RECURSION AUDIT & FIX
**File:** `supabase_rls_recursion_audit.md`  
**Date:** 2026-08-17  
**Error Code:** PostgreSQL `42P17`  
**Error Message:** `"infinite recursion detected in policy for relation \"class_members\""`

---

## 1. Problem Description & Root Cause Analysis

When a client queries `public.profiles` (e.g. `supabase.from('profiles').select('*').eq('id', user.id)` upon login), PostgreSQL evaluated all `FOR SELECT` policies defined on `public.profiles`.

### The Recursive Loop Trace:
1. **`public.profiles` Policy:**
   ```sql
   CREATE POLICY "Teachers can read enrolled student profile"
     ON public.profiles FOR SELECT TO authenticated
     USING (
       EXISTS (
         SELECT 1 FROM public.class_members cm
         JOIN public.classes c ON cm.class_id = c.id
         WHERE c.teacher_user_id = auth.uid()
         AND cm.student_user_id = profiles.id
         AND cm.status = 'active'
       )
     );
   ```
   *To evaluate this policy, PostgreSQL queried `public.class_members`.*

2. **`public.class_members` Policy:**
   ```sql
   CREATE POLICY "Teachers can manage members in own classes"
     ON public.class_members FOR ALL TO authenticated
     USING (
       EXISTS (
         SELECT 1 FROM public.classes
         WHERE classes.id = class_members.class_id
         AND (classes.teacher_user_id = auth.uid() OR public.is_admin())
       )
     );
   ```
   *To evaluate this policy, PostgreSQL queried `public.classes`.*

3. **`public.classes` Policy:**
   ```sql
   CREATE POLICY "Students can view classes they belong to"
     ON public.classes FOR SELECT TO authenticated
     USING (
       EXISTS (
         SELECT 1 FROM public.class_members
         WHERE class_members.class_id = classes.id
         AND class_members.student_user_id = auth.uid()
       )
     );
   ```
   *To evaluate this policy, PostgreSQL queried `public.class_members` AGAIN!*

4. **Circular Lock (Infinite Recursion):**
   `profiles` $\rightarrow$ `class_members` $\rightarrow$ `classes` $\rightarrow$ `class_members` $\rightarrow$ `classes` $\rightarrow$ ...
   
   Result: **PostgreSQL runtime terminates execution with HTTP 500 / 42P17 infinite recursion error.**
   Frontend receives a 500 error on profile fetch, preventing `AuthContext` from reading `role = 'admin'`.

---

## 2. Solution Architecture: Decoupled Security Definer Helpers

Direct table joins inside RLS `USING` clauses were replaced by dedicated, atomic, `SECURITY DEFINER` helper functions marked as `STABLE` with `search_path = public, pg_temp`.

Because these functions run in a security definer context and perform isolated index lookups:
- They bypass subquery policy expansion.
- They return pure boolean authorization flags.
- They completely eliminate policy-to-policy circular recursion.

### Implemented Helper Functions:
1. `public.is_admin() -> BOOLEAN`: Checks if `auth.uid()` has `role = 'admin'` in `public.profiles`.
2. `public.is_student_in_class(p_class_id UUID, p_student_id UUID) -> BOOLEAN`: Verifies active class membership.
3. `public.is_teacher_of_class(p_class_id UUID, p_teacher_id UUID) -> BOOLEAN`: Verifies class ownership.
4. `public.is_teacher_of_student(p_teacher_id UUID, p_student_id UUID) -> BOOLEAN`: Verifies teacher-student relationship without triggering RLS on `class_members` / `classes`.
5. `public.is_parent_of_student(p_parent_id UUID, p_student_id UUID) -> BOOLEAN`: Verifies active parent-child link.

---

## 3. Policy Refactoring Summary

| Table | Old Policy Approach | New Recursion-Free Policy |
|---|---|---|
| `public.profiles` | Direct `JOIN class_members` and `JOIN classes` | `USING (public.is_teacher_of_student(auth.uid(), id))` |
| `public.profiles` | Direct `JOIN parent_student_links` | `USING (public.is_parent_of_student(auth.uid(), id))` |
| `public.profiles` (Self) | Standalone check | `USING (id = auth.uid())` (100% isolated, zero subqueries) |
| `public.classes` | `EXISTS (SELECT 1 FROM class_members ...)` | `USING (public.is_student_in_class(id, auth.uid()))` |
| `public.class_members` | `EXISTS (SELECT 1 FROM classes ...)` | `USING (public.is_teacher_of_class(class_id, auth.uid()) OR public.is_admin())` |
| `public.learning_sessions` | Cross-table joins | `USING (public.is_teacher_of_student(auth.uid(), user_id))` |
| `public.daily_learning_stats` | Cross-table joins | `USING (public.is_teacher_of_student(auth.uid(), user_id))` |
| `public.student_alerts` | Cross-table joins | `USING (public.is_teacher_of_student(auth.uid(), user_id))` |
| `public.learner_skill_scores`| Cross-table joins | `USING (public.is_teacher_of_student(auth.uid(), user_id))` |

---

## 4. Verification & Validation Checklist

- [x] Migration created: `supabase/migrations/20260817000008_fix_rls_recursion.sql`
- [x] Master script updated: `supabase/PRODUCTION_DEPLOY_ALL_PENDING.sql`
- [x] Zero table deletion, zero data truncation.
- [x] Self profile read (`id = auth.uid()`) runs with zero recursion.
- [x] Admin, Parent, Teacher cross-reads use isolated security definer helpers.
- [x] All 70 Vitest tests passing.
