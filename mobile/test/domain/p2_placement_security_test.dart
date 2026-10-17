import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilimyol_mobile/app/providers.dart';

void main() {
  group('P2 Placement Test Security & Anti-Cheat (Flutter)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes placement state with question start timestamp', () async {
      final notifier = container.read(placementStateNotifierProvider.notifier);
      await notifier.loadQuestions('course_math_01');

      final state = container.read(placementStateNotifierProvider);
      expect(state.hasLoaded, isTrue);
      expect(state.currentQuestion, isNotNull);
      expect(state.questionStartedAt, isNotNull);
      expect(state.submissions, isEmpty);
      expect(state.history, isEmpty);
    });

    test('rejects negative or out-of-bounds selectedIndex without crashing', () async {
      final notifier = container.read(placementStateNotifierProvider.notifier);
      await notifier.loadQuestions('course_math_01');

      // Negative index
      final negativeResult = await notifier.submitAnswer(-1);
      expect(negativeResult, isFalse);

      // Out of bounds index
      final outOfBoundsResult = await notifier.submitAnswer(999);
      expect(outOfBoundsResult, isFalse);

      final state = container.read(placementStateNotifierProvider);
      expect(state.submissions, isEmpty);
    });

    test('rate limits rapid consecutive submissions within 800ms', () async {
      final notifier = container.read(placementStateNotifierProvider.notifier);
      await notifier.loadQuestions('course_math_01');

      // First valid submission
      final firstSubmit = await notifier.submitAnswer(0);
      expect(firstSubmit, isFalse); // False indicates test is still in progress

      // Immediate second submission (< 800ms) must be throttled
      final throttledSubmit = await notifier.submitAnswer(0);
      expect(throttledSubmit, isFalse);

      final state = container.read(placementStateNotifierProvider);
      // Exactly 1 submission registered, 2nd was throttled
      expect(state.submissions.length, equals(1));
    });

    test('tracks real time spent per question and clamps to [1, 600]', () async {
      final notifier = container.read(placementStateNotifierProvider.notifier);
      await notifier.loadQuestions('course_math_01');

      await notifier.submitAnswer(0);

      final state = container.read(placementStateNotifierProvider);
      expect(state.submissions.isNotEmpty, isTrue);
      final submission = state.submissions.first;
      expect(submission.timeSpentSeconds, greaterThanOrEqualTo(1));
      expect(submission.timeSpentSeconds, lessThanOrEqualTo(600));
    });
  });
}
