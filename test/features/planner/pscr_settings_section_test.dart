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

  testWidgets('persists the final value after debounce, not per keystroke', (
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
    // Before the debounce elapses nothing is persisted (no per-keystroke
    // save storm / overlapping writes).
    await tester.pump(const Duration(milliseconds: 100));
    expect(notifier.state.pscrRatio, 100.0);

    // After the debounce, the final value lands exactly once.
    await tester.pump(const Duration(milliseconds: 300));
    expect(notifier.state.pscrRatio, 180.0);
  });

  testWidgets('clearing the field before the debounce drops the pending edit', (
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

    // Type a valid value, then clear the field before the debounce elapses.
    await tester.enterText(find.byType(TextFormField), '180');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextFormField), '');

    // The now-deleted 180 must not flush after the delay: invalid/empty input
    // cancels the pending save (regression for the stale-flush bug).
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.state.pscrRatio, 100.0);
  });
}
