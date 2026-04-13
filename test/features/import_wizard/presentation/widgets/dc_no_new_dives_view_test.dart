import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  testWidgets('renders breadcrumb TextButton with expected text', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(home: DcNoNewDivesView(onDone: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    expect(
      find.textContaining('Looking for older or deleted dives'),
      findsOneWidget,
    );
  });

  testWidgets('tapping breadcrumb invokes onDone', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      localizedMaterialApp(home: DcNoNewDivesView(onDone: () => tapped++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Looking for older'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets('tapping Done also invokes onDone', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      localizedMaterialApp(home: DcNoNewDivesView(onDone: () => tapped++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });
}
