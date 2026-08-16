import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';

void main() {
  group('AuthFlow and Session Persistence Tests', () {
    test('initializes default learner profile and preserves identity', () async {
      final repo = InMemoryLearnerRepository();
      final profile = await repo.getProfile();

      expect(profile.name, isNotEmpty);
      expect(profile.dailyMinutes, equals(15));
      expect(profile.goal, equals(OnboardingGoal.mastery));
    });

    test('updates learner preferences and persists across session reloads', () async {
      final repo = InMemoryLearnerRepository();
      final current = await repo.getProfile();

      final updated = current.copyWith(
        name: 'Jasurbek',
        dailyMinutes: 30,
        goal: OnboardingGoal.examPrep,
      );

      await repo.updateProfile(updated);
      final reloaded = await repo.getProfile();

      expect(reloaded.name, equals('Jasurbek'));
      expect(reloaded.dailyMinutes, equals(30));
      expect(reloaded.goal, equals(OnboardingGoal.examPrep));
    });
  });
}
