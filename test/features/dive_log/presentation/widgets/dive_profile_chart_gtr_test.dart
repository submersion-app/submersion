import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier({bool showGtr = true})
    : super(AppSettings(defaultShowGtr: showGtr));

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 20 points so a touch near the centre resolves to a sample.
List<DiveProfilePoint> _profile() => List.generate(
  20,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < 10 ? i * 2.0 : (19 - i) * 2.0,
  ),
);

const _gtrGreen = Color(0xFF2E7D32);

Widget _harness({
  required List<DiveProfilePoint> profile,
  List<int?>? gtrCurve,
  bool showGtr = true,
  bool tooltipBelow = false,
  void Function(List<TooltipRow>? rows)? onTooltipData,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => _TestSettingsNotifier(showGtr: showGtr),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: DiveProfileChart(
            profile: profile,
            gtrCurve: gtrCurve,
            tooltipBelow: tooltipBelow,
            onTooltipData: onTooltipData,
          ),
        ),
      ),
    ),
  );
}

Iterable<LineChartBarData> _gtrBars(WidgetTester tester) => tester
    .widget<LineChart>(find.byType(LineChart))
    .data
    .lineBarsData
    .where((b) => b.color == _gtrGreen);

Future<List<TooltipRow>?> _touchCentre(
  WidgetTester tester,
  List<TooltipRow>? Function() rows,
) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(LineChart)),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveBy(const Offset(2, 0));
  await tester.pump();
  return rows();
}

void main() {
  group('DiveProfileChart GTR line', () {
    testWidgets('draws the line and breaks it at blank samples', (
      tester,
    ) async {
      final gtr = List<int?>.generate(
        20,
        (i) => i == 10 ? null : 2400 - i * 60,
      );

      await tester.pumpWidget(_harness(profile: _profile(), gtrCurve: gtr));
      await tester.pumpAndSettle();

      final bars = _gtrBars(tester).toList();
      expect(bars, hasLength(1));
      expect(
        bars.single.spots.where((s) => s == FlSpot.nullSpot),
        isNotEmpty,
        reason: 'a blank sample must break the line, not plunge to zero',
      );
    });

    testWidgets('draws nothing when the legend hides it', (tester) async {
      final gtr = List<int?>.filled(20, 2400);

      await tester.pumpWidget(
        _harness(profile: _profile(), gtrCurve: gtr, showGtr: false),
      );
      await tester.pumpAndSettle();

      expect(_gtrBars(tester), isEmpty);
    });

    testWidgets('can label the right axis in minutes', (tester) async {
      final gtr = List<int?>.filled(20, 2400);

      await tester.pumpWidget(_harness(profile: _profile(), gtrCurve: gtr));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveProfileChart)),
      );
      container
          .read(profileLegendProvider.notifier)
          .setRightAxisMetric(ProfileRightAxisMetric.gtr);
      await tester.pumpAndSettle();

      expect(find.text('GTR (min)'), findsOneWidget);
    });
  });

  group('DiveProfileChart GTR external tooltip', () {
    testWidgets('reports whole minutes, rounded down', (tester) async {
      List<TooltipRow>? rows;
      // 2920 s = 48.67 min: a countdown never overstates what is left.
      final gtr = List<int?>.filled(20, 2920);

      await tester.pumpWidget(
        _harness(
          profile: _profile(),
          gtrCurve: gtr,
          tooltipBelow: true,
          onTooltipData: (r) => rows = r,
        ),
      );
      await tester.pumpAndSettle();
      final got = await _touchCentre(tester, () => rows);

      expect(got, isNotNull);
      final gtrRows = got!.where((r) => r.label == 'GTR').toList();
      expect(gtrRows, hasLength(1));
      expect(gtrRows.single.value, '48 min');
    });

    testWidgets('shows a dash where the value is blank', (tester) async {
      List<TooltipRow>? rows;
      final gtr = List<int?>.filled(20, null);

      await tester.pumpWidget(
        _harness(
          profile: _profile(),
          gtrCurve: gtr,
          tooltipBelow: true,
          onTooltipData: (r) => rows = r,
        ),
      );
      await tester.pumpAndSettle();
      final got = await _touchCentre(tester, () => rows);

      expect(got, isNotNull);
      final gtrRows = got!.where((r) => r.label == 'GTR').toList();
      expect(gtrRows, hasLength(1));
      expect(gtrRows.single.value, '--');
    });
  });
}
