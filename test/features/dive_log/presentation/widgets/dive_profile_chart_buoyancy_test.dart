import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_buoyancy_line.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_right_axis_tick_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// Issue #4593: the net buoyancy line on the dive profile.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _buoyant = ProfileMetricColors.buoyancyBuoyant;
const _heavy = ProfileMetricColors.buoyancyHeavy;

List<DiveProfilePoint> _profile() => List.generate(
  20,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < 10 ? i * 2.0 : (19 - i) * 2.0,
  ),
);

/// Heavy for the first eight samples, buoyant after.
List<double?> _crossingCurve() => [
  for (var i = 0; i < 20; i++) -2.0 + i * 0.25,
];

Widget _harness({
  required AppSettings settings,
  List<double?>? buoyancyCurve,
  bool buoyancyAvailable = true,
  void Function(List<TooltipRow>? rows)? onTooltipData,
  List<DiveProfilePoint>? profile,
  List<ChartSourceOverlay>? overlays,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 360,
          child: DiveProfileChart(
            profile: profile ?? _profile(),
            overlays: overlays,
            buoyancyCurve: buoyancyCurve,
            buoyancyAvailable: buoyancyAvailable,
            tooltipPresentation: TooltipPresentation.external,
            onTooltipData: onTooltipData,
          ),
        ),
      ),
    ),
  );
}

