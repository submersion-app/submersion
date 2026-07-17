import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/safety_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _buildTestWidget(MockSettingsNotifier notifier) {
  return ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => notifier)],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SafetySettingsPage(),
    ),
  );
}

void main() {
  testWidgets('renders master toggle on and five rule switches', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(_buildTestWidget(notifier));
    await tester.pumpAndSettle();

    expect(find.text('Post-dive safety review'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(6));

    final master = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile).first,
    );
    expect(master.value, isTrue);
  });

  testWidgets('toggling master off disables rule switches', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(_buildTestWidget(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    final ruleSwitches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .skip(1);
    for (final s in ruleSwitches) {
      expect(s.onChanged, isNull);
    }
  });
}
