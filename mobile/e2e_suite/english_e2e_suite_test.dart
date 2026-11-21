import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';
import 'tier1_features_test.dart';
import 'tier2_boundaries_test.dart';
import 'tier3_combinations_test.dart';
import 'tier4_scenarios_test.dart';

typedef TierRegistrar = void Function();

final List<TierRegistrar> _tierRegistrars = [
  registerTier1Tests,
  registerTier2Tests,
  registerTier3Tests,
  registerTier4Tests,
];

void main() {
  setUpAll(ensureE2eTestBinding);

  group('[M1] M_E2E_1 Harness Smoke Checks', () {
    testWidgets(
      'mobile390 demo -> course_eng_01 -> lesson_eng_starter -> Yolchi AI open/close preserves lesson',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.mobile390);
        await enterDemoMode(tester);

        expect(findCourseCard('Ingliz tili'), findsWidgets);
        expect(findCourseCard('Matematika'), findsWidgets);

        await selectCourse(tester, 'course_eng_01');
        expect(find.text('Qayerdan boshlamoqchisiz?'), findsOneWidget);

        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');

        expect(find.text('Birinchi inglizcha so‘zlar'), findsWidgets);
        expect(find.textContaining('Qadam 1 /'), findsOneWidget);
        expect(find.textContaining('«Hello» — salom'), findsWidgets);

        await openAndCloseYolchiAi(
          tester,
          askText: 'Hello qachon ishlatiladi?',
          preserveText: '«Hello» — salom',
        );

        expect(find.textContaining('Qadam 1 /'), findsOneWidget);
        expect(find.textContaining('«Hello» — salom'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'desktop1440 demo -> course_eng_01 -> lesson_eng_starter -> selectCourse from /lesson -> simulateAppRestart',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        expect(find.text('Qayerdan boshlamoqchisiz?'), findsOneWidget);

        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        expect(find.text('Birinchi inglizcha so‘zlar'), findsWidgets);

        await selectCourse(tester, 'course_math_01');
        expect(find.text('Qayerdan boshlamoqchisiz?'), findsOneWidget);

        await simulateAppRestart(
          tester,
          viewport: ViewportPreset.desktop1440,
          keepDemoSession: true,
        );

        expect(find.text('Qaysi fanni o‘rganishni istaysiz?'), findsOneWidget);
        expect(findCourseCard('Ingliz tili'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });

  for (final registerTier in _tierRegistrars) {
    registerTier();
  }
}
