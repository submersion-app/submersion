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

  final showAllCalls = <bool>[];

  @override
  Future<void> setCounterdiffusionShowAll(bool value) async {
    showAllCalls.add(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Issue #4530: the chart options offer the counterdiffusion overlay with an
/// ICD | All choice, only where helium is breathed or held.
void main() {
  late _StubSettingsNotifier settings;

  Widget dialog({required bool hasCounterdiffusion}) {
    settings = _StubSettingsNotifier();
    return ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => settings)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChartOptionsDialog(
            config: ProfileLegendConfig(
              hasGasSwitches: true,
              hasCounterdiffusion: hasCounterdiffusion,
            ),
            anchorOffset: const Offset(300, 0),
            anchorSize: const Size(40, 40),
          ),
        ),
      ),
    );
  }

  Future<ProviderContainer> openMarkers(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.text('Markers'));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(ChartOptionsDialog)),
    );
  }

  testWidgets('the row toggles the overlay, off by default', (tester) async {
    await tester.pumpWidget(dialog(hasCounterdiffusion: true));
    final container = await openMarkers(tester);

    expect(container.read(profileLegendProvider).showCounterdiffusion, isFalse);
    await tester.tap(find.text('Counterdiffusion'));
    await tester.pumpAndSettle();
    expect(container.read(profileLegendProvider).showCounterdiffusion, isTrue);
  });

  testWidgets('All shows every opposing phase and is remembered', (
    tester,
  ) async {
    await tester.pumpWidget(dialog(hasCounterdiffusion: true));
    final container = await openMarkers(tester);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(
      container.read(profileLegendProvider).counterdiffusionShowAll,
      isTrue,
    );
    expect(settings.showAllCalls, [true]);
  });

  testWidgets('a dive without helium has no such row', (tester) async {
    await tester.pumpWidget(dialog(hasCounterdiffusion: false));
    await openMarkers(tester);

    expect(find.text('Counterdiffusion'), findsNothing);
  });
}
