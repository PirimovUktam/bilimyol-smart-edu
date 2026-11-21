import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bilimyol_mobile/core/storage/local_storage_service.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/repositories/i_learner_repository.dart';

void main() {
  group('InMemoryLearnerRepository Snapshot Persistence', () {
    test('persists and restores profile, skill scores, completed lessons, attempts, XP and streak', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.load();

      final repo1 = InMemoryLearnerRepository(storage: storage);
      final initial = await repo1.getProfile();
      await repo1.updateProfile(
        initial.copyWith(name: 'Malika', selectedCourseId: 'course_eng_01'),
        fields: {
          LearnerProfileField.name,
          LearnerProfileField.selectedCourse,
        },
      );
      await repo1.saveCourseLearningPlan(
        courseId: 'course_eng_01',
        goal: OnboardingGoal.examPrep,
        dailyMinutes: 25,
        initialLevel: InitialLevel.beginner,
      );
      await repo1.saveSkillScores('course_eng_01', {
        'skill_eng_vocab': const SkillScore(
          skillId: 'skill_eng_vocab',
          courseId: 'course_eng_01',
          score: 75,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.proficient,
        ),
      });
      await repo1.recordAnswerAttempt(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        lessonId: 'lesson_eng_vocab_01',
        questionId: 'q_eng_vocab_01_step',
        selectedIndex: 0,
        selectedAnswer: 'A',
        isCorrect: true,
      );
      await repo1.markLessonCompleted(
        'lesson_eng_vocab_01',
        courseId: 'course_eng_01',
      );
      await repo1.markReinforcementCompleted(
        reinforcementId: 'reinf_node_eng_list',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_listening',
        questionId: 'q_eng_reinf_01',
        beforeScore: 43,
        afterScore: 65,
        xpAwarded: 30,
      );
      await repo1.addXp(30, 'reinf_1');

      final expected = await repo1.getProfile();

      // Simulate cold restart with a fresh repository instance reading same storage
      final reloadedStorage = await LocalStorageService.load();
      final repo2 = InMemoryLearnerRepository(storage: reloadedStorage);
      final restored = await repo2.getProfile();

      expect(restored.name, equals('Malika'));
      expect(restored.selectedCourseId, equals('course_eng_01'));
      expect(restored.goal, equals(OnboardingGoal.examPrep));
      expect(restored.dailyMinutes, equals(25));
      expect(restored.courseLevels['course_eng_01'], equals(InitialLevel.beginner));
      expect(restored.xp, equals(expected.xp));
      expect(restored.completedLessonIds, contains('lesson_eng_vocab_01'));
      expect(restored.completedNodeIds, contains('node_eng_vocab'));
      expect(restored.completedReinforcementIds, contains('reinf_node_eng_list'));
      expect(restored.scoresByCourse['course_eng_01']?['skill_eng_vocab']?.score,
          equals(expected.scoresByCourse['course_eng_01']?['skill_eng_vocab']?.score));

      // XP idempotency key survives restart
      final xpAfterDuplicate = await repo2.addXp(30, 'reinf_1');
      expect(xpAfterDuplicate, equals(expected.xp));

      // Reset clears persisted snapshot
      await repo2.resetAll();
      final repo3 = InMemoryLearnerRepository(
        storage: await LocalStorageService.load(),
      );
      final afterReset = await repo3.getProfile();
      expect(afterReset.name, equals('Foydalanuvchi'));
      expect(afterReset.xp, equals(0));
      expect(afterReset.completedLessonIds, isEmpty);
    });

    test('corrupt JSON snapshot falls back safely to clean default state', () async {
      SharedPreferences.setMockInitialValues({
        LocalStorageService.demoLearnerSnapshotKey: '{not valid json!!',
      });
      final storage = await LocalStorageService.load();
      final repo = InMemoryLearnerRepository(storage: storage);

      final profile = await repo.getProfile();
      expect(profile.name, equals('Foydalanuvchi'));
      expect(profile.xp, equals(0));
      expect(profile.scoresByCourse, isEmpty);
    });

    test('handles non-string optional attempt fields and clamps out-of-range skill scores', () async {
      final snapshot = jsonEncode({
        'version': 1,
        'profile': {
          'id': 'learner_mobile_01',
          'name': 'CustomName',
          'selectedCourseId': 'course_math_01',
          'goal': 'mastery',
          'dailyMinutes': 15,
          'initialLevel': 'intermediate',
          'courseLevels': {},
          'xp': 250,
          'streakDays': 2,
          'lastActiveDate': '2026-11-20',
          'scoresByCourse': {
            'course_math_01': {
              'skill_math_algebra': {
                'skillId': 'skill_math_algebra',
                'courseId': 'course_math_01',
                'score': 999,
                'lastUpdated': 1000,
              },
              'skill_math_functions': {
                'skillId': 'skill_math_functions',
                'courseId': 'course_math_01',
                'score': -10,
                'lastUpdated': 1000,
              },
            },
          },
          'completedLessonIds': [],
          'completedNodeIds': [],
          'completedReinforcementIds': [],
          'createdAt': 1000,
        },
        'answerAttempts': [
          {
            'id': 'att_1',
            'courseId': 'course_math_01',
            'skillId': 'skill_math_algebra',
            'lessonId': 'lesson_math_algebra_01',
            'questionId': 'q_1',
            'selectedIndex': 0,
            'selectedAnswer': 'A',
            'isCorrect': true,
            'timestamp': 1000,
            'correctOption': 12345,
            'explanation': 99,
          },
        ],
        'processedActionKeys': ['xp_key_1'],
        'recordedActivityDates': ['2026-11-20'],
        'skillBaselines': {},
      });

      SharedPreferences.setMockInitialValues({
        LocalStorageService.demoLearnerSnapshotKey: snapshot,
      });
      final storage = await LocalStorageService.load();
      final repo = InMemoryLearnerRepository(storage: storage);

      final profile = await repo.getProfile();
      expect(profile.name, equals('CustomName'));
      expect(profile.xp, equals(250));
      expect(
        profile.scoresByCourse['course_math_01']?['skill_math_algebra']?.score,
        equals(100),
      );
      expect(
        profile.scoresByCourse['course_math_01']?['skill_math_functions']?.score,
        equals(0),
      );

      // Idempotency key survived alongside non-string optional attempt fields
      final xpAfterDup = await repo.addXp(50, 'xp_key_1');
      expect(xpAfterDup, equals(250));
    });

    test('atomic hydration leaves default state if any snapshot section has corrupt structure', () async {
      final halfCorrupt = jsonEncode({
        'version': 1,
        'profile': {
          'name': 'CustomName',
          'xp': 250,
        },
        'processedActionKeys': 'not-a-list',
      });

      SharedPreferences.setMockInitialValues({
        LocalStorageService.demoLearnerSnapshotKey: halfCorrupt,
      });
      final storage = await LocalStorageService.load();
      final repo = InMemoryLearnerRepository(storage: storage);

      final profile = await repo.getProfile();
      expect(profile.name, equals('Foydalanuvchi'));
      expect(profile.xp, equals(0));
    });

    test('non-Map or malformed item in answerAttempts aborts hydration atomically without shifting attemptCountAtBaseline', () async {
      final corruptAttemptSnapshot = jsonEncode({
        'version': 1,
        'profile': {
          'id': 'learner_mobile_01',
          'name': 'CustomName',
          'selectedCourseId': 'course_math_01',
          'goal': 'mastery',
          'dailyMinutes': 15,
          'initialLevel': 'intermediate',
          'courseLevels': {},
          'xp': 250,
          'streakDays': 2,
          'lastActiveDate': '2026-11-20',
          'scoresByCourse': {
            'course_math_01': {
              'skill_math_algebra': {
                'skillId': 'skill_math_algebra',
                'courseId': 'course_math_01',
                'score': 82,
                'lastUpdated': 1000,
              },
            },
          },
          'completedLessonIds': ['lesson_math_algebra_01'],
          'completedNodeIds': ['node_math_alg'],
          'completedReinforcementIds': [],
          'createdAt': 1000,
        },
        'answerAttempts': [
          'bad-entry',
          {
            'id': 'att_2',
            'courseId': 'course_math_01',
            'skillId': 'skill_math_algebra',
            'lessonId': 'lesson_math_algebra_01',
            'questionId': 'q_math_alg_01',
            'selectedIndex': 0,
            'selectedAnswer': 'wrong',
            'isCorrect': false,
            'timestamp': 2000,
          },
        ],
        'processedActionKeys': ['xp_key_1'],
        'recordedActivityDates': ['2026-11-20'],
        'skillBaselines': {
          'course_math_01': {
            'skill_math_algebra': {
              'score': 82,
              'attemptCountAtBaseline': 1,
            },
          },
        },
      });

      SharedPreferences.setMockInitialValues({
        LocalStorageService.demoLearnerSnapshotKey: corruptAttemptSnapshot,
      });
      final storage = await LocalStorageService.load();
      final repo = InMemoryLearnerRepository(storage: storage);

      final profile = await repo.getProfile();
      expect(profile.name, equals('Foydalanuvchi'));
      expect(profile.xp, equals(0));
      expect(profile.scoresByCourse, isEmpty);
      expect(profile.completedLessonIds, isEmpty);
      expect(await repo.getAnswerAttempts(), isEmpty);
    });

    test('concurrent resetAll prevents in-flight hydration from overwriting default state', () async {
      final gate = Completer<void>();
      final oldSnapshot = jsonEncode({
        'version': 1,
        'profile': {
          'name': 'OldSavedName',
          'xp': 999,
        },
      });
      final storage = _DelayedSnapshotStorage(gate, oldSnapshot);
      final repo = InMemoryLearnerRepository(storage: storage);

      final getProfileFuture = repo.getProfile();
      final resetFuture = repo.resetAll();
      gate.complete();

      final results = await Future.wait([getProfileFuture, resetFuture]);
      expect(results[0].name, equals('Foydalanuvchi'));
      expect(results[0].xp, equals(0));
      expect(results[1].name, equals('Foydalanuvchi'));
      expect(results[1].xp, equals(0));

      final after = await repo.getProfile();
      expect(after.name, equals('Foydalanuvchi'));
      expect(after.xp, equals(0));
    });

    test('resetAll mid-await during recordAnswerAttempt aborts resurrection and leaves null snapshot', () async {
      final storage = _BlockingWriteSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.getProfile();

      final attemptFuture = repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_algebra_01',
        questionId: 'q_math_alg_01',
        selectedIndex: 2,
        selectedAnswer: 'x=3',
        isCorrect: true,
      );
      await storage.writeEntered.future;

      await repo.resetAll();
      storage.releaseWrite();
      await attemptFuture;

      final after = await repo.getProfile();
      expect(after.name, equals('Foydalanuvchi'));
      expect(after.xp, equals(0));
      expect(after.scoresByCourse, isEmpty);
      expect(after.completedLessonIds, isEmpty);
      expect(await repo.getAnswerAttempts(), isEmpty);
      expect(storage.lastSnapshot, isNull);
      expect(await storage.getDemoLearnerSnapshot(), isNull);
    });

    test('resetAll mid-await during markLessonCompleted aborts resurrection and leaves null snapshot', () async {
      final storage = _BlockingWriteSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.getProfile();

      final completeFuture = repo.markLessonCompleted(
        'lesson_math_algebra_01',
        courseId: 'course_math_01',
      );
      await storage.writeEntered.future;

      await repo.resetAll();
      storage.releaseWrite();
      await completeFuture;

      final after = await repo.getProfile();
      expect(after.name, equals('Foydalanuvchi'));
      expect(after.xp, equals(0));
      expect(after.scoresByCourse, isEmpty);
      expect(after.completedLessonIds, isEmpty);
      expect(after.completedNodeIds, isEmpty);
      expect(storage.lastSnapshot, isNull);
      expect(await storage.getDemoLearnerSnapshot(), isNull);
    });

    test('concurrent unawaited resetAll suspended in clearDemoLearnerSnapshot does not wipe post-reset addXp or recordAnswerAttempt', () async {
      final storage = _BlockingClearSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.addXp(20, 'pre_reset');
      expect(storage.lastSnapshot, isNotNull);

      storage.armClearGate();
      final resetFuture = repo.resetAll();
      await storage.clearEntered.future;

      final postResetXpFuture = repo.addXp(55, 'post_reset_xp');
      final postResetAttemptFuture = repo.recordAnswerAttempt(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        lessonId: 'lesson_eng_vocab_01',
        questionId: 'q_eng_vocab_01_step',
        selectedIndex: 0,
        selectedAnswer: 'A',
        isCorrect: true,
      );
      await Future<void>.delayed(Duration.zero);

      storage.releaseClear();
      await Future.wait<void>([
        resetFuture,
        postResetXpFuture,
        postResetAttemptFuture,
      ]);

      final inMem = await repo.getProfile();
      expect(inMem.xp, equals(57));
      expect(storage.lastSnapshot, isNotNull);
      expect(storage.ops.first, equals('set'));
      expect(
        storage.ops.indexOf('clear'),
        lessThan(storage.ops.lastIndexOf('set')),
      );

      final reloaded = InMemoryLearnerRepository(storage: storage);
      final restored = await reloaded.getProfile();
      expect(restored.xp, equals(57));
      expect(restored.scoresByCourse.containsKey('course_eng_01'), isTrue);
      expect(await reloaded.getAnswerAttempts(), hasLength(1));
    });

    test('second resetAll while post-reset write awaits pending clear aborts stale epoch write and preserves null snapshot', () async {
      final storage = _BlockingClearSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.addXp(10, 'initial');

      storage.armClearGate();
      final firstReset = repo.resetAll();
      await storage.clearEntered.future;

      final abortedXpFuture = repo.addXp(55, 'epoch1_xp');
      await Future<void>.delayed(Duration.zero);

      final secondReset = repo.resetAll();
      storage.releaseClear();
      await Future.wait<void>([firstReset, abortedXpFuture, secondReset]);

      final after = await repo.getProfile();
      expect(after.xp, equals(0));
      expect(storage.lastSnapshot, isNull);
      expect(await storage.getDemoLearnerSnapshot(), isNull);
    });

    test('pre-reset blocked write does not deadlock resetAll and preserves subsequent post-reset mutation', () async {
      final storage = _BlockingWriteSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.getProfile();

      final staleWriteFuture = repo.addXp(40, 'stale_pre_reset');
      await storage.writeEntered.future;

      await repo.resetAll();
      final postResetFuture = repo.addXp(55, 'post_reset_xp');

      storage.releaseWrite();
      await Future.wait<void>([staleWriteFuture, postResetFuture]);

      final reloaded = InMemoryLearnerRepository(storage: storage);
      final restored = await reloaded.getProfile();
      expect(restored.xp, equals(55));
      expect(storage.lastSnapshot, isNotNull);
    });

    test('error in clearDemoLearnerSnapshot does not poison subsequent addXp or resetAll', () async {
      final storage = _FailingClearSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.addXp(25, 'before_fail');

      storage.throwOnClear = true;
      await expectLater(repo.resetAll(), throwsStateError);

      storage.throwOnClear = false;
      await repo.addXp(55, 'after_fail');
      final reloaded1 = InMemoryLearnerRepository(storage: storage);
      expect((await reloaded1.getProfile()).xp, equals(55));

      await repo.resetAll();
      final reloaded2 = InMemoryLearnerRepository(storage: storage);
      expect((await reloaded2.getProfile()).xp, equals(0));
      expect(storage.lastSnapshot, isNull);
    });

    test('PROBE_REPO_5a: markLessonCompleted failure in setDemoLearnerSnapshot flushes persisted snapshot on retry', () async {
      final storage = _FlakySetSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.getProfile();

      storage.throwOnSet = true;
      await expectLater(
        repo.markLessonCompleted(
          'lesson_math_algebra_01',
          courseId: 'course_math_01',
        ),
        throwsStateError,
      );

      storage.throwOnSet = false;
      await repo.markLessonCompleted(
        'lesson_math_algebra_01',
        courseId: 'course_math_01',
      );

      final reloaded = InMemoryLearnerRepository(storage: storage);
      final restored = await reloaded.getProfile();
      expect(restored.xp, equals(20));
      expect(restored.completedLessonIds, contains('lesson_math_algebra_01'));
      expect(restored.completedNodeIds, contains('node_math_alg'));
    });

    test('PROBE_REPO_5d: addXp idempotency key failure in setDemoLearnerSnapshot flushes persisted snapshot on retry', () async {
      final storage = _FlakySetSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.addXp(10, 'init_ok');

      storage.throwOnSet = true;
      await expectLater(repo.addXp(25, 'key_25'), throwsStateError);

      storage.throwOnSet = false;
      final retryXp = await repo.addXp(25, 'key_25');
      expect(retryXp, equals(35));

      final reloaded = InMemoryLearnerRepository(storage: storage);
      final restored = await reloaded.getProfile();
      expect(restored.xp, equals(35));
    });

    test('PROBE_7: recordAnswerAttempt failure in setDemoLearnerSnapshot leaves no partial XP, attempts, or scores and retries cleanly', () async {
      final storage = _FlakySetSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.getProfile();

      storage.throwOnSet = true;
      await expectLater(
        repo.recordAnswerAttempt(
          courseId: 'course_math_01',
          skillId: 'skill_math_algebra',
          lessonId: 'lesson_math_algebra_01',
          questionId: 'q_math_alg_01',
          selectedIndex: 2,
          selectedAnswer: 'x=3',
          isCorrect: true,
        ),
        throwsStateError,
      );

      final afterFail = await repo.getProfile();
      expect(afterFail.xp, equals(0));
      expect(afterFail.scoresByCourse, isEmpty);
      expect(await repo.getAnswerAttempts(), isEmpty);
      expect(storage.lastSnapshot, isNull);

      storage.throwOnSet = false;
      await repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_algebra_01',
        questionId: 'q_math_alg_01',
        selectedIndex: 2,
        selectedAnswer: 'x=3',
        isCorrect: true,
      );

      final afterRetry = await repo.getProfile();
      expect(afterRetry.xp, equals(2));
      expect(await repo.getAnswerAttempts(), hasLength(1));
      final retryScore =
          afterRetry.scoresByCourse['course_math_01']?['skill_math_algebra'];
      expect(retryScore, isNotNull);

      final reloaded = InMemoryLearnerRepository(storage: storage);
      final restored = await reloaded.getProfile();
      expect(restored.xp, equals(2));
      expect(await reloaded.getAnswerAttempts(), hasLength(1));
      expect(
        restored.scoresByCourse['course_math_01']?['skill_math_algebra']?.score,
        equals(retryScore!.score),
      );

      // Subsequent failure preserves prior persisted state without partial leak
      await repo.addXp(8, 'prior_bonus');
      storage.throwOnSet = true;
      await expectLater(
        repo.recordAnswerAttempt(
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_vocab_01',
          questionId: 'q_eng_vocab_01_step',
          selectedIndex: 0,
          selectedAnswer: 'A',
          isCorrect: true,
        ),
        throwsStateError,
      );
      final afterSecondFail = await repo.getProfile();
      expect(afterSecondFail.xp, equals(10));
      expect(afterSecondFail.scoresByCourse.containsKey('course_eng_01'), isFalse);
      expect(await repo.getAnswerAttempts(), hasLength(1));

      storage.throwOnSet = false;
      await repo.recordAnswerAttempt(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        lessonId: 'lesson_eng_vocab_01',
        questionId: 'q_eng_vocab_01_step',
        selectedIndex: 0,
        selectedAnswer: 'A',
        isCorrect: true,
      );
      final afterSecondRetry = await repo.getProfile();
      expect(afterSecondRetry.xp, equals(12));
      expect(afterSecondRetry.scoresByCourse.containsKey('course_eng_01'), isTrue);
      expect(await repo.getAnswerAttempts(), hasLength(2));
    });

    test('PROBE_7_2B: failed recordAnswerAttempt does not leak into concurrent succeeding addXp snapshot', () async {
      final storage = _QueuedControllableSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.getProfile();

      storage.enqueueWriteGate(shouldFail: true);
      final failedAttempt = repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_algebra_01',
        questionId: 'q_math_alg_01',
        selectedIndex: 2,
        selectedAnswer: 'x=3',
        isCorrect: true,
      );
      await storage.firstWriteEntered.future;

      final concurrentXp = repo.addXp(10, 'concurrent_bonus');
      await Future<void>.delayed(Duration.zero);

      storage.releaseFirstWrite();
      await expectLater(failedAttempt, throwsStateError);
      await concurrentXp;

      final inMem = await repo.getProfile();
      expect(inMem.xp, equals(10));
      expect(inMem.scoresByCourse, isEmpty);
      expect(await repo.getAnswerAttempts(), isEmpty);

      final reloaded = InMemoryLearnerRepository(storage: storage);
      final restored = await reloaded.getProfile();
      expect(restored.xp, equals(10));
      expect(restored.scoresByCourse, isEmpty);
      expect(await reloaded.getAnswerAttempts(), isEmpty);
    });

    test('PROBE_7_3A: failed recordAnswerAttempt does not wipe concurrent succeeding same-skill recordAnswerAttempt score', () async {
      final storage = _QueuedControllableSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.getProfile();

      storage.enqueueWriteGate(shouldFail: true);
      final call1 = repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_algebra_01',
        questionId: 'q_math_alg_01',
        selectedIndex: 2,
        selectedAnswer: 'x=3',
        isCorrect: true,
      );
      await storage.firstWriteEntered.future;

      final call2 = repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_algebra_01',
        questionId: 'q_math_alg_02',
        selectedIndex: 1,
        selectedAnswer: 'x=5',
        isCorrect: true,
      );
      await Future<void>.delayed(Duration.zero);

      storage.releaseFirstWrite();
      await expectLater(call1, throwsStateError);
      await call2;

      final inMem = await repo.getProfile();
      expect(inMem.xp, equals(2));
      expect(await repo.getAnswerAttempts(), hasLength(1));
      expect(
        inMem.scoresByCourse['course_math_01']?['skill_math_algebra'],
        isNotNull,
      );

      final reloaded = InMemoryLearnerRepository(storage: storage);
      final restored = await reloaded.getProfile();
      expect(restored.xp, equals(2));
      expect(await reloaded.getAnswerAttempts(), hasLength(1));
      expect(
        restored.scoresByCourse['course_math_01']?['skill_math_algebra']?.score,
        equals(inMem.scoresByCourse['course_math_01']?['skill_math_algebra']?.score),
      );
    });

    test('PROBE_7_3B: two concurrent failing recordAnswerAttempt calls leave zero phantom XP or skill scores', () async {
      final storage = _QueuedControllableSnapshotStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.getProfile();

      storage.enqueueWriteGate(shouldFail: true);
      final call1 = repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_algebra_01',
        questionId: 'q_math_alg_01',
        selectedIndex: 2,
        selectedAnswer: 'x=3',
        isCorrect: true,
      );
      await storage.firstWriteEntered.future;

      storage.enqueueWriteGate(shouldFail: true, releaseImmediately: true);
      final call2 = repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_algebra_01',
        questionId: 'q_math_alg_02',
        selectedIndex: 1,
        selectedAnswer: 'x=5',
        isCorrect: true,
      );
      await Future<void>.delayed(Duration.zero);

      storage.releaseFirstWrite();
      await expectLater(call1, throwsStateError);
      await expectLater(call2, throwsStateError);

      final inMem = await repo.getProfile();
      expect(inMem.xp, equals(0));
      expect(inMem.scoresByCourse, isEmpty);
      expect(await repo.getAnswerAttempts(), isEmpty);
    });

    test('PROBE_7_4: failed recordAnswerAttempt reverts streakDays, lastActiveDate, and recordedActivityDates under concurrent addXp', () async {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .split('T')
          .first;
      final storage = _QueuedControllableSnapshotStorage(
        initialSnapshot: jsonEncode({
          'version': 1,
          'profile': {
            'id': 'learner_mobile_01',
            'name': 'Foydalanuvchi',
            'selectedCourseId': 'course_math_01',
            'goal': 'mastery',
            'dailyMinutes': 15,
            'initialLevel': 'intermediate',
            'courseLevels': {},
            'xp': 0,
            'streakDays': 2,
            'lastActiveDate': yesterday,
            'scoresByCourse': {},
            'completedLessonIds': [],
            'completedNodeIds': [],
            'completedReinforcementIds': [],
            'createdAt': 1000,
          },
          'answerAttempts': [],
          'processedActionKeys': [],
          'recordedActivityDates': [yesterday],
          'skillBaselines': {},
        }),
      );
      final repo = InMemoryLearnerRepository(storage: storage);
      await repo.getProfile();

      storage.enqueueWriteGate(shouldFail: true);
      final failedAttempt = repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_algebra_01',
        questionId: 'q_math_alg_01',
        selectedIndex: 2,
        selectedAnswer: 'x=3',
        isCorrect: true,
      );
      await storage.firstWriteEntered.future;

      final concurrentXp = repo.addXp(5, 'bonus');
      await Future<void>.delayed(Duration.zero);

      storage.releaseFirstWrite();
      await expectLater(failedAttempt, throwsStateError);
      await concurrentXp;

      final inMem = await repo.getProfile();
      expect(inMem.xp, equals(5));
      expect(inMem.streakDays, equals(2));
      expect(inMem.lastActiveDate, equals(yesterday));

      // Subsequent recordDailyActivity for today still advances streak to 3
      final newStreak = await repo.recordDailyActivity();
      expect(newStreak, equals(3));
    });
  });
}

