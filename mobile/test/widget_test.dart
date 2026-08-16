import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilimyol_mobile/app/app.dart';

void main() {
  testWidgets('BilimYolApp smoke test and renders course selection', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BilimYolApp(),
      ),
    );

    // Initial load frame
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Matematika'), findsWidgets);
    expect(find.text('Ingliz tili'), findsWidgets);
  });
}
