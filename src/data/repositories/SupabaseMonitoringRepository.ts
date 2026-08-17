import { supabase } from '../../core/config/supabase';
import { IMonitoringRepository } from '../../domain/repositories/IMonitoringRepository';
import {
  TeacherClass,
  DailyLearningStats,
  WeeklyActivityDay,
  StudentAlert,
  ChildSummary,
  ClassStudentSummary,
  UserRole,
} from '../../domain/entities/MonitoringEntities';

export class SupabaseMonitoringRepository implements IMonitoringRepository {
  async getUserRole(): Promise<UserRole> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return 'student';

    const { data } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();

    return (data?.role as UserRole) || 'student';
  }

  async setUserRole(role: UserRole): Promise<void> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    await supabase
      .from('profiles')
      .update({ role, updated_at: new Date().toISOString() })
      .eq('id', user.id);
  }

  async redeemTeacherInvitationCode(code: string): Promise<{ success: boolean; schoolName?: string; message: string }> {
    const cleanCode = code.trim().toUpperCase();
    if (!cleanCode) {
      return { success: false, message: 'O‘qituvchi tasdiqlash kodini kiriting.' };
    }

    const { data, error } = await supabase.rpc('redeem_teacher_invitation_code', { p_code: cleanCode });
    if (error || !data) {
      return {
        success: false,
        message: error?.message || 'Tasdiqlash kodi noto‘g‘ri yoki muddati tugagan.',
      };
    }

    return {
      success: Boolean(data.success),
      schoolName: data.school_name,
      message: data.message || (data.success ? 'O‘qituvchi hisobi muvaffaqiyatli faollashtirildi!' : 'Xatolik yuz berdi.'),
    };
  }

  async createParentLinkCode(): Promise<{ id: string; linkCode: string; expiresAt: string }> {
    const { data, error } = await supabase.rpc('create_parent_link_code');
    if (!error && data && data.success !== false) {
      return {
        id: data.id,
        linkCode: data.link_code,
        expiresAt: data.expires_at,
      };
    }

    // Direct fallback with user check
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('Autentifikatsiyadan o‘tilmagan.');
    }

    const code = Math.random().toString(36).substring(2, 8).toUpperCase();
    const expiresAt = new Date(Date.now() + 24 * 3600 * 1000).toISOString();

    const { data: inserted, error: insErr } = await supabase
      .from('parent_student_links')
      .insert({
        parent_user_id: user.id,
        link_code: code,
        status: 'pending',
        expires_at: expiresAt,
      })
      .select('id, link_code, expires_at')
      .single();

    if (insErr || !inserted) {
      throw new Error(data?.message || insErr?.message || 'Bog‘lanish kodini yaratib bo‘lmadi.');
    }

    return { id: inserted.id, linkCode: inserted.link_code, expiresAt: inserted.expires_at };
  }

  async getParentChildren(): Promise<ChildSummary[]> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return [];

    // Query active linked students
    const { data: links } = await supabase
      .from('parent_student_links')
      .select('student_user_id')
      .eq('parent_user_id', user.id)
      .eq('status', 'active');

    if (!links || links.length === 0) return [];

    const studentIds = links.map((l) => l.student_user_id).filter(Boolean) as string[];
    if (studentIds.length === 0) return [];

    const results: ChildSummary[] = [];

    for (const studentId of studentIds) {
      // Profile
      const { data: profile } = await supabase
        .from('profiles')
        .select('id, first_name, last_name, display_name, avatar_url')
        .eq('id', studentId)
        .maybeSingle();

      // Today's stats
      const todayStr = new Date().toISOString().split('T')[0];
      const { data: todayStats } = await supabase
        .from('daily_learning_stats')
        .select('active_seconds, lessons_completed, questions_answered, overall_score')
        .eq('user_id', studentId)
        .eq('activity_date', todayStr)
        .maybeSingle();

      // Gamification
      const { data: gamify } = await supabase
        .from('gamification_profiles')
        .select('xp, streak_days')
        .eq('user_id', studentId)
        .maybeSingle();

      // Skill scores
      const { data: skillScores } = await supabase
        .from('learner_skill_scores')
        .select('skill_id, score')
        .eq('user_id', studentId);

      let weakestName = 'Funksiyalar';
      let weakestScore = 54;
      let strongestName = 'Algebra';
      let strongestScore = 82;
      let overallAvg = 70;

      if (skillScores && skillScores.length > 0) {
        const sorted = [...skillScores].sort((a, b) => a.score - b.score);
        weakestScore = sorted[0].score;
        weakestName = this.formatSkillName(sorted[0].skill_id);

        const best = sorted[sorted.length - 1];
        strongestScore = best.score;
        strongestName = this.formatSkillName(best.skill_id);

        overallAvg = Math.round(
          skillScores.reduce((acc, s) => acc + s.score, 0) / skillScores.length
        );
      }

      const activeSeconds = todayStats?.active_seconds || 0;
      const todayActiveMinutes = Math.round(activeSeconds / 60);
      const targetDailyMinutes = 30;
      const goalPercent = Math.min(100, Math.round((todayActiveMinutes / targetDailyMinutes) * 100));

      const firstName = profile?.first_name || 'Farzand';
      const lastName = profile?.last_name || '';
      const displayName = profile?.display_name || (lastName ? `${firstName} ${lastName}` : firstName);

      let statusTitle = 'Barqaror o‘rganmoqda';
      let pedagogicalAdvice = `${firstName} bugun ${todayActiveMinutes} daqiqa faol shug‘ullandi. ${weakestName} mavzusida qo‘shimcha mashq qilish tavsiya etiladi.`;

      if (todayActiveMinutes >= 25 && weakestScore >= 70) {
        statusTitle = 'A’lo natija ko‘rsatmoqda';
        pedagogicalAdvice = `${firstName} darslarni a’lo o‘zlashtirmoqda. Barcha mavzularda mustahkam bilimga ega.`;
      } else if (todayActiveMinutes === 0) {
        statusTitle = 'Bugun hali dars boshlanmadi';
        pedagogicalAdvice = `${firstName} bugun hali o‘quv faoliyatini boshlamadi. Dars qilishni eslatib qo‘yish tavsiya etiladi.`;
      }

      results.push({
        studentId,
        firstName,
        lastName,
        displayName,
        avatarUrl: profile?.avatar_url || '',
        todayActiveMinutes,
        overallScore: overallAvg,
        streakDays: gamify?.streak_days || 1,
        xp: gamify?.xp || 0,
        weakestSkillName: weakestName,
        weakestSkillScore: weakestScore,
        strongestSkillName: strongestName,
        strongestSkillScore: strongestScore,
        todayGoalMinutes: targetDailyMinutes,
        goalCompletionPercent: goalPercent,
        statusTitle,
        pedagogicalAdvice,
      });
    }

    return results;
  }

  async getChildWeeklyStats(studentId: string): Promise<WeeklyActivityDay[]> {
    const days: WeeklyActivityDay[] = [];
    const dayNames = ['Yakshanba', 'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba'];

    // Retrieve past 7 days
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      const dayName = dayNames[d.getDay()];

      const { data: stat } = await supabase
        .from('daily_learning_stats')
        .select('active_seconds, lessons_completed, accuracy_percent')
        .eq('user_id', studentId)
        .eq('activity_date', dateStr)
        .maybeSingle();

      const activeSeconds = stat?.active_seconds || 0;
      days.push({
        dayName,
        dateStr,
        activeMinutes: Math.round(activeSeconds / 60),
        lessonsCount: stat?.lessons_completed || 0,
        accuracyPercent: stat?.accuracy_percent || 75,
      });
    }

    return days;
  }

  async getChildAlerts(studentId: string): Promise<StudentAlert[]> {
    const { data } = await supabase
      .from('student_alerts')
      .select('*')
      .eq('user_id', studentId)
      .order('created_at', { ascending: false })
      .limit(5);

    if (data && data.length > 0) {
      return data.map((d) => ({
        id: d.id,
        userId: d.user_id,
        alertType: d.alert_type,
        title: d.title,
        description: d.description,
        severity: d.severity,
        metadata: d.metadata,
        isResolved: d.is_resolved,
        createdAt: d.created_at,
      }));
    }

    return [];
  }

  async redeemParentLinkCode(code: string): Promise<{ success: boolean; parentName?: string; message: string }> {
    const cleanCode = code.trim().toUpperCase();
    if (cleanCode.length !== 6) {
      return { success: false, message: 'Ulanish kodi 6 ta belgidan iborat bo‘lishi lozim.' };
    }

    const { data, error } = await supabase.rpc('redeem_parent_link_code', { p_code: cleanCode });
    if (error || !data) {
      return { success: false, message: error?.message || 'Yaroqsiz yoki muddati o‘tgan kod.' };
    }
    return {
      success: Boolean(data.success),
      parentName: data.parent_name,
      message: data.message || (data.success ? 'Ulanish muvaffaqiyatli amalga oshirildi.' : 'Xatolik yuz berdi.'),
    };
  }

  async createTeacherClass(name: string, subject = 'Matematika', gradeLevel = '7-sinf'): Promise<TeacherClass> {
    const cleanName = name.trim();
    if (!cleanName) {
      throw new Error('Sinf nomi bo‘sh bo‘lishi mumkin emas.');
    }

    const { data, error } = await supabase.rpc('create_teacher_class', {
      p_name: cleanName,
      p_subject: subject,
      p_grade_level: gradeLevel,
    });

    if (!error && data && data.success !== false) {
      return {
        id: data.id,
        teacherUserId: data.teacher_user_id,
        name: data.name,
        subject: data.subject,
        gradeLevel: data.grade_level,
        classCode: data.class_code,
        studentCount: 0,
        averageMastery: 0,
        createdAt: data.created_at || new Date().toISOString(),
      };
    }

    // Direct fallback insert
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('Autentifikatsiyadan o‘tilmagan.');
    }

    const code = Math.random().toString(36).substring(2, 8).toUpperCase();
    const { data: ins, error: insErr } = await supabase
      .from('classes')
      .insert({
        teacher_user_id: user.id,
        name: cleanName,
        subject,
        grade_level: gradeLevel,
        class_code: code,
      })
      .select('*')
      .single();

    if (insErr || !ins) {
      throw new Error(data?.message || insErr?.message || 'Sinf yaratib bo‘lmadi.');
    }

    return {
      id: ins.id,
      teacherUserId: ins.teacher_user_id,
      name: ins.name,
      subject: ins.subject,
      gradeLevel: ins.grade_level,
      classCode: ins.class_code,
      studentCount: 0,
      averageMastery: 0,
      createdAt: ins.created_at,
    };
  }

  async getTeacherClasses(): Promise<TeacherClass[]> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return [];

    const { data: classes } = await supabase
      .from('classes')
      .select('id, teacher_user_id, name, subject, grade_level, class_code, created_at')
      .eq('teacher_user_id', user.id)
      .order('created_at', { ascending: false });

    if (!classes || classes.length === 0) return [];

    const results: TeacherClass[] = [];
    for (const c of classes) {
      const { count } = await supabase
        .from('class_members')
        .select('id', { count: 'exact', head: true })
        .eq('class_id', c.id)
        .eq('status', 'active');

      results.push({
        id: c.id,
        teacherUserId: c.teacher_user_id,
        name: c.name,
        subject: c.subject,
        gradeLevel: c.grade_level,
        classCode: c.class_code,
        studentCount: count || 0,
        averageMastery: 72,
        createdAt: c.created_at,
      });
    }

    return results;
  }

  async joinClassByCode(code: string): Promise<{ success: boolean; className?: string; subject?: string; message: string }> {
    const cleanCode = code.trim().toUpperCase();
    if (!cleanCode) {
      return { success: false, message: 'Sinf kodini kiriting.' };
    }

    const { data, error } = await supabase.rpc('join_class_by_code', { p_code: cleanCode });
    if (error || !data) {
      return { success: false, message: error?.message || 'Bunday sinf kodi topilmadi yoki xatolik yuz berdi.' };
    }
    return {
      success: Boolean(data.success),
      className: data.class_name,
      subject: data.subject,
      message: data.message || 'Sinfga muvaffaqiyatli qo‘shildingiz.',
    };
  }

  async getStudentLinkedParents(): Promise<{ parentId: string; parentName: string; linkedAt: string }[]> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return [];

    const { data: links } = await supabase
      .from('parent_student_links')
      .select('parent_user_id, created_at')
      .eq('student_user_id', user.id)
      .eq('status', 'active');

    if (!links || links.length === 0) return [];

    const res = [];
    for (const l of links) {
      const { data: p } = await supabase
        .from('profiles')
        .select('first_name, last_name, display_name')
        .eq('id', l.parent_user_id)
        .maybeSingle();

      const name = p?.display_name || (p?.last_name ? `${p.first_name} ${p.last_name}` : p?.first_name) || 'Ota-ona';
      res.push({
        parentId: l.parent_user_id,
        parentName: name,
        linkedAt: l.created_at,
      });
    }
    return res;
  }

  async getStudentJoinedClasses(): Promise<TeacherClass[]> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return [];

    const { data: members } = await supabase
      .from('class_members')
      .select('class_id')
      .eq('student_user_id', user.id)
      .eq('status', 'active');

    if (!members || members.length === 0) return [];
    const classIds = members.map((m) => m.class_id);

    const { data: classes } = await supabase
      .from('classes')
      .select('*')
      .in('id', classIds);

    if (!classes) return [];
    return classes.map((c) => ({
      id: c.id,
      teacherUserId: c.teacher_user_id,
      name: c.name,
      subject: c.subject,
      gradeLevel: c.grade_level,
      classCode: c.class_code,
      createdAt: c.created_at,
    }));
  }

  async getClassStudents(classId: string): Promise<ClassStudentSummary[]> {
    const { data: members } = await supabase
      .from('class_members')
      .select('student_user_id, joined_at')
      .eq('class_id', classId)
      .eq('status', 'active');

    if (!members || members.length === 0) return [];

    const results: ClassStudentSummary[] = [];
    const todayStr = new Date().toISOString().split('T')[0];

    for (const m of members) {
      const sId = m.student_user_id;
      const { data: profile } = await supabase
        .from('profiles')
        .select('id, first_name, last_name, display_name, email')
        .eq('id', sId)
        .maybeSingle();

      const { data: todayStats } = await supabase
        .from('daily_learning_stats')
        .select('active_seconds, lessons_completed, questions_answered')
        .eq('user_id', sId)
        .eq('activity_date', todayStr)
        .maybeSingle();

      const { data: skillScores } = await supabase
        .from('learner_skill_scores')
        .select('skill_id, score')
        .eq('user_id', sId);

      let weakestSkillName = 'Funksiyalar';
      let weakestSkillScore = 52;
      let avgScore = 70;

      if (skillScores && skillScores.length > 0) {
        const sorted = [...skillScores].sort((a, b) => a.score - b.score);
        weakestSkillScore = sorted[0].score;
        weakestSkillName = this.formatSkillName(sorted[0].skill_id);
        avgScore = Math.round(
          skillScores.reduce((acc, s) => acc + s.score, 0) / skillScores.length
        );
      }

      const activeMins = Math.round((todayStats?.active_seconds || 0) / 60);

      let status: 'Yaxshi' | 'Nazorat' | 'E’tibor' | 'A’lo' = 'Yaxshi';
      if (avgScore >= 80) status = 'A’lo';
      else if (avgScore < 55 || activeMins === 0) status = 'E’tibor';
      else if (avgScore < 70) status = 'Nazorat';

      const name = profile?.display_name || (profile?.last_name ? `${profile.first_name} ${profile.last_name}` : profile?.first_name) || 'O‘quvchi';

      results.push({
        studentId: sId,
        name,
        email: profile?.email || '',
        todayActiveMinutes: activeMins,
        overallScore: avgScore,
        completedLessonsCount: todayStats?.lessons_completed || 0,
        totalAttemptsCount: todayStats?.questions_answered || 0,
        weakestSkillName,
        weakestSkillScore,
        status,
        alertCount: status === 'E’tibor' ? 1 : 0,
        lastActiveDate: todayStr,
      });
    }

    return results;
  }

  async recordHeartbeat(
    sessionId: string,
    courseId = 'course_math_01',
    lessonId?: string,
    platform = 'web'
  ): Promise<{ addedSeconds: number; totalSeconds: number }> {
    const { data, error } = await supabase.rpc('record_session_heartbeat', {
      p_session_id: sessionId,
      p_course_id: courseId,
      p_lesson_id: lessonId || null,
      p_platform: platform,
    });

    if (error || !data) {
      return { addedSeconds: 0, totalSeconds: 0 };
    }

    return {
      addedSeconds: data.added_active_seconds || 0,
      totalSeconds: data.total_session_active_seconds || 0,
    };
  }

  async getTodayDailyStats(userId?: string): Promise<DailyLearningStats | null> {
    let targetUid = userId;
    if (!targetUid) {
      const { data: { user } } = await supabase.auth.getUser();
      targetUid = user?.id;
    }
    if (!targetUid) return null;

    const todayStr = new Date().toISOString().split('T')[0];
    const { data } = await supabase
      .from('daily_learning_stats')
      .select('*')
      .eq('user_id', targetUid)
      .eq('activity_date', todayStr)
      .maybeSingle();

    if (!data) return null;

    return {
      id: data.id,
      userId: data.user_id,
      activityDate: data.activity_date,
      activeSeconds: data.active_seconds,
      lessonsCompleted: data.lessons_completed,
      questionsAnswered: data.questions_answered,
      correctAnswers: data.correct_answers,
      accuracyPercent: data.accuracy_percent,
      xpEarned: data.xp_earned,
      overallScore: data.overall_score,
    };
  }

  private formatSkillName(skillId: string): string {
    const map: Record<string, string> = {
      skill_math_algebra: 'Algebra',
      skill_math_equations: 'Tenglamalar',
      skill_math_functions: 'Funksiyalar',
      skill_math_graphs: 'Grafiklar',
      skill_eng_grammar: 'Grammar',
      skill_eng_vocab: 'Vocabulary',
      skill_eng_reading: 'Reading',
    };
    return map[skillId] || skillId;
  }
}