class _BlockingWriteSnapshotStorage extends LocalStorageService {
  final Completer<void> writeEntered = Completer<void>();
  final Completer<void> _writeGate = Completer<void>();
  String? lastSnapshot;

  void releaseWrite() {
    if (!_writeGate.isCompleted) _writeGate.complete();
  }

  @override
  Future<String?> getDemoLearnerSnapshot() async => lastSnapshot;

  @override
  Future<void> setDemoLearnerSnapshot(String json) async {
    if (!writeEntered.isCompleted) writeEntered.complete();
    await _writeGate.future;
    lastSnapshot = json;
  }

  @override
  Future<void> clearDemoLearnerSnapshot() async {
    lastSnapshot = null;
  }
}

class _BlockingClearSnapshotStorage extends LocalStorageService {
  Completer<void> clearEntered = Completer<void>();
  Completer<void>? _clearGate;
  String? lastSnapshot;
  final List<String> ops = [];

  void armClearGate() {
    clearEntered = Completer<void>();
    _clearGate = Completer<void>();
  }

  void releaseClear() {
    final gate = _clearGate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

  @override
  Future<String?> getDemoLearnerSnapshot() async => lastSnapshot;

  @override
  Future<void> setDemoLearnerSnapshot(String json) async {
    ops.add('set');
    lastSnapshot = json;
  }

  @override
  Future<void> clearDemoLearnerSnapshot() async {
    if (!clearEntered.isCompleted) clearEntered.complete();
    final gate = _clearGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    ops.add('clear');
    lastSnapshot = null;
  }
}

class _FailingClearSnapshotStorage extends LocalStorageService {
  bool throwOnClear = false;
  String? lastSnapshot;

