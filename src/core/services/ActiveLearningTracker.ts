import { supabase } from '../config/supabase';

class ActiveLearningTracker {
  private tracking: { sessionId: string; courseId: string; lessonId: string | null; timer: number } | null = null;
  private lastActivity = 0;
  private sending = false;

  private recordInteraction = () => {
    this.lastActivity = Date.now();
  };

  private readonly activityEvents = ['pointerdown', 'pointermove', 'keydown', 'scroll', 'focus'] as const;

  start(courseId: string): void {
    this.stop();
    this.recordInteraction();
    for (const event of this.activityEvents) {
      window.addEventListener(event, this.recordInteraction, { passive: true });
    }
    this.tracking = {
      sessionId: crypto.randomUUID(),
      courseId,
      lessonId: null,
      timer: window.setInterval(() => void this.sendHeartbeat(), 25_000),
    };
    void this.sendHeartbeat();
  }

  setLesson(lessonId: string | null): void {
    if (this.tracking) this.tracking.lessonId = lessonId;
  }

  stop(): void {
    if (!this.tracking) return;
    window.clearInterval(this.tracking.timer);
    for (const event of this.activityEvents) window.removeEventListener(event, this.recordInteraction);
    this.tracking = null;
  }

  private async sendHeartbeat(): Promise<void> {
    const tracking = this.tracking;
    if (!tracking || this.sending || document.hidden || !document.hasFocus() || Date.now() - this.lastActivity > 120_000) return;
    this.sending = true;
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session || this.tracking !== tracking) return;
      await supabase.rpc('record_session_heartbeat', {
        p_session_id: tracking.sessionId,
        p_course_id: tracking.courseId,
        p_lesson_id: tracking.lessonId,
        p_platform: 'web',
      });
    } catch {
      // Background telemetry does not interrupt a lesson.
    } finally {
      this.sending = false;
    }
  }
}

export const activeLearningTracker = new ActiveLearningTracker();