List<LineChartBarData> _bars(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData;

bool _isNeutralRule(LineChartBarData b) =>
    b.dashArray != null &&
    b.spots.length == 2 &&
    b.spots.first.y == b.spots.last.y &&
    b.barWidth < 1;

void main() {
  testWidgets('draws heavy and buoyant runs when on', (tester) async {
    await tester.pumpWidget(
      _harness(
        settings: const AppSettings(defaultShowBuoyancy: true),
        buoyancyCurve: _crossingCurve(),
      ),
    );
    await tester.pumpAndSettle();

    final bars = _bars(tester);
    expect(bars.where((b) => b.color == _heavy), hasLength(1));
    expect(bars.where((b) => b.color == _buoyant), hasLength(1));
    expect(bars.where(_isNeutralRule), hasLength(1));
  });

  testWidgets('the neutral rule follows the time axis as overlays change', (
    tester,
  ) async {
    // An overlaid computer that logged longer widens the time axis without
    // touching the active profile or the curve, so the cached rule must not
    // keep the old extent.
    final profile = _profile();
    final curve = _crossingCurve();
    const settings = AppSettings(defaultShowBuoyancy: true);
    await tester.pumpWidget(
      _harness(settings: settings, profile: profile, buoyancyCurve: curve),
    );
    await tester.pumpAndSettle();
    expect(_bars(tester).firstWhere(_isNeutralRule).spots.last.x, 570);

    final longer = List.generate(
      41,
      (i) => DiveProfilePoint(timestamp: i * 30, depth: 5),
    );
    await tester.pumpWidget(
      _harness(
        settings: settings,
        profile: profile,
        buoyancyCurve: curve,
        overlays: [
          ChartSourceOverlay(
            sourceId: 'src-b',
            name: 'Overlay',
            color: Colors.purple,
            computerId: 'comp-b',
            points: longer,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(_bars(tester).firstWhere(_isNeutralRule).spots.last.x, 1200);
  });

  testWidgets('draws nothing when off', (tester) async {
    await tester.pumpWidget(
      _harness(settings: const AppSettings(), buoyancyCurve: _crossingCurve()),
    );
    await tester.pumpAndSettle();

    final bars = _bars(tester);
    expect(
      bars.where((b) => b.color == _heavy || b.color == _buoyant),
      isEmpty,
    );
    expect(bars.where(_isNeutralRule), isEmpty);
  });

  testWidgets('draws nothing while the curve is still loading', (tester) async {
    await tester.pumpWidget(
      _harness(settings: const AppSettings(defaultShowBuoyancy: true)),
    );
    await tester.pumpAndSettle();
    expect(_bars(tester).where(_isNeutralRule), isEmpty);
  });

  testWidgets('one legend entry with two colours', (tester) async {
    await tester.pumpWidget(
      _harness(
        settings: const AppSettings(defaultShowBuoyancy: true),
        buoyancyCurve: _crossingCurve(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buoyancy'), findsOneWidget);
    final swatches = tester
        .widgetList<LegendSwatch>(find.byType(LegendSwatch))
        .where((s) => s.color == _buoyant && s.secondColor == _heavy);
    expect(swatches, hasLength(1));
  });

  testWidgets('no legend entry until the line has a curve to draw', (
    tester,
  ) async {
    // Loading, or a model that failed: advertising a line the chart does not
    // draw leaves the diver looking for it.
    await tester.pumpWidget(
      _harness(settings: const AppSettings(defaultShowBuoyancy: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buoyancy'), findsNothing);
  });

  testWidgets('signed axis ticks stay left to right in RTL locales', (
    tester,
  ) async {
    // Without it "-4.1" draws as "4.1-" in Arabic and Hebrew.
    await tester.pumpWidget(
      _harness(
        settings: const AppSettings(
          defaultShowBuoyancy: true,
          defaultRightAxisMetric: ProfileRightAxisMetric.buoyancy,
        ),
        buoyancyCurve: _crossingCurve(),
        locale: const Locale('he'),
      ),
    );
    await tester.pumpAndSettle();
    final signed = tester
        .widgetList<Text>(find.byType(Text))
        .where((w) => RegExp(r'^[+-]\d').hasMatch(w.data ?? ''))
        .toList();
    expect(signed, isNotEmpty);
    for (final tick in signed) {
      expect(tick.textDirection, TextDirection.ltr, reason: tick.data);
    }
  });

  testWidgets('no legend entry when the dive cannot be modelled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        settings: const AppSettings(defaultShowBuoyancy: true),
        buoyancyAvailable: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buoyancy'), findsNothing);
  });

  testWidgets('the tooltip carries a buoyancy row naming the side', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(
      _harness(
        settings: const AppSettings(defaultShowBuoyancy: true),
        buoyancyCurve: _crossingCurve(),
        onTooltipData: (r) => rows = r,
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LineChart)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(2, 0));
    await tester.pump();
    final got = rows;
    await gesture.up();
    await tester.pumpAndSettle();

    final row = got!.singleWhere((r) => r.label == 'Buoyancy');
    expect(row.value, matches(RegExp(r'kg (buoyant|heavy|neutral)$')));
    expect(row.metric, ProfileRightAxisMetric.buoyancy);
  });

  group('formatBuoyancyReadout', () {
    final l10n = AppLocalizationsEn();
    const metric = UnitFormatter(AppSettings());
    const imperial = UnitFormatter(AppSettings(weightUnit: WeightUnit.pounds));

    test('names the side', () {
      expect(formatBuoyancyReadout(0.94, metric, l10n), '+0.9 kg buoyant');
      expect(formatBuoyancyReadout(-2.36, metric, l10n), '-2.4 kg heavy');
      expect(formatBuoyancyReadout(0.04, metric, l10n), '0.0 kg neutral');
      expect(formatBuoyancyReadout(-0.04, metric, l10n), '0.0 kg neutral');
    });

    test('keeps the signed value whole in right-to-left text', () {
      // An isolate stops bidi reordering moving the sign to the far end.
      expect(
        formatBuoyancyReadout(
          -2.36,
          metric,
          l10n,
          direction: TextDirection.rtl,
        ),
        '\u2066-2.4 kg\u2069 heavy',
      );
    });

    test('tooltip in pounds', () {
      expect(formatBuoyancyReadout(-2.36, imperial, l10n), '-5.2 lbs heavy');
    });
  });

  group('right axis', () {
    const metric = UnitFormatter(AppSettings());

    test('axis tick has plus sign', () {
      String tick(double v) =>
          formatRightAxisTick(ProfileRightAxisMetric.buoyancy, v, metric);
      expect(tick(2.0), '+2.0');
      expect(tick(-3.0), '-3.0');
      expect(tick(0), '0.0');
    });

    test('axis ticks follow the weight unit', () {
      const imperial = UnitFormatter(
        AppSettings(weightUnit: WeightUnit.pounds),
      );
      expect(
        formatRightAxisTick(ProfileRightAxisMetric.buoyancy, 1.0, imperial),
        '+2.2',
      );
    });
  });
}
