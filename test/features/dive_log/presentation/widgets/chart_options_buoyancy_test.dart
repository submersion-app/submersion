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

/// Issue #4593: the chart options offer the buoyancy line only where the
/// dive can be modelled.
void main() {
  Widget dialog({required bool hasBuoyancy}) => ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _StubSettingsNotifier()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChartOptionsDialog(
          config: ProfileLegendConfig(
            hasTemperatureData: true,
            hasBuoyancy: hasBuoyancy,
          ),
          anchorOffset: const Offset(300, 0),
          anchorSize: const Size(40, 40),
        ),
      ),
    ),
  );

  Future<ProviderContainer> openOverlays(WidgetTester tester) async {
    await tester.pumpAndSettle();
    if (find.text('Buoyancy').evaluate().isEmpty &&
        find.text('Overlays').evaluate().isNotEmpty) {
      await tester.tap(find.text('Overlays'));
      await tester.pumpAndSettle();
    }
    return ProviderScope.containerOf(
      tester.element(find.byType(ChartOptionsDialog)),
    );
  }

  testWidgets('the row toggles the line, off by default', (tester) async {
    await tester.pumpWidget(dialog(hasBuoyancy: true));
    final container = await openOverlays(tester);

    expect(container.read(profileLegendProvider).showBuoyancy, isFalse);
    await tester.tap(find.text('Buoyancy'));
    await tester.pumpAndSettle();
    expect(container.read(profileLegendProvider).showBuoyancy, isTrue);
  });

  testWidgets('options row only when available', (tester) async {
    await tester.pumpWidget(dialog(hasBuoyancy: false));
    await openOverlays(tester);

    expect(find.text('Buoyancy'), findsNothing);
  });
}
