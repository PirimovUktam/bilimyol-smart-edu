import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/domain/usecases/select_course_use_case.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';

void main() {
  group('CourseSwitching Tests', () {
    test('switches active course cleanly and isolates subject skill scores', () async {
      final courseRepo = InMemoryCourseRepository();
      final learnerRepo = InMemoryLearnerRepository();
      final selectUseCase = SelectCourseUseCase(courseRepo, learnerRepo);

      // 1. Select Mathematics and record scores
      final mathCourse = await selectUseCase.execute('course_math_01');
      expect(mathCourse.title, equals('Matematika'));

      await learnerRepo.saveSkillScores('course_math_01', {
        'skill_math_functions': const SkillScore(
          skillId: 'skill_math_functions',
          courseId: 'course_math_01',
          score: 63,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.developing,
        ),
      });

      // 2. Switch to English and record scores
      final engCourse = await selectUseCase.execute('course_eng_01');
      expect(engCourse.title, equals('Ingliz tili'));

      await learnerRepo.saveSkillScores('course_eng_01', {
        'skill_eng_listening': const SkillScore(
          skillId: 'skill_eng_listening',
          courseId: 'course_eng_01',
          score: 43,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.needsRemediation,
          isWeakestFocus: true,
        ),
      });

      final profile = await learnerRepo.getProfile();
      expect(profile.selectedCourseId, equals('course_eng_01'));

      // Ensure Mathematics score is still preserved in its isolated course scope
      expect(profile.scoresByCourse['course_math_01']?['skill_math_functions']?.score, equals(63));
      // Ensure English score is stored in English scope
      expect(profile.scoresByCourse['course_eng_01']?['skill_eng_listening']?.score, equals(43));
    });

    test('loads distinct skill sets for Mathematics and English', () async {
      final courseRepo = InMemoryCourseRepository();

      final mathSkills = await courseRepo.getSkillsByCourseId('course_math_01');
      final engSkills = await courseRepo.getSkillsByCourseId('course_eng_01');

      expect(mathSkills.map((s) => s.name), containsAll(['Algebra asoslari', 'Tenglamalar', 'Funksiyalar', 'Grafiklar']));
      expect(engSkills.map((s) => s.name), containsAll(['Vocabulary', 'Grammar', 'Listening', 'Reading']));
      expect(mathSkills.length, equals(4));
      expect(engSkills.length, equals(4));
    });
  });
}
