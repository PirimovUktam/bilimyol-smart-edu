import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/course.dart';

void main() {
  group('Subject Alignment and AI Lesson Generation Regression Tests (Flutter)', () {
    late InMemoryCourseRepository courseRepo;
    late InMemoryLessonRepository lessonRepo;
    late DemoAITutorService aiService;

    setUp(() {
      courseRepo = InMemoryCourseRepository();
      lessonRepo = InMemoryLessonRepository();
      aiService = DemoAITutorService();
    });

    test('1. English course contains English lessons and does not load math lessons', () async {
      final course = await courseRepo.getCourseById('course_eng_01');
      expect(course, isNotNull);
      expect(course!.subject, equals(SubjectType.english));
      expect(course.lessons, isNotEmpty);
      expect(course.lessons.first, equals('lesson_eng_listening_01'));

      final lesson = await lessonRepo.getLessonById(course.lessons.first);
      expect(lesson, isNotNull);
      expect(lesson!.courseId, equals('course_eng_01'));
      expect(lesson.title, contains('Listening'));
      expect(lesson.title.contains('Matematika'), isFalse);
      expect(lesson.title.contains('Kasrlar'), isFalse);
    });

    test('2. Mathematics course contains Math lessons with formula steps', () async {
      final course = await courseRepo.getCourseById('course_math_01');
      expect(course, isNotNull);
      expect(course!.subject, equals(SubjectType.mathematics));
      expect(course.lessons, isNotEmpty);
      expect(course.lessons.first, equals('lesson_math_functions_01'));

      final lesson = await lessonRepo.getLessonById(course.lessons.first);
      expect(lesson, isNotNull);
      expect(lesson!.courseId, equals('course_math_01'));
      expect(lesson.title, contains('Funksiya'));
      expect(lesson.title.contains('Listening'), isFalse);
    });

    test('3. IT & Logic courses ship seeded lessons with correct subject attribution (no math fallback)', () async {
      final itCourse = await courseRepo.getCourseById('course_it');
      expect(itCourse, isNotNull);
      expect(itCourse!.subject, equals(SubjectType.it));
      expect(itCourse.lessons, isNotEmpty);
      expect(itCourse.lessons.first, equals('lesson_it_python_01'));

      final itLesson = await lessonRepo.getLessonById(itCourse.lessons.first);
      expect(itLesson, isNotNull);
      expect(itLesson!.courseId, equals('course_it'));
      expect(itLesson.title.contains('Matematika'), isFalse);

      final logicCourse = await courseRepo.getCourseById('course_logic');
      expect(logicCourse, isNotNull);
      expect(logicCourse!.subject, equals(SubjectType.logic));
      expect(logicCourse.lessons, isNotEmpty);
      expect(logicCourse.lessons.first, equals('lesson_logic_puzzles_01'));

      final logicLesson = await lessonRepo.getLessonById(
        logicCourse.lessons.first,
      );
      expect(logicLesson, isNotNull);
      expect(logicLesson!.courseId, equals('course_logic'));
      expect(logicLesson.title.contains('Matematika'), isFalse);

      // Unknown ids still never fall back to another course's content.
      final missingLesson = await lessonRepo.getLessonById('lesson_it_missing');
      expect(missingLesson, isNull);
    });

    test('5. IT & Logic have skills, placement questions and roadmap nodes', () async {
      for (final courseId in ['course_it', 'course_logic']) {
        final skills = await courseRepo.getSkillsByCourseId(courseId);
        expect(skills, isNotEmpty, reason: '$courseId needs skills');

        final questions = await courseRepo.getPlacementQuestions(courseId);
        expect(
          questions.length,
          greaterThanOrEqualTo(4),
          reason: '$courseId needs a placement bank',
        );

        final nodes = await lessonRepo.getBaseRoadmapNodes(courseId);
        expect(nodes, isNotEmpty, reason: '$courseId needs roadmap nodes');
        expect(
          nodes.any((node) => node.targetLessonId != null),
          isTrue,
          reason: '$courseId roadmap must point at a lesson',
        );
      }
    });

    test('4. AI lesson generation creates appropriate English and Math lessons', () async {
      // English AI lesson
      const engRequest = GenerateLessonRequest(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_listening',
        topic: 'Daily Conversation',
        level: 'intermediate',
        difficulty: 'medium',
      );
      final engResponse = await aiService.generateLesson(engRequest);
      expect(engResponse.courseId, equals('course_eng_01'));
      expect(engResponse.title.toLowerCase(), contains('dars'));

      // Math AI lesson
      const mathRequest = GenerateLessonRequest(
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        topic: 'Chiziqli funksiyalar',
        level: 'intermediate',
        difficulty: 'medium',
      );
      final mathResponse = await aiService.generateLesson(mathRequest);
      expect(mathResponse.courseId, equals('course_math_01'));
      expect(mathResponse.title, contains('Chiziqli funksiyalar'));
    });
  });
}
