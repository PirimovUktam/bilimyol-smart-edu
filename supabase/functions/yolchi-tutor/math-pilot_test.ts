import { isMathDraftGeneration, MATH_MASTERY_COURSE, readMathTutorAnswer, selectMathObjective } from "./math-pilot.ts";

const foundation = {
  course_id: MATH_MASTERY_COURSE,
  target_lesson_id: "starter",
  skill_id: "addition",
  title: "Qöşiş",
  description: "Ikki guruhni birlaştiriş",
  status: "available",
  order_index: 10,
  mastery_state: "not_started",
  is_optional: false,
};
const locked = { ...foundation, target_lesson_id: "graphs", skill_id: "graphs", status: "locked", order_index: 60 };

Deno.test("math tutor uses only the server-approved, course-bound objective", () => {
  const roadmap = [locked, foundation];
  if (selectMathObjective(roadmap)?.target_lesson_id !== "starter") throw new Error("Wrong default objective");
  if (selectMathObjective(roadmap, "graphs") || selectMathObjective(roadmap, "addition", "graphs") ||
      selectMathObjective(roadmap, "unknown") || selectMathObjective([{ ...foundation, status: "invented" }])) {
    throw new Error("An unavailable or invalid objective was accepted");
  }
});

Deno.test("math generation cannot publish drafts and tutor output is explanation only", () => {
  for (const action of ["generate_lesson", "generate_question", "generate_reinforcement"]) {
    if (!isMathDraftGeneration(MATH_MASTERY_COURSE, action)) throw new Error("Draft route remains available");
  }
  if (isMathDraftGeneration("course_eng_01", "generate_lesson") || isMathDraftGeneration(MATH_MASTERY_COURSE, "askTutor")) {
    throw new Error("Unrelated action was blocked");
  }
  if (readMathTutorAnswer({ answer: "  Misol  " }) !== "Misol") throw new Error("Explanation rejected");
  for (const invalid of ["free-form text", { answer: [] }, { answer: "" }, { answer: "Hi", skillId: "unsupported" },
    { answer: "Hi", nextLesson: "graphs", mastered: true }]) {
    if (readMathTutorAnswer(invalid) !== null) throw new Error("Untrusted response accepted");
  }
});