  @override
  Future<String?> getDemoLearnerSnapshot() async => lastSnapshot;

  @override
  Future<void> setDemoLearnerSnapshot(String json) async {
    lastSnapshot = json;
  }

  @override
  Future<void> clearDemoLearnerSnapshot() async {
    if (throwOnClear) {
      throw StateError('clear failed');
    }
    lastSnapshot = null;
  }
}

class _DelayedSnapshotStorage extends LocalStorageService {
  final Completer<void> _gate;
  final String _snapshot;
  bool _cleared = false;

  _DelayedSnapshotStorage(this._gate, this._snapshot);

  @override
  Future<String?> getDemoLearnerSnapshot() async {
    await _gate.future;
    return _cleared ? null : _snapshot;
  }

  @override
  Future<void> clearDemoLearnerSnapshot() async {
    _cleared = true;
  }
}

class _FlakySetSnapshotStorage extends LocalStorageService {
  bool throwOnSet = false;
  String? lastSnapshot;

  @override
  Future<String?> getDemoLearnerSnapshot() async => lastSnapshot;

  @override
  Future<void> setDemoLearnerSnapshot(String json) async {
    if (throwOnSet) {
      throw StateError('injected set failure');
    }
    lastSnapshot = json;
  }

  @override
  Future<void> clearDemoLearnerSnapshot() async {
    lastSnapshot = null;
  }
}

class _WritePlan {
  final bool shouldFail;
  final Completer<void>? gate;
  _WritePlan({required this.shouldFail, required this.gate});
}

class _QueuedControllableSnapshotStorage extends LocalStorageService {
  String? lastSnapshot;
  final Completer<void> firstWriteEntered = Completer<void>();
  final List<_WritePlan> _plans = [];
  Completer<void>? _firstGate;

  _QueuedControllableSnapshotStorage({String? initialSnapshot})
    : lastSnapshot = initialSnapshot;

  void enqueueWriteGate({
    required bool shouldFail,
    bool releaseImmediately = false,
  }) {
    final gate = releaseImmediately ? null : Completer<void>();
    if (!releaseImmediately && _firstGate == null) {
      _firstGate = gate;
    }
    _plans.add(_WritePlan(shouldFail: shouldFail, gate: gate));
  }

  void releaseFirstWrite() {
    final gate = _firstGate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

  @override
  Future<String?> getDemoLearnerSnapshot() async => lastSnapshot;

  @override
  Future<void> setDemoLearnerSnapshot(String json) async {
    if (!firstWriteEntered.isCompleted) {
      firstWriteEntered.complete();
    }
    final plan = _plans.isNotEmpty ? _plans.removeAt(0) : null;
    if (plan?.gate != null) {
      await plan!.gate!.future;
    }
    if (plan?.shouldFail == true) {
      throw StateError('injected queued failure');
    }
    lastSnapshot = json;
  }

  @override
  Future<void> clearDemoLearnerSnapshot() async {
    lastSnapshot = null;
  }
}
