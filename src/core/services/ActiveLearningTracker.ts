import { supabase } from '../config/supabase';

class ActiveLearningTracker {
  private sessionId: string = '';
  private intervalId: number | null = null;
  private lastActivityTimestamp: number = Date.now();
  private isPaused: boolean = false;
  private currentCourseId: string = 'course_math_01';
  private currentLessonId: string | null = null;
  private readonly INACTIVITY_LIMIT_MS = 300_000; // 5 minutes

  constructor() {
    this.sessionId = this.generateSessionId();
    this.attachEventListeners();
  }

  public start(courseId = 'course_math_01', lessonId?: string): void {
    this.currentCourseId = courseId;
    this.currentLessonId = lessonId || null;
    this.lastActivityTimestamp = Date.now();
    this.isPaused = false;

    if (!this.sessionId) {
      this.sessionId = this.generateSessionId();
    }

    if (this.intervalId === null) {
      // Send initial heartbeat immediately
      this.sendHeartbeat();
      // Schedule periodic pulse every 25 seconds
      this.intervalId = window.setInterval(() => {
        this.sendHeartbeat();
      }, 25_000);
    }
  }

  public setLesson(lessonId: string): void {
    this.currentLessonId = lessonId;
    this.recordInteraction();
  }

  public stop(): void {
    if (this.intervalId !== null) {
      window.clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  public recordInteraction(): void {
    this.lastActivityTimestamp = Date.now();
    if (this.isPaused) {
      this.isPaused = false;
    }
  }

  private attachEventListeners(): void {
    if (typeof window === 'undefined') return;

    const onUserAction = () => this.recordInteraction();

    window.addEventListener('mousemove', onUserAction, { passive: true });
    window.addEventListener('keydown', onUserAction, { passive: true });
    window.addEventListener('click', onUserAction, { passive: true });
    window.addEventListener('scroll', onUserAction, { passive: true });
    window.addEventListener('touchstart', onUserAction, { passive: true });

    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        this.isPaused = true;
      } else {
        this.isPaused = false;
        this.lastActivityTimestamp = Date.now();
      }
    });

    window.addEventListener('focus', () => {
      this.isPaused = false;
      this.lastActivityTimestamp = Date.now();
    });

    window.addEventListener('blur', () => {
      this.isPaused = true;
    });
  }

  private async sendHeartbeat(): Promise<void> {
    if (this.isPaused) return;

    // Check if idle for more than 5 minutes
    const now = Date.now();
    if (now - this.lastActivityTimestamp > this.INACTIVITY_LIMIT_MS) {
      return; // Inactive, do not count
    }

    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) return;

      await supabase.rpc('record_session_heartbeat', {
        p_session_id: this.sessionId,
        p_course_id: this.currentCourseId,
        p_lesson_id: this.currentLessonId,
        p_platform: 'web',
      });
    } catch {
      // Background heartbeat errors should never interrupt user experience
    }
  }

  private generateSessionId(): string {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) {
      return crypto.randomUUID();
    }
    return 'sess_' + Math.random().toString(36).substring(2, 15) + Date.now().toString(36);
  }
}

export const activeLearningTracker = new ActiveLearningTracker();
