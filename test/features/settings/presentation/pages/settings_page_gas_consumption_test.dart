import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Records what the picker asks the notifier to persist, without touching the
/// database. Everything except the display falls through to noSuchMethod.
class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _RecordingSettingsNotifier(super.settings);

  final List<GasConsumptionDisplay> saved = [];

  @override
  Future<void> setGasConsumptionDisplay(GasConsumptionDisplay display) async {
    saved.add(display);
    state = state.copyWith(gasConsumptionDisplay: display);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Settings > Units > Gas consumption offers SAC, RMV, or Both (spec D6).
void main() {
  late _RecordingSettingsNotifier notifier;

  Widget host(AppSettings settings) {
    notifier = _RecordingSettingsNotifier(settings);
    return ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsSectionDetailPage(sectionId: 'units'),
      ),
    );
  }

  Future<void> openTile(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Gas consumption'), 50.0);
    await tester.pumpAndSettle();
  }

  group('gas consumption picker', () {
    testWidgets('the tile reports Both by default', (tester) async {
      await tester.pumpWidget(host(const AppSettings()));
      await openTile(tester);

      expect(find.text('Gas consumption'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
    });

    testWidgets('the tile names a single lane with its unit', (tester) async {
      await tester.pumpWidget(
        host(
          const AppSettings(
            gasConsumptionDisplay: GasConsumptionDisplay.sac,
            pressureUnit: PressureUnit.psi,
          ),
        ),
      );
      await openTile(tester);

      expect(find.text('SAC (psi/min)'), findsOneWidget);
    });

    testWidgets('the picker offers SAC, RMV, and Both with subtitles', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AppSettings()));
      await openTile(tester);
      await tester.tap(find.text('Gas consumption'));
      await tester.pumpAndSettle();

      expect(find.text('Gas consumption display'), findsOneWidget);
      expect(
        find.text(
          'Tank pressure drop per minute (bar/min). Works with any logged '
          'pressures.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Gas volume breathed per minute at the surface (L/min). Needs a '
          'tank volume.',
        ),
        findsOneWidget,
      );
      expect(find.text('Show SAC and RMV side by side.'), findsOneWidget);
    });

    testWidgets('choosing RMV persists it and closes the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AppSettings()));
      await openTile(tester);
      await tester.tap(find.text('Gas consumption'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'RMV'));
      await tester.pumpAndSettle();

      expect(notifier.saved, [GasConsumptionDisplay.rmv]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('RMV (L/min)'), findsOneWidget);
    });
  });
}
