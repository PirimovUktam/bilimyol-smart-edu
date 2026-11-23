import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/l10n/app_strings.dart';
import 'package:bilimyol_mobile/core/theme/app_theme.dart';
import 'package:bilimyol_mobile/data/datasources/courses_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/features/roadmap/roadmap_screen.dart';

void main() {
  group('RoadmapScreen P0 Deadlock & Diagnostic Progression', () {
    for (final course in seedCourses) {
      testWidgets(
        'low diagnostic scores (<50%) render actionable Maşq qiliş button for ${course.id}',
        (tester) async {
          final repo = InMemoryLearnerRepository();
          await repo.saveSkillScores(course.id, {
            for (final skill in course.skills)
              skill: SkillScore(
                skillId: skill,
                courseId: course.id,
                score: 25,
                lastUpdated: 1000,
                masteryLevel: MasteryLevel.needsRemediation,
              ),
          });
          final initial = await repo.getProfile();
          await repo.updateProfile(initial.copyWith(selectedCourseId: course.id));

          final container = ProviderContainer(
            overrides: [
              learnerRepositoryProvider.overrideWithValue(repo),
              courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
              lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
            ],
          );
          addTearDown(container.dispose);

          await container.read(courseStateNotifierProvider.notifier).init();
          await container.read(courseStateNotifierProvider.notifier).selectCourse(course.id);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                locale: const Locale('uz'),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: AppStrings.localizationsDelegates,
                home: const RoadmapScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Maşq qiliş'), findsWidgets);
          expect(find.text('Ta’lim yöli'), findsAtLeastNWidgets(1));
          expect(find.text('Roadmap'), findsNothing);
        },
      );
    }

    testWidgets('Tezkor demo [82, 84, 41, 68] renders Takrorlaş on steps 1-2 and unlocks Maşq qiliş on step 3', (tester) async {
      final repo = InMemoryLearnerRepository();
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');
      await container.read(learnerStateNotifierProvider.notifier).seedQuickDemo();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('uz'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: AppStrings.localizationsDelegates,
            home: const RoadmapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Takrorlaş'), findsNWidgets(2));
      expect(find.text('Maşq qiliş'), findsNWidgets(2));
    });
  });
}
