import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/ascent_rate_thresholds_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<MockSettingsNotifier> pump(
    WidgetTester tester, {
    DepthUnit depthUnit = DepthUnit.meters,
    double ascentRateWarning = 9.0,
  }) async {
    final settings = MockSettingsNotifier(
      AppSettings(depthUnit: depthUnit, ascentRateWarning: ascentRateWarning),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AscentRateThresholdsTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  Slider slider(WidgetTester tester, String key) =>
      tester.widget<Slider>(find.byKey(ValueKey(key)));

  testWidgets('shows both thresholds in metres', (tester) async {
    await pump(tester);

    expect(find.text('Ascent rate thresholds'), findsOneWidget);
    expect(find.text('Warning 9m/min, critical 12m/min'), findsOneWidget);
  });

  testWidgets('shows both thresholds in feet', (tester) async {
    await pump(tester, depthUnit: DepthUnit.feet);

    expect(find.text('Warning 30ft/min, critical 39ft/min'), findsOneWidget);
  });

  testWidgets('saving the dialog stores both thresholds', (tester) async {
    final settings = await pump(tester);

    await tester.tap(find.text('Ascent rate thresholds'));
    await tester.pumpAndSettle();
    slider(tester, 'ascent-rate-warning').onChanged!(10);
    await tester.pump();
    slider(tester, 'ascent-rate-critical').onChanged!(16);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(settings.state.ascentRateWarning, 10);
    expect(settings.state.ascentRateCritical, 16);
  });

  testWidgets('raising warning past critical carries critical with it', (
    tester,
  ) async {
    final settings = await pump(tester);

    await tester.tap(find.text('Ascent rate thresholds'));
    await tester.pumpAndSettle();
    slider(tester, 'ascent-rate-warning').onChanged!(15);
    await tester.pump();

    expect(slider(tester, 'ascent-rate-critical').value, 15);
    expect(find.text('15m/min'), findsNWidgets(2));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(settings.state.ascentRateWarning, 15);
    expect(settings.state.ascentRateCritical, 15);
  });

  testWidgets('lowering critical below warning carries warning with it', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Ascent rate thresholds'));
    await tester.pumpAndSettle();
    slider(tester, 'ascent-rate-critical').onChanged!(7);
    await tester.pump();

    expect(slider(tester, 'ascent-rate-warning').value, 7);
  });

  testWidgets('saving keeps an off-grid threshold the diver did not move', (
    tester,
  ) async {
    final settings = await pump(tester, ascentRateWarning: 9.5);

    await tester.tap(find.text('Ascent rate thresholds'));
    await tester.pumpAndSettle();
    slider(tester, 'ascent-rate-critical').onChanged!(14);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(settings.state.ascentRateWarning, 9.5);
    expect(settings.state.ascentRateCritical, 14);
  });

  testWidgets('saving unchanged thresholds writes nothing', (tester) async {
    final settings = await pump(tester);
    var writes = 0;
    settings.addListener((_) => writes++, fireImmediately: false);

    await tester.tap(find.text('Ascent rate thresholds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(writes, 0);
  });

  testWidgets('cancel changes nothing', (tester) async {
    final settings = await pump(tester);

    await tester.tap(find.text('Ascent rate thresholds'));
    await tester.pumpAndSettle();
    slider(tester, 'ascent-rate-warning').onChanged!(5);
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(settings.state.ascentRateWarning, 9);
    expect(settings.state.ascentRateCritical, 12);
  });
}
