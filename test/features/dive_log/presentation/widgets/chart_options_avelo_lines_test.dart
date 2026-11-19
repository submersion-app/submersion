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

/// Issue #4664: the chart options offer each Avelo line only on a dive whose
/// samples carry it, and the row toggles it.
void main() {
  Widget dialog(ProfileLegendConfig config) => ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _StubSettingsNotifier()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChartOptionsDialog(
          config: config,
          anchorOffset: const Offset(300, 0),
          anchorSize: const Size(40, 40),
        ),
      ),
    ),
  );

  Future<ProviderContainer> open(WidgetTester tester, String label) async {
    await tester.pumpAndSettle();
    for (final section in ['Overlays', 'Gas Analysis', 'Other']) {
      if (find.text(label).evaluate().isNotEmpty) break;
      if (find.text(section).evaluate().isNotEmpty) {
        await tester.tap(find.text(section));
        await tester.pumpAndSettle();
      }
    }
    return ProviderScope.containerOf(
      tester.element(find.byType(ChartOptionsDialog)),
    );
  }

  const all = ProfileLegendConfig(
    hasTemperatureData: true,
    hasAveloBuoyancy: true,
    hasAveloGasRemaining: true,
    hasComputerRmv: true,
  );

  for (final (label, read) in <(String, bool Function(ProfileLegendState))>[
    ('Avelo buoyancy', (s) => s.showAveloBuoyancy),
    ('Gas remaining', (s) => s.showAveloGasRemaining),
    ('RMV (computer)', (s) => s.showComputerRmv),
  ]) {
    testWidgets('the $label row toggles its line, off by default', (
      tester,
    ) async {
      await tester.pumpWidget(dialog(all));
      final container = await open(tester, label);

      expect(read(container.read(profileLegendProvider)), isFalse);
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(read(container.read(profileLegendProvider)), isTrue);
    });

    testWidgets('no $label row on a dive without it', (tester) async {
      await tester.pumpWidget(
        dialog(const ProfileLegendConfig(hasTemperatureData: true)),
      );
      await open(tester, label);

      expect(find.text(label), findsNothing);
    });
  }
}
