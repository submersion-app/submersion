import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/default_visible_metrics_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setDefaultShowGtr(bool value) async =>
      state = state.copyWith(defaultShowGtr: value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget buildPage(_StubSettingsNotifier notifier) {
    return ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: DefaultVisibleMetricsPage(),
      ),
    );
  }

  testWidgets('toggles the GTR default', (tester) async {
    final notifier = _StubSettingsNotifier();
    await tester.pumpWidget(buildPage(notifier));
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(
      SwitchListTile,
      'GTR (Gas Time Remaining)',
    );
    await tester.scrollUntilVisible(tile, 100);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(notifier.state.defaultShowGtr, isTrue);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
  });
}
