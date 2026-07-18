import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/widgets/pscr_settings_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets('reflects a pSCR ratio that changes after init (async load)', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(
      testApp(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const PscrSettingsSection(),
      ),
    );
    await tester.pumpAndSettle();

    // Starts at the default while "settings load".
    expect(find.widgetWithText(TextFormField, '100'), findsOneWidget);

    // The loaded/changed value propagates into the field (the bug Copilot
    // flagged: an init-once controller would still show 100).
    await notifier.setPscrRatio(250);
    await tester.pump();
    expect(find.widgetWithText(TextFormField, '250'), findsOneWidget);
  });

  testWidgets('editing the field writes the pSCR ratio setting', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(
      testApp(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const PscrSettingsSection(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '180');
    await tester.pump();
    expect(notifier.state.pscrRatio, 180.0);
  });
}
