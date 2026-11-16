export const MATH_MASTERY_COURSE = "course_math_01";

export function isMathDraftGeneration(courseId: unknown, action: string): boolean {
  return courseId === MATH_MASTERY_COURSE && action.startsWith("generate_");
}

interface MathObjective {
  course_id: string;
  target_lesson_id: string;
  skill_id: string;
  title: string;
  description: string;
  status: "locked" | "available" | "in_progress" | "reinforcement" | "completed";
  order_index: number;
  mastery_state: "not_started" | "practicing" | "needs_review" | "mastered";
  is_optional: boolean;
}

function isOpenObjective(row: unknown): row is MathObjective {
  if (!row || typeof row !== "object") return false;
  const n = row as Partial<MathObjective>;
  return n.course_id === MATH_MASTERY_COURSE &&
    typeof n.target_lesson_id === "string" && typeof n.skill_id === "string" &&
    typeof n.title === "string" && typeof n.description === "string" &&
    typeof n.order_index === "number" && Number.isFinite(n.order_index) && typeof n.is_optional === "boolean" &&
    (n.status === "available" || n.status === "in_progress" || n.status === "reinforcement" || n.status === "completed") &&
    (n.mastery_state === "not_started" || n.mastery_state === "practicing" ||
      n.mastery_state === "needs_review" || n.mastery_state === "mastered");
}

export function selectMathObjective(roadmap: unknown, skillId?: string, lessonId?: string): MathObjective | undefined {
  if (!Array.isArray(roadmap)) return undefined;
  const open = roadmap.filter(isOpenObjective);
  if (lessonId) return open.find((n) => n.target_lesson_id === lessonId && (!skillId || n.skill_id === skillId));
  const matching = skillId ? open.filter((n) => n.skill_id === skillId) : open;
  return matching.find((n) => !n.is_optional && n.status !== "completed") ?? matching[0];
}

export function readMathTutorAnswer(value: unknown): string | null {
  if (!value || typeof value !== "object" || Array.isArray(value) || Object.keys(value).length !== 1) return null;
  const answer = (value as { answer?: unknown }).answer;
  return typeof answer === "string" && answer.trim().length > 0 && answer.length <= 4000 ? answer.trim() : null;
}
