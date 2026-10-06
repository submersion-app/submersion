import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _dialog({required bool hasLateGasSwitches}) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => _StubSettingsNotifier())],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChartOptionsDialog(
        config: ProfileLegendConfig(
          hasGasSwitches: true,
          hasLateGasSwitches: hasLateGasSwitches,
        ),
        anchorOffset: const Offset(300, 0),
        anchorSize: const Size(40, 40),
      ),
    ),
  ),
);

void main() {
  testWidgets('the Markers section toggles late gas switches', (tester) async {
    await tester.pumpWidget(_dialog(hasLateGasSwitches: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Markers'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChartOptionsDialog)),
    );
    expect(container.read(profileLegendProvider).showLateGasSwitches, isTrue);
    await tester.tap(find.text('Late gas switches'));
    await tester.pumpAndSettle();
    expect(container.read(profileLegendProvider).showLateGasSwitches, isFalse);
  });

  testWidgets('a dive with no late switches has no such row', (tester) async {
    await tester.pumpWidget(_dialog(hasLateGasSwitches: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Markers'));
    await tester.pumpAndSettle();
    expect(find.text('Late gas switches'), findsNothing);
  });
}
