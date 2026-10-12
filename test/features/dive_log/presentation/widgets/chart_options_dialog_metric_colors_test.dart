import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/legend_candidates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #3012: the chart options dialog shows the diver's metric colours
/// and links to the page where they are chosen.
class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _purple = Color(0xFFE040FB);

Widget _app({
  ProfileLegendConfig config = const ProfileLegendConfig(hasPpO2Data: true),
  ProfileMetricColorOverrides? overrides,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierColor: Colors.transparent,
                builder: (_) => ChartOptionsDialog(
                  config: config,
                  anchorOffset: const Offset(300, 0),
                  anchorSize: const Size(40, 40),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/metric-colors',
        builder: (context, state) => const Text('colors page'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => _StubSettingsNotifier(
          AppSettings(
            defaultShowPpO2: true,
            profileMetricColors:
                overrides ??
                ProfileMetricColorOverrides.none.withColor(
                  ProfileMetric.ppO2,
                  _purple,
                ),
          ),
        ),
      ),
    ],
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

/// Every icon, fill and border colour drawn in the row labelled [label].
Set<Color> _rowColors(WidgetTester tester, String label) {
  final row = find.ancestor(of: find.text(label), matching: find.byType(Row));
  final colors = <Color>{};
  for (final element
      in find
          .descendant(of: row.first, matching: find.byType(Container))
          .evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration) {
      if (decoration.color != null) colors.add(decoration.color!);
      final border = decoration.border;
      if (border is Border) colors.add(border.top.color);
    }
  }
  for (final element
      in find
          .descendant(of: row.first, matching: find.byType(Icon))
          .evaluate()) {
    final color = (element.widget as Icon).color;
    if (color != null) colors.add(color);
  }
  return colors;
}

Future<void> _open(
  WidgetTester tester, {
  ProfileLegendConfig? config,
  ProfileMetricColorOverrides? overrides,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    config == null ? _app() : _app(config: config, overrides: overrides),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the ppO2 swatch takes the chosen colour', (tester) async {
    await _open(tester);
    if (find.text('ppO2').evaluate().isEmpty) {
      await tester.tap(find.text('Gas Analysis'));
      await tester.pumpAndSettle();
    }
    expect(_rowColors(tester, 'ppO2'), contains(_purple));
  });

  testWidgets('the Metric Colors link opens the settings page', (tester) async {
    await _open(tester);
    final link = find.text('Metric Colors');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('colors page'), findsOneWidget);
    expect(find.byType(ChartOptionsDialog), findsNothing);
  });

  testWidgets('every gas analysis swatch follows its chosen colour, and '
      'tanks without a cylinder keep the fallback colours', (tester) async {
    const colors = {
      ProfileMetric.ppN2: Color(0xFFE040FB),
      ProfileMetric.ppHe: Color(0xFF00E676),
      ProfileMetric.mod: Color(0xFFF50057),
      ProfileMetric.density: Color(0xFFFF7043),
    };
    var overrides = ProfileMetricColorOverrides.none;
    colors.forEach((m, c) => overrides = overrides.withColor(m, c));
    const series = [
      TankPressurePoint(tankId: 't1', timestamp: 0, pressure: 200),
    ];
    await _open(
      tester,
      config: const ProfileLegendConfig(
        hasPpN2Data: true,
        hasPpHeData: true,
        hasModData: true,
        hasDensityData: true,
        hasMultiTankPressure: true,
        tankPressures: {
          't1': series,
          't2': [TankPressurePoint(tankId: 't2', timestamp: 0, pressure: 200)],
        },
      ),
      overrides: overrides,
    );
    for (final section in ['Gas Analysis', 'Tank Pressures']) {
      final f = find.text(section);
      if (f.evaluate().isNotEmpty &&
          find
              .text(section == 'Gas Analysis' ? 'ppN2' : 'Tank 1')
              .evaluate()
              .isEmpty) {
        await tester.tap(f);
        await tester.pumpAndSettle();
      }
    }
    // A switched-off row draws a grey box; switch each on first (tanks
    // follow Pressure, which is on by default).
    for (final label in ['ppN2', 'ppHe', 'MOD', 'Gas Density']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(_rowColors(tester, 'ppN2'), contains(colors[ProfileMetric.ppN2]));
    expect(_rowColors(tester, 'ppHe'), contains(colors[ProfileMetric.ppHe]));
    expect(_rowColors(tester, 'MOD'), contains(colors[ProfileMetric.mod]));
    expect(
      _rowColors(tester, 'Gas Density'),
      contains(colors[ProfileMetric.density]),
    );
    expect(
      _rowColors(tester, 'Tank 1').map((c) => c.toARGB32()),
      contains(tankFallbackColor(0).toARGB32()),
    );
  });
}
