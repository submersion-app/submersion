import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  testWidgets('renders expected text and icon', (tester) async {
    await tester.pumpWidget(
      localizedMaterialApp(home: DcNoNewDivesView(onDone: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('No new dives to download'), findsOneWidget);
    expect(
      find.text('All dives from this computer have already been imported.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('tapping Done invokes onDone', (tester) async {
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
