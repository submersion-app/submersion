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

/// Issue #5098: the chart options offer the trim line only on a dive whose
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

  Future<ProviderContainer> open(WidgetTester tester) async {
    await tester.pumpAndSettle();
    for (final section in ['Overlays', 'Gas Analysis', 'Other']) {
      if (find.text('Trim').evaluate().isNotEmpty) break;
      if (find.text(section).evaluate().isNotEmpty) {
        await tester.tap(find.text(section));
        await tester.pumpAndSettle();
      }
    }
    return ProviderScope.containerOf(
      tester.element(find.byType(ChartOptionsDialog)),
    );
  }

  testWidgets('the Trim row toggles its line, off by default', (tester) async {
    await tester.pumpWidget(
      dialog(
        const ProfileLegendConfig(hasTemperatureData: true, hasTrim: true),
      ),
    );
    final container = await open(tester);

    expect(container.read(profileLegendProvider).showTrim, isFalse);
    await tester.ensureVisible(find.text('Trim'));
    await tester.tap(find.text('Trim'));
    await tester.pumpAndSettle();
    expect(container.read(profileLegendProvider).showTrim, isTrue);
  });

  testWidgets('no Trim row on a dive without it', (tester) async {
    await tester.pumpWidget(
      dialog(const ProfileLegendConfig(hasTemperatureData: true)),
    );
    await open(tester);

    expect(find.text('Trim'), findsNothing);
  });
}
