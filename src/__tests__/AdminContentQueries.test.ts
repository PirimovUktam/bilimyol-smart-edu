import { beforeEach, describe, expect, it, vi } from 'vitest';
import { adminContentService } from '../data/services/AdminContentService';

const fetchBackend = vi.hoisted(() => vi.fn<typeof fetch>());
vi.mock('../core/config/supabase', async () => {
  const { createClient } = await vi.importActual<typeof import('@supabase/supabase-js')>('@supabase/supabase-js');
  return {
    isSupabaseConfigured: true,
    supabase: createClient('http://127.0.0.1:54321', 'admin-test-key', {
      global: { fetch: fetchBackend },
      auth: { persistSession: false, autoRefreshToken: false },
    }),
  };
});

const requestedUrl = (index = 0) => new URL(String(fetchBackend.mock.calls[index][0]));

beforeEach(() => fetchBackend.mockReset());

describe('Admin content queries', () => {
  it('pages within the course and skill through the admin question view', async () => {
    const questions = Array.from({ length: 21 }, (_, index) => ({
      id: `question-${index + 21}`,
      course_id: 'course-b', skill_id: 'skill-b', text: 'Question', options: ['A', 'B'],
      correct_index: 1, difficulty: 'medium', explanation: 'Because B', formula_latex: null,
      is_placement: false,
    }));
    fetchBackend.mockImplementationOnce(async () => Response.json(questions));

    const page = await adminContentService.getQuestions('course-b', 'skill-b', 1);
    const url = requestedUrl();

    expect(url.pathname).toBe('/rest/v1/admin_questions');
    expect(url.searchParams.get('course_id')).toBe('eq.course-b');
    expect(url.searchParams.get('skill_id')).toBe('eq.skill-b');
    expect(url.searchParams.get('offset')).toBe('20');
    expect(url.searchParams.get('limit')).toBe('21');
    expect(url.searchParams.get('order')).toBe('created_at.desc,id.asc');
    expect(url.searchParams.get('select')).not.toBe('*');
    expect(page.rows).toHaveLength(20);
    expect(page.rows[0]).toMatchObject({ id: 'question-21', correctIndex: 1 });
    expect(page.rows.at(-1)?.id).toBe('question-40');
    expect(page.hasMore).toBe(true);
  });

  it('loads large lesson content only for the editor and preserves it when saving', async () => {
    const lesson = {
      id: 'lesson-b', course_id: 'course-b', skill_id: 'skill-b', title: 'Lesson',
      estimated_minutes: 20, summary: 'Summary', is_published: false, is_archived: true,
    };
    fetchBackend
      .mockImplementationOnce(async () => Response.json([lesson]))
      .mockImplementationOnce(async () => Response.json({ steps: [], reinforcement_exercise: null }))
      .mockImplementationOnce(async () => Response.json({ saved: true, id: lesson.id }));

    const page = await adminContentService.getLessons('course-b');
    const listUrl = requestedUrl();
    expect(listUrl.pathname).toBe('/rest/v1/admin_lessons');
    expect(listUrl.searchParams.get('course_id')).toBe('eq.course-b');
    expect(listUrl.searchParams.get('limit')).toBe('21');
    expect(listUrl.searchParams.get('select')).not.toMatch(/\*|steps|reinforcement_exercise/);
    expect(page.rows[0]).toMatchObject({ id: lesson.id, isPublished: false, isArchived: true });

    const detail = await adminContentService.getLessonDetails(lesson.id);
    const detailUrl = requestedUrl(1);
    expect(detailUrl.pathname).toBe('/rest/v1/admin_lessons');
    expect(detailUrl.searchParams.get('id')).toBe('eq.lesson-b');
    expect(detailUrl.searchParams.get('select')).toBe('steps,reinforcement_exercise');

    await adminContentService.saveLesson({ ...page.rows[0], ...detail, title: 'Renamed' });
    const request = fetchBackend.mock.calls[2][1];
    expect(requestedUrl(2).pathname).toBe('/rest/v1/rpc/admin_save_lesson');
    expect(JSON.parse(String(request?.body)).p_lesson).toMatchObject({
      id: 'lesson-b', title: 'Renamed', steps: [], reinforcement_exercise: null,
    });
  });

  it('retrieves skill selector options beyond the first batch for the chosen course', async () => {
    fetchBackend
      .mockImplementationOnce(async () => Response.json(Array.from({ length: 100 }, (_, index) => ({
        id: `skill-${index + 1}`, name: `Skill ${index + 1}`,
      }))))
      .mockImplementationOnce(async () => Response.json([{ id: 'skill-101', name: 'Skill 101' }]));

    const options = await adminContentService.getSkillOptions('course-b');
    const firstUrl = requestedUrl();
    const secondUrl = requestedUrl(1);
    expect(firstUrl.pathname).toBe('/rest/v1/skills');
    expect(firstUrl.searchParams.get('course_id')).toBe('eq.course-b');
    expect(firstUrl.searchParams.get('select')).toBe('id,name');
    expect(secondUrl.searchParams.get('course_id')).toBe('eq.course-b');
    expect(secondUrl.searchParams.get('offset')).toBe('100');
    expect(options).toHaveLength(101);
    expect(options.at(-1)).toEqual({ id: 'skill-101', name: 'Skill 101' });
  });

  it('surfaces query failures and treats a deleted last page as empty', async () => {
    fetchBackend
      .mockImplementationOnce(async () => Response.json({ code: '42501', message: 'permission denied' }, { status: 403 }))
      .mockImplementationOnce(async () => Response.json({ code: 'PGRST103', message: 'Requested range not satisfiable' }, { status: 416 }));

    await expect(adminContentService.getSkills('course-b')).rejects.toThrow('permission denied');
    await expect(adminContentService.getSkills('course-b', 1)).resolves.toMatchObject({ rows: [], hasMore: false });
  });
});
