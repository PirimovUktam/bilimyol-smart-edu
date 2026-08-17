import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';

void main() {
  group('User Identity & Profile Resolution Tests (Flutter)', () {
    late InMemoryLearnerRepository learnerRepo;

    setUp(() async {
      learnerRepo = InMemoryLearnerRepository();
      await learnerRepo.resetAll();
    });

    test('initializes default profile with neutral name Foydalanuvchi without hardcoded name', () async {
      final profile = await learnerRepo.getProfile();
      expect(profile.name, equals('Foydalanuvchi'));
      expect(profile.name, isNot(equals('Azizbek')));
    });

    test('updates learner name to "Aaaaa" accurately upon registration', () async {
      final current = await learnerRepo.getProfile();
      final updated = current.copyWith(name: 'Aaaaa');
      await learnerRepo.updateProfile(updated);

      final fresh = await learnerRepo.getCurrentProfile();
      expect(fresh.name, equals('Aaaaa'));
    });

    test('isolates user sessions and clears state upon resetAll', () async {
      final current = await learnerRepo.getProfile();
      await learnerRepo.updateProfile(current.copyWith(name: 'UserA', xp: 200));

      var profile = await learnerRepo.getProfile();
      expect(profile.name, equals('UserA'));
      expect(profile.xp, equals(200));

      await learnerRepo.resetAll();
      profile = await learnerRepo.getProfile();
      expect(profile.name, equals('Foydalanuvchi'));
      expect(profile.xp, equals(0));
    });
  });
}
