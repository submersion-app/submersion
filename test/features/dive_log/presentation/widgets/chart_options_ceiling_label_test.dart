import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #2552: the toggle names the ceiling the way the legend does, so the
/// row that switches "Ceiling (calc)" off is recognisably the same line.
class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _dialog({
  required bool labelCeilingAsCalculated,
  List<LegendOverlaySource> overlays = const [],
}) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => _StubSettingsNotifier())],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChartOptionsDialog(
        config: ProfileLegendConfig(
          hasCeilingCurve: true,
          labelCeilingAsCalculated: labelCeilingAsCalculated,
          overlays: overlays,
        ),
        anchorOffset: const Offset(300, 0),
        anchorSize: const Size(40, 40),
      ),
    ),
  ),
);

void main() {
  testWidgets('the row says calculated under the computer\'s stops', (
    tester,
  ) async {
    await tester.pumpWidget(_dialog(labelCeilingAsCalculated: true));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChartOptionsDialog)),
    );
    expect(container.read(profileLegendProvider).showCeiling, isTrue);
    await tester.tap(find.text('Ceiling (calc)'));
    await tester.pumpAndSettle();
    expect(container.read(profileLegendProvider).showCeiling, isFalse);
  });

  testWidgets('an overlaid source earns the label too', (tester) async {
    await tester.pumpWidget(
      _dialog(
        labelCeilingAsCalculated: false,
        overlays: const [
          LegendOverlaySource(
            name: 'Teric',
            metrics: {LegendMetric.ceiling},
            labelCeilingAsCalculated: true,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ceiling (calc)'), findsOneWidget);
  });

  testWidgets('the row stays plain otherwise', (tester) async {
    await tester.pumpWidget(_dialog(labelCeilingAsCalculated: false));
    await tester.pumpAndSettle();

    expect(find.text('Ceiling'), findsOneWidget);
    expect(find.text('Ceiling (calc)'), findsNothing);
  });
}
