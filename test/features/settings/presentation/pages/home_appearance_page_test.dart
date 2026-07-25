import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/settings/presentation/pages/home_appearance_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<MockSettingsNotifier> pumpPage(WidgetTester tester) async {
    final notifier = MockSettingsNotifier();
    final overrides = await getBaseOverrides(settingsNotifier: notifier);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeAppearancePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('shows one enabled toggle per chip type', (tester) async {
    await pumpPage(tester);
    for (final type in HomeChipType.values) {
      final toggle = find.byKey(Key('homeChipToggle_${type.name}'));
      await tester.scrollUntilVisible(toggle, 100);
      expect(toggle, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    }
  });

  testWidgets('toggling a chip records it as hidden', (tester) async {
    final notifier = await pumpPage(tester);
    final toggle = find.byKey(const Key('homeChipToggle_noFly'));
    await tester.scrollUntilVisible(toggle, 100);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(notifier.state.hiddenHomeChips, contains('noFly'));
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });
}
