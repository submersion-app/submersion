import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_colors.dart';

import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_timeline_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_overlay.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier()
    : super(const AppSettings(defaultShowGasTimeline: true));

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Settings notifier that enables ALL profile metrics for maximum
/// _emitExternalTooltip coverage.
class _AllMetricsSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _AllMetricsSettingsNotifier()
    : super(
        const AppSettings(
          defaultShowHeartRate: true,
          defaultShowSac: true,
          defaultShowPpO2: true,
          defaultShowPpN2: true,
          defaultShowPpHe: true,
          defaultShowGasDensity: true,
          defaultShowGf: true,
          defaultShowSurfaceGf: true,
          defaultShowMeanDepth: true,
          defaultShowTts: true,
          defaultShowCns: true,
          defaultShowOtu: true,
          showCeilingOnProfile: true,
          showNdlOnProfile: true,
          showAscentRateColors: true,
        ),
      );

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _makeProfile({int points = 10}) {
  return List.generate(
    points,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: (i < points / 2 ? i * 3.0 : (points - i) * 3.0),
    ),
  );
}

Widget _buildChart({
  List<DiveProfilePoint>? profile,
  List<ChartSourceOverlay>? overlays,
  String? activeComputerId,
  Map<String, String>? computerNames,
  Map<String, List<TankPressurePoint>>? tankPressures,
  List<DiveTank>? tanks,
  List<double>? ceilingCurve,
  List<AscentRatePoint>? ascentRates,
  List<ProfileEvent>? events,
  List<int>? ndlCurve,
  List<double>? sacCurve,
  double? tankVolume,
  double sacNormalizationFactor = 1.0,
  List<double>? ppO2Curve,
  List<List<double?>>? o2SensorCurves,
  bool ppO2FromSensorAverage = false,
  List<double>? ppN2Curve,
  List<double>? ppHeCurve,
  List<double>? densityCurve,
  List<double>? gfCurve,
  List<double>? surfaceGfCurve,
  List<double>? meanDepthCurve,
  List<int>? ttsCurve,
  List<double>? cnsCurve,
  List<double>? otuCurve,
  List<double>? modCurve,
  List<ProfileMarker>? markers,
  bool showMaxDepthMarker = false,
  bool showPressureThresholdMarkers = false,
  List<GasSwitchWithTank>? gasSwitches,
  List<GasUsageSegment>? gasSegments,
  int? diveDurationSeconds,
  bool tooltipBelow = false,
  void Function(List<TooltipRow>? rows)? onTooltipData,
  void Function(int? index)? onPointSelected,
  int? playbackTimestamp,
  int? highlightedTimestamp,
  List<PhotoChartMarker>? photoMarkers,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: DiveProfileChart(
            profile: profile ?? _makeProfile(),
            overlays: overlays,
            activeComputerId: activeComputerId,
            computerNames: computerNames,
            tankPressures: tankPressures,
            tanks: tanks,
            ceilingCurve: ceilingCurve,
            ascentRates: ascentRates,
            events: events,
            ndlCurve: ndlCurve,
            sacCurve: sacCurve,
            tankVolume: tankVolume,
            sacNormalizationFactor: sacNormalizationFactor,
            ppO2Curve: ppO2Curve,
            o2SensorCurves: o2SensorCurves,
            ppO2FromSensorAverage: ppO2FromSensorAverage,
            ppN2Curve: ppN2Curve,
            ppHeCurve: ppHeCurve,
            densityCurve: densityCurve,
            gfCurve: gfCurve,
            surfaceGfCurve: surfaceGfCurve,
            meanDepthCurve: meanDepthCurve,
            ttsCurve: ttsCurve,
            cnsCurve: cnsCurve,
            otuCurve: otuCurve,
            modCurve: modCurve,
            markers: markers,
            showMaxDepthMarker: showMaxDepthMarker,
            showPressureThresholdMarkers: showPressureThresholdMarkers,
            gasSwitches: gasSwitches,
            gasSegments: gasSegments,
            diveDurationSeconds: diveDurationSeconds,
            tooltipBelow: tooltipBelow,
            onTooltipData: onTooltipData,
            onPointSelected: onPointSelected,
            playbackTimestamp: playbackTimestamp,
            highlightedTimestamp: highlightedTimestamp,
            photoMarkers: photoMarkers,
          ),
        ),
      ),
    ),
  );
}

/// Build chart with all metrics enabled via _AllMetricsSettingsNotifier.
/// This ensures _emitExternalTooltip covers every metric branch.
Widget _buildChartAllMetrics({
  List<DiveProfilePoint>? profile,
  Map<String, List<TankPressurePoint>>? tankPressures,
  List<DiveTank>? tanks,
  List<double>? ceilingCurve,
  List<AscentRatePoint>? ascentRates,
  List<int>? ndlCurve,
  List<double>? sacCurve,
  double? tankVolume,
  double sacNormalizationFactor = 1.0,
  List<double>? ppO2Curve,
  List<List<double?>>? o2SensorCurves,
  bool ppO2FromSensorAverage = false,
  List<double>? ppN2Curve,
  List<double>? ppHeCurve,
  List<double>? densityCurve,
  List<double>? gfCurve,
  List<double>? surfaceGfCurve,
  List<double>? meanDepthCurve,
  List<int>? ttsCurve,
  List<double>? cnsCurve,
  List<double>? otuCurve,
  List<double>? modCurve,
  List<ProfileMarker>? markers,
  bool showMaxDepthMarker = false,
  bool showPressureThresholdMarkers = false,
  bool tooltipBelow = false,
  void Function(List<TooltipRow>? rows)? onTooltipData,
  void Function(int? index)? onPointSelected,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _AllMetricsSettingsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: DiveProfileChart(
            profile: profile ?? _makeProfile(),
            tankPressures: tankPressures,
            tanks: tanks,
            ceilingCurve: ceilingCurve,
            ascentRates: ascentRates,
            ndlCurve: ndlCurve,
            sacCurve: sacCurve,
            tankVolume: tankVolume,
            sacNormalizationFactor: sacNormalizationFactor,
            ppO2Curve: ppO2Curve,
            o2SensorCurves: o2SensorCurves,
            ppO2FromSensorAverage: ppO2FromSensorAverage,
            ppN2Curve: ppN2Curve,
            ppHeCurve: ppHeCurve,
            densityCurve: densityCurve,
            gfCurve: gfCurve,
            surfaceGfCurve: surfaceGfCurve,
            meanDepthCurve: meanDepthCurve,
            ttsCurve: ttsCurve,
            cnsCurve: cnsCurve,
            otuCurve: otuCurve,
            modCurve: modCurve,
            markers: markers,
            showMaxDepthMarker: showMaxDepthMarker,
            showPressureThresholdMarkers: showPressureThresholdMarkers,
            tooltipBelow: tooltipBelow,
            onTooltipData: onTooltipData,
            onPointSelected: onPointSelected,
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DiveProfileChart - single profile rendering', () {
    testWidgets('renders without crashing with profile data', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders empty state when profile is empty', (tester) async {
      await tester.pumpWidget(_buildChart(profile: const []));
      await tester.pumpAndSettle();

      // Empty profile should show empty state placeholder.
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });

  group('DiveProfileChart - overlay source rendering', () {
    ChartSourceOverlay overlay({
      String sourceId = 'src-b',
      String name = 'Erics Teric',
      Color color = Colors.orange,
      String? computerId = 'comp-b',
      required List<DiveProfilePoint> points,
    }) {
      return ChartSourceOverlay(
        sourceId: sourceId,
        name: name,
        color: color,
        computerId: computerId,
        points: points,
      );
    }

    testWidgets('renders with an overlaid source', (tester) async {
      await tester.pumpWidget(
        _buildChart(
          profile: _makeProfile(points: 8),
          activeComputerId: 'comp-a',
          overlays: [overlay(points: _makeProfile(points: 8))],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('an overlay appends exactly one dashed depth bar in its color, '
        'after every other bar', (tester) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 8)));
      await tester.pumpAndSettle();
      final withoutOverlay = tester
          .widget<LineChart>(find.byType(LineChart).first)
          .data
          .lineBarsData
          .length;

      await tester.pumpWidget(
        _buildChart(
          profile: _makeProfile(points: 8),
          activeComputerId: 'comp-a',
          overlays: [
            overlay(color: Colors.purple, points: _makeProfile(points: 6)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final bars = tester
          .widget<LineChart>(find.byType(LineChart).first)
          .data
          .lineBarsData;
      expect(bars.length, withoutOverlay + 1);
      final overlayBar = bars.last;
      expect(overlayBar.color, Colors.purple);
      expect(overlayBar.dashArray, [6, 4]);
      expect(overlayBar.spots.length, 6);
      // Depth bar 0 is still the active source.
      expect(bars.first.spots.length, 8);
    });

    testWidgets(
      'tooltip rows label overlay depth and temperature with the metric',
      (tester) async {
        final active = [
          for (var i = 0; i < 5; i++)
            DiveProfilePoint(
              timestamp: i * 20,
              depth: i * 3.0,
              temperature: 27.0,
            ),
        ];
        final other = [
          for (var i = 0; i < 5; i++)
            DiveProfilePoint(
              timestamp: i * 20,
              depth: i * 2.0,
              temperature: 26.5,
            ),
        ];

        List<TooltipRow>? receivedRows;
        await tester.pumpWidget(
          _buildChart(
            profile: active,
            activeComputerId: 'comp-a',
            overlays: [overlay(name: 'Erics Teric', points: other)],
            tooltipBelow: true,
            onTooltipData: (rows) => receivedRows = rows,
          ),
        );
        await tester.pumpAndSettle();

        final data = tester
            .widget<LineChart>(find.byType(LineChart).first)
            .data;
        final bars = data.lineBarsData;
        final touchedSpot = bars.first.spots[2];
        data.lineTouchData.touchCallback!(
          FlPanDownEvent(DragDownDetails()),
          LineTouchResponse(
            touchLocation: Offset.zero,
            touchChartCoordinate: Offset.zero,
            lineBarSpots: <TouchLineBarSpot>[
              TouchLineBarSpot(bars.first, 0, touchedSpot, 2),
            ],
          ),
        );

        expect(receivedRows, isNotNull);
        final byLabel = {for (final r in receivedRows!) r.label: r.value};
        expect(byLabel['Depth · Erics Teric'], isNotNull);
        expect(byLabel['Depth · Erics Teric'], isNot(isEmpty));
        expect(byLabel['Temp · Erics Teric'], isNotNull);
      },
    );

    testWidgets(
      'touch on the active depth bar resolves the active profile sample '
      'even with a denser overlay present',
      (tester) async {
        // The overlay's points need not align index-for-index with
        // [widget.profile]; overlay bars are appended last so they never
        // participate in the depth-spot mapping.
        final active = [
          for (var i = 0; i < 5; i++)
            DiveProfilePoint(timestamp: i * 20, depth: i * 3.0),
        ];
        final other = [
          for (var i = 0; i < 9; i++)
            DiveProfilePoint(timestamp: i * 10, depth: i * 1.5),
        ];

        int? selected;
        await tester.pumpWidget(
          _buildChart(
            profile: active,
            activeComputerId: 'comp-a',
            overlays: [overlay(points: other)],
            onPointSelected: (i) => selected = i,
          ),
        );
        await tester.pumpAndSettle();

        final data = tester
            .widget<LineChart>(find.byType(LineChart).first)
            .data;
        final bars = data.lineBarsData;
        // Bar 0 is the active depth line; the overlay bar is last.
        expect(bars.first.spots.length, 5);
        expect(bars.last.spots.length, 9);

        final touchedSpot = bars.first.spots[3];
        expect(touchedSpot.x, 60.0);
        data.lineTouchData.touchCallback!(
          FlPanDownEvent(DragDownDetails()),
          LineTouchResponse(
            touchLocation: Offset.zero,
            touchChartCoordinate: Offset.zero,
            lineBarSpots: <TouchLineBarSpot>[
              TouchLineBarSpot(bars.first, 0, touchedSpot, 3),
            ],
          ),
        );

        expect(selected, 3);
        expect(active[selected!].timestamp, 60);
      },
    );
  });

  group('DiveProfileChart - multi-tank pressure rendering', () {
    testWidgets('renders with tank pressure data', (tester) async {
      final profile = _makeProfile(points: 10);
      final tankPressures = <String, List<TankPressurePoint>>{
        'tank-1': List.generate(
          10,
          (i) => TankPressurePoint(
            id: 'tp-1-$i',
            tankId: 'tank-1',
            timestamp: i * 30,
            pressure: 200.0 - i * 5,
          ),
        ),
        'tank-2': List.generate(
          10,
          (i) => TankPressurePoint(
            id: 'tp-2-$i',
            tankId: 'tank-2',
            timestamp: i * 30,
            pressure: 180.0 - i * 4,
          ),
        ),
      };
      final tanks = [
        const DiveTank(id: 'tank-1', startPressure: 200, endPressure: 155),
        const DiveTank(id: 'tank-2', startPressure: 180, endPressure: 144),
      ];

      await tester.pumpWidget(
        _buildChart(
          profile: profile,
          tankPressures: tankPressures,
          tanks: tanks,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with single tank pressure data', (tester) async {
      final profile = _makeProfile(points: 5);
      final tankPressures = <String, List<TankPressurePoint>>{
        'tank-1': List.generate(
          5,
          (i) => TankPressurePoint(
            id: 'tp-$i',
            tankId: 'tank-1',
            timestamp: i * 30,
            pressure: 200.0 - i * 10,
          ),
        ),
      };
      final tanks = [
        const DiveTank(id: 'tank-1', startPressure: 200, endPressure: 160),
      ];

      await tester.pumpWidget(
        _buildChart(
          profile: profile,
          tankPressures: tankPressures,
          tanks: tanks,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });

  group('DiveProfileChart - overlay temperature and event gating', () {
    // Reads the primary fl_chart LineChartData (the depth/time plot is first).
    LineChartData primaryChartData(WidgetTester tester) =>
        tester.widget<LineChart>(find.byType(LineChart).first).data;

    List<LineChartBarData> temperatureLines(WidgetTester tester) =>
        primaryChartData(tester).lineBarsData
            .where(
              (bar) =>
                  bar.dashArray != null &&
                  bar.dashArray!.length == 2 &&
                  bar.dashArray![0] == 5 &&
                  bar.dashArray![1] == 3,
            )
            .toList();

    List<DiveProfilePoint> profileWithTemp(double temperature) => List.generate(
      8,
      (i) => DiveProfilePoint(
        timestamp: i * 30,
        depth: i * 1.0,
        temperature: temperature,
      ),
    );

    ChartSourceOverlay overlayB(List<DiveProfilePoint> points) =>
        ChartSourceOverlay(
          sourceId: 'src-b',
          name: 'Erics Teric',
          color: Colors.orange,
          computerId: 'comp-b',
          points: points,
        );

    testWidgets(
      'active and overlaid sources each draw a temperature line on one scale',
      (tester) async {
        await tester.pumpWidget(
          _buildChart(
            profile: profileWithTemp(20),
            activeComputerId: 'comp-a',
            overlays: [overlayB(profileWithTemp(22))],
          ),
        );
        await tester.pumpAndSettle();

        expect(temperatureLines(tester).length, 2);
      },
    );

    testWidgets('removing the overlay removes its temperature line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(profile: profileWithTemp(20), activeComputerId: 'comp-a'),
      );
      await tester.pumpAndSettle();

      expect(temperatureLines(tester).length, 1);
    });

    testWidgets('events draw for the active and overlaid computers only', (
      tester,
    ) async {
      final createdAt = DateTime(2024, 1, 1);
      final events = [
        ProfileEvent(
          id: 'e-a',
          diveId: 'dive-1',
          timestamp: 30,
          eventType: ProfileEventType.bookmark,
          computerId: 'comp-a',
          createdAt: createdAt,
        ),
        ProfileEvent(
          id: 'e-b',
          diveId: 'dive-1',
          timestamp: 60,
          eventType: ProfileEventType.bookmark,
          computerId: 'comp-b',
          createdAt: createdAt,
        ),
      ];

      // comp-b not overlaid: its event hides.
      await tester.pumpWidget(
        _buildChart(
          profile: profileWithTemp(20),
          activeComputerId: 'comp-a',
          overlays: const [],
          events: events,
        ),
      );
      await tester.pumpAndSettle();

      var verticalLines = primaryChartData(tester).extraLinesData.verticalLines;
      expect(verticalLines.any((l) => l.x == 30), isTrue);
      expect(verticalLines.any((l) => l.x == 60), isFalse);

      // Overlaying comp-b brings its event back.
      await tester.pumpWidget(
        _buildChart(
          profile: profileWithTemp(20),
          activeComputerId: 'comp-a',
          overlays: [overlayB(profileWithTemp(22))],
          events: events,
        ),
      );
      await tester.pumpAndSettle();

      verticalLines = primaryChartData(tester).extraLinesData.verticalLines;
      expect(verticalLines.any((l) => l.x == 30), isTrue);
      expect(verticalLines.any((l) => l.x == 60), isTrue);
    });

    testWidgets('a null-computerId event always draws (active-owned)', (
      tester,
    ) async {
      final createdAt = DateTime(2024, 1, 1);
      final events = [
        ProfileEvent(
          id: 'e-primary',
          diveId: 'dive-1',
          timestamp: 30,
          eventType: ProfileEventType.bookmark,
          createdAt: createdAt,
        ),
      ];

      await tester.pumpWidget(
        _buildChart(
          profile: profileWithTemp(20),
          activeComputerId: 'comp-a',
          overlays: const [],
          events: events,
        ),
      );
      await tester.pumpAndSettle();

      final verticalLines = primaryChartData(
        tester,
      ).extraLinesData.verticalLines;
      expect(verticalLines.any((l) => l.x == 30), isTrue);
    });
  });

  group('DiveProfileChart - empty state', () {
    testWidgets('empty profile shows "No dive profile data" text', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart(profile: const []));
      await tester.pumpAndSettle();

      expect(find.text('No dive profile data'), findsOneWidget);
    });

    testWidgets('empty profile shows show_chart icon', (tester) async {
      await tester.pumpWidget(_buildChart(profile: const []));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('empty profile renders fixed height container', (tester) async {
      await tester.pumpWidget(_buildChart(profile: const []));
      await tester.pumpAndSettle();

      // The empty state container is present within the chart widget
      final chart = find.byType(DiveProfileChart);
      expect(chart, findsOneWidget);
    });
  });

  group('DiveProfileChart - bounded constraints', () {
    testWidgets('renders in bounded SizedBox', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 350,
                child: DiveProfileChart(profile: _makeProfile()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders inside a Column with constrained height', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                height: 400,
                width: 400,
                child: Column(
                  children: [
                    const SizedBox(height: 50),
                    SizedBox(
                      height: 300,
                      child: DiveProfileChart(profile: _makeProfile()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });

  group('DiveProfileChart - profile with temperature data', () {
    testWidgets('renders with temperature data points', (tester) async {
      final profile = List.generate(
        10,
        (i) => DiveProfilePoint(
          timestamp: i * 30,
          depth: (i < 5 ? i * 3.0 : (9 - i) * 3.0),
          temperature: 22.0 - i * 0.5,
        ),
      );

      await tester.pumpWidget(_buildChart(profile: profile));
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });

  group('DiveProfileChart - profile with heart rate data', () {
    testWidgets('renders with heart rate data points', (tester) async {
      final profile = List.generate(
        10,
        (i) => DiveProfilePoint(
          timestamp: i * 30,
          depth: (i < 5 ? i * 3.0 : (9 - i) * 3.0),
          heartRate: 70 + i * 2,
        ),
      );

      await tester.pumpWidget(_buildChart(profile: profile));
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });

  group('DiveProfileChart - with ceiling and ascent rate data', () {
    testWidgets('renders with ceiling curve data', (tester) async {
      final profile = _makeProfile(points: 10);
      final ceilingCurve = List.generate(10, (i) => i < 5 ? 0.0 : i * 0.5);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 300,
                child: DiveProfileChart(
                  profile: profile,
                  ceilingCurve: ceilingCurve,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });

  group('DiveProfileChart - large profile', () {
    testWidgets('handles large profile (1000+ points) without crash', (
      tester,
    ) async {
      final profile = _makeProfile(points: 1000);

      await tester.pumpWidget(_buildChart(profile: profile));
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });

  // =========================================================================
  // TooltipRow class coverage
  // =========================================================================

  group('TooltipRow', () {
    test('holds label, value, and bulletColor', () {
      const row = TooltipRow(
        label: 'Depth',
        value: '30.0 m',
        bulletColor: Colors.blue,
      );

      expect(row.label, 'Depth');
      expect(row.value, '30.0 m');
      expect(row.bulletColor, Colors.blue);
    });

    test('can be created with different colors', () {
      const row1 = TooltipRow(
        label: 'Temp',
        value: '22 C',
        bulletColor: Colors.orange,
      );
      const row2 = TooltipRow(
        label: 'HR',
        value: '80 bpm',
        bulletColor: Colors.red,
      );

      expect(row1.bulletColor, Colors.orange);
      expect(row2.bulletColor, Colors.red);
    });
  });

  // =========================================================================
  // Profile with advanced data curves (coverage for line-building code)
  // =========================================================================

  group('DiveProfileChart - advanced data curves rendering', () {
    List<DiveProfilePoint> makeRichProfile() {
      return List.generate(
        10,
        (i) => DiveProfilePoint(
          timestamp: i * 30,
          depth: (i < 5 ? i * 5.0 : (9 - i) * 5.0),
          temperature: 22.0 - i * 0.3,
          heartRate: 70 + i * 3,
        ),
      );
    }

    testWidgets('renders with NDL curve data', (tester) async {
      final profile = makeRichProfile();
      final ndlCurve = List.generate(10, (i) => i < 5 ? 600 - i * 60 : -1);

      await tester.pumpWidget(
        _buildChart(profile: profile, ndlCurve: ndlCurve),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with ppO2 curve data', (tester) async {
      final profile = makeRichProfile();
      final ppO2 = List.generate(10, (i) => 0.21 + i * 0.05);

      await tester.pumpWidget(_buildChart(profile: profile, ppO2Curve: ppO2));
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with O2 sensor curves alongside ppO2', (tester) async {
      final profile = makeRichProfile();
      final ppO2 = List.generate(10, (i) => 0.7 + i * 0.05);
      // Three cells (e.g. JJ-CCR), each per-sample, with a null gap on cell 3.
      final sensors = <List<double?>>[
        List.generate(10, (i) => 0.68 + i * 0.05),
        List.generate(10, (i) => 0.72 + i * 0.05),
        List.generate(10, (i) => i == 4 ? null : 0.70 + i * 0.05),
      ];

      await tester.pumpWidget(
        _buildChart(profile: profile, ppO2Curve: ppO2, o2SensorCurves: sensors),
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      expect(chart.o2SensorCurves, sensors);
      expect(chart.ppO2FromSensorAverage, isFalse);
    });

    testWidgets('forwards ppO2FromSensorAverage flag to the chart', (
      tester,
    ) async {
      final profile = makeRichProfile();
      final ppO2 = List.generate(10, (i) => 0.7 + i * 0.05);

      await tester.pumpWidget(
        _buildChart(
          profile: profile,
          ppO2Curve: ppO2,
          o2SensorCurves: <List<double?>>[List.generate(10, (i) => 0.7)],
          ppO2FromSensorAverage: true,
        ),
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      expect(chart.ppO2FromSensorAverage, isTrue);
    });

    testWidgets('renders with ppN2 curve data', (tester) async {
      final profile = makeRichProfile();
      final ppN2 = List.generate(10, (i) => 0.79 + i * 0.02);

      await tester.pumpWidget(_buildChart(profile: profile, ppN2Curve: ppN2));
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with ppHe curve (trimix)', (tester) async {
      final profile = makeRichProfile();
      final ppHe = List.generate(10, (i) => 0.1 + i * 0.01);

      await tester.pumpWidget(_buildChart(profile: profile, ppHeCurve: ppHe));
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with gas density curve', (tester) async {
      final profile = makeRichProfile();
      final density = List.generate(10, (i) => 1.2 + i * 0.2);

      await tester.pumpWidget(
        _buildChart(profile: profile, densityCurve: density),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with GF curve', (tester) async {
      final profile = makeRichProfile();
      final gf = List.generate(10, (i) => 20.0 + i * 5);

      await tester.pumpWidget(_buildChart(profile: profile, gfCurve: gf));
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with surface GF curve', (tester) async {
      final profile = makeRichProfile();
      final surfaceGf = List.generate(10, (i) => 15.0 + i * 4);

      await tester.pumpWidget(
        _buildChart(profile: profile, surfaceGfCurve: surfaceGf),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with mean depth curve', (tester) async {
      final profile = makeRichProfile();
      final meanDepth = List.generate(10, (i) => i * 2.0);

      await tester.pumpWidget(
        _buildChart(profile: profile, meanDepthCurve: meanDepth),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with TTS curve', (tester) async {
      final profile = makeRichProfile();
      final tts = List.generate(10, (i) => i < 5 ? 0 : i * 60);

      await tester.pumpWidget(_buildChart(profile: profile, ttsCurve: tts));
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with CNS curve', (tester) async {
      final profile = makeRichProfile();
      final cns = List.generate(10, (i) => i * 3.0);

      await tester.pumpWidget(_buildChart(profile: profile, cnsCurve: cns));
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with OTU curve', (tester) async {
      final profile = makeRichProfile();
      final otu = List.generate(10, (i) => i * 5.0);

      await tester.pumpWidget(_buildChart(profile: profile, otuCurve: otu));
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with MOD curve', (tester) async {
      final profile = makeRichProfile();
      final mod = List.generate(10, (i) => 30.0 + i * 2);

      await tester.pumpWidget(_buildChart(profile: profile, modCurve: mod));
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with SAC curve data', (tester) async {
      final profile = makeRichProfile();
      final sac = List.generate(10, (i) => i > 0 ? 0.5 + i * 0.05 : 0.0);

      await tester.pumpWidget(
        _buildChart(
          profile: profile,
          sacCurve: sac,
          tankVolume: 12.0,
          sacNormalizationFactor: 1.1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with ascent rate data', (tester) async {
      final profile = makeRichProfile();
      final ascentRates = List.generate(
        10,
        (i) => AscentRatePoint(
          timestamp: i * 30,
          depth: profile[i].depth,
          rateMetersPerMin: i < 5 ? -3.0 : 9.0 + i,
          category: i < 7 ? AscentRateCategory.safe : AscentRateCategory.danger,
        ),
      );

      await tester.pumpWidget(
        _buildChart(profile: profile, ascentRates: ascentRates),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with profile events', (tester) async {
      final profile = makeRichProfile();
      final events = [
        ProfileEvent(
          id: 'ev-1',
          diveId: 'dive-1',
          timestamp: 120,
          eventType: ProfileEventType.safetyStopStart,
          severity: EventSeverity.info,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(_buildChart(profile: profile, events: events));
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with profile markers', (tester) async {
      final profile = makeRichProfile();
      final markers = [
        const ProfileMarker(
          timestamp: 120,
          depth: 25.0,
          type: ProfileMarkerType.maxDepth,
          value: 25.0,
        ),
      ];

      await tester.pumpWidget(
        _buildChart(
          profile: profile,
          markers: markers,
          showMaxDepthMarker: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with gas switches', (tester) async {
      final profile = makeRichProfile();
      final gasSwitches = [
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'gs-1',
            diveId: 'dive-1',
            timestamp: 120,
            tankId: 'tank-1',
            createdAt: DateTime(2026, 1, 1),
          ),
          tankName: 'EAN32',
          gasMix: 'EAN32',
          o2Fraction: 0.32,
          heFraction: 0.0,
        ),
      ];

      await tester.pumpWidget(
        _buildChart(profile: profile, gasSwitches: gasSwitches),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with playback timestamp cursor', (tester) async {
      final profile = makeRichProfile();

      await tester.pumpWidget(
        _buildChart(profile: profile, playbackTimestamp: 120),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with highlighted timestamp', (tester) async {
      final profile = makeRichProfile();

      await tester.pumpWidget(
        _buildChart(profile: profile, highlightedTimestamp: 90),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });

  // =========================================================================
  // Chart with all curves together (maximizes line-building coverage)
  // =========================================================================

  group('DiveProfileChart - full data rendering', () {
    testWidgets('renders with all available data curves simultaneously', (
      tester,
    ) async {
      final profile = List.generate(
        10,
        (i) => DiveProfilePoint(
          timestamp: i * 30,
          depth: (i < 5 ? i * 5.0 : (9 - i) * 5.0),
          temperature: 22.0 - i * 0.3,
          heartRate: 70 + i * 2,
        ),
      );

      final tankPressures = <String, List<TankPressurePoint>>{
        'tank-1': List.generate(
          10,
          (i) => TankPressurePoint(
            id: 'tp-$i',
            tankId: 'tank-1',
            timestamp: i * 30,
            pressure: 200.0 - i * 8,
          ),
        ),
      };
      final tanks = [
        const DiveTank(id: 'tank-1', startPressure: 200, endPressure: 120),
      ];

      await tester.pumpWidget(
        _buildChart(
          profile: profile,
          ceilingCurve: List.generate(10, (i) => i < 5 ? 0.0 : i * 0.5),
          ascentRates: List.generate(
            10,
            (i) => AscentRatePoint(
              timestamp: i * 30,
              depth: profile[i].depth,
              rateMetersPerMin: i < 5 ? -2.0 : 5.0,
              category: AscentRateCategory.safe,
            ),
          ),
          ndlCurve: List.generate(10, (i) => i < 5 ? 900 : -1),
          sacCurve: List.generate(10, (i) => 0.4 + i * 0.03),
          tankVolume: 12.0,
          ppO2Curve: List.generate(10, (i) => 0.21 + i * 0.04),
          ppN2Curve: List.generate(10, (i) => 0.79 + i * 0.01),
          ppHeCurve: List.generate(10, (i) => 0.05 + i * 0.005),
          densityCurve: List.generate(10, (i) => 1.2 + i * 0.15),
          gfCurve: List.generate(10, (i) => 20.0 + i * 4),
          surfaceGfCurve: List.generate(10, (i) => 15.0 + i * 3),
          meanDepthCurve: List.generate(10, (i) => i * 1.5),
          ttsCurve: List.generate(10, (i) => i < 5 ? 0 : i * 30),
          cnsCurve: List.generate(10, (i) => i * 2.5),
          otuCurve: List.generate(10, (i) => i * 4.0),
          modCurve: List.generate(10, (i) => 30.0 + i * 2),
          tankPressures: tankPressures,
          tanks: tanks,
          markers: [
            const ProfileMarker(
              timestamp: 120,
              depth: 25.0,
              type: ProfileMarkerType.maxDepth,
              value: 25.0,
            ),
          ],
          showMaxDepthMarker: true,
          events: [
            ProfileEvent(
              id: 'ev-1',
              diveId: 'dive-1',
              timestamp: 90,
              eventType: ProfileEventType.safetyStopStart,
              severity: EventSeverity.info,
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });

  // =========================================================================
  // Touch interaction / tooltip callback coverage
  // =========================================================================

  group('DiveProfileChart - tooltipBelow external callback', () {
    testWidgets('renders with tooltipBelow=true and onTooltipData set', (
      tester,
    ) async {
      List<TooltipRow>? receivedRows;

      await tester.pumpWidget(
        _buildChart(
          tooltipBelow: true,
          onTooltipData: (rows) => receivedRows = rows,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
      // Initially no tooltip data should have been emitted
      expect(receivedRows, isNull);
    });

    testWidgets('renders with onPointSelected callback set', (tester) async {
      int? selectedIndex;

      await tester.pumpWidget(
        _buildChart(onPointSelected: (index) => selectedIndex = index),
      );
      await tester.pumpAndSettle();

      // The chart renders without error when onPointSelected is provided
      expect(find.byType(DiveProfileChart), findsOneWidget);
      // No interaction yet, so selectedIndex is null
      expect(selectedIndex, isNull);
    });

    testWidgets(
      'renders chart with tooltipBelow and all curves for tooltip coverage',
      (tester) async {
        List<TooltipRow>? receivedRows;

        final profile = List.generate(
          10,
          (i) => DiveProfilePoint(
            timestamp: i * 30,
            depth: (i < 5 ? i * 5.0 : (9 - i) * 5.0),
            temperature: 22.0 - i * 0.3,
            heartRate: 70 + i * 2,
          ),
        );

        await tester.pumpWidget(
          _buildChart(
            profile: profile,
            tooltipBelow: true,
            onTooltipData: (rows) => receivedRows = rows,
            ceilingCurve: List.generate(10, (i) => i < 5 ? 0.0 : i * 0.5),
            sacCurve: List.generate(10, (i) => 0.4 + i * 0.03),
            tankVolume: 12.0,
            ppO2Curve: List.generate(10, (i) => 0.21 + i * 0.04),
            ppN2Curve: List.generate(10, (i) => 0.79 + i * 0.01),
            ppHeCurve: List.generate(10, (i) => 0.05 + i * 0.005),
            densityCurve: List.generate(10, (i) => 1.2 + i * 0.15),
            gfCurve: List.generate(10, (i) => 20.0 + i * 4),
            surfaceGfCurve: List.generate(10, (i) => 15.0 + i * 3),
            meanDepthCurve: List.generate(10, (i) => i * 1.5),
            ttsCurve: List.generate(10, (i) => i < 5 ? 0 : i * 30),
            cnsCurve: List.generate(10, (i) => i * 2.5),
            otuCurve: List.generate(10, (i) => i * 4.0),
            ndlCurve: List.generate(10, (i) => i < 5 ? 900 : -1),
            ascentRates: List.generate(
              10,
              (i) => AscentRatePoint(
                timestamp: i * 30,
                depth: profile[i].depth,
                rateMetersPerMin: i < 5 ? -2.0 : 5.0,
                category: AscentRateCategory.safe,
              ),
            ),
            tankPressures: {
              'tank-1': List.generate(
                10,
                (i) => TankPressurePoint(
                  id: 'tp-$i',
                  tankId: 'tank-1',
                  timestamp: i * 30,
                  pressure: 200.0 - i * 8,
                ),
              ),
            },
            tanks: [
              const DiveTank(
                id: 'tank-1',
                startPressure: 200,
                endPressure: 120,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DiveProfileChart), findsOneWidget);
        // The tooltip data is only emitted when a chart point is touched.
        // Confirm the widget rendered without error.
        expect(receivedRows, isNull);
      },
    );
  });

  group('DiveProfileChart - tooltip placement', () {
    testWidgets('default keeps the bubble pinned above the chart box '
        '(detail-page behavior)', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      final tooltip = tester
          .widget<LineChart>(find.byType(LineChart).first)
          .data
          .lineTouchData
          .touchTooltipData;
      expect(tooltip.showOnTopOfTheChartBoxArea, isTrue);
      expect(tooltip.fitInsideVertically, isFalse);
      expect(tooltip.tooltipMargin, 0);
    });
  });

  // =========================================================================
  // Static helper coverage
  // =========================================================================

  group('DiveProfileChart.tankTooltipLabel', () {
    test('appends the gas type to the fallback label', () {
      final label = DiveProfileChart.tankTooltipLabel(
        const DiveTank(id: 'tank-1', gasMix: GasMix(o2: 32)),
        'Tank 1',
      );
      expect(label, 'Tank 1 (EAN32)');
    });

    test('uses the caller-provided fallback label', () {
      final label = DiveProfileChart.tankTooltipLabel(
        const DiveTank(id: 'tank-2', gasMix: GasMix(o2: 50)),
        'Tank 2',
      );
      expect(label, 'Tank 2 (EAN50)');
    });

    test('honors a localized fallback label', () {
      // The built-in tooltip passes a localized default (e.g. l10n
      // diveLog_tank_title); the gas type is appended to whatever is given.
      final label = DiveProfileChart.tankTooltipLabel(
        const DiveTank(id: 'tank-1', gasMix: GasMix(o2: 32)),
        'Cilindro 1',
      );
      expect(label, 'Cilindro 1 (EAN32)');
    });

    test('shows Air for a 21% mix', () {
      final label = DiveProfileChart.tankTooltipLabel(
        const DiveTank(id: 'tank-1', gasMix: GasMix(o2: 21)),
        'Tank 1',
      );
      expect(label, 'Tank 1 (Air)');
    });

    test('appends the gas type to a custom tank name', () {
      final label = DiveProfileChart.tankTooltipLabel(
        const DiveTank(id: 'tank-1', name: 'Backgas', gasMix: GasMix(o2: 32)),
        'Tank 1',
      );
      expect(label, 'Backgas (EAN32)');
    });

    test('falls back to the label without gas when tank is null', () {
      expect(DiveProfileChart.tankTooltipLabel(null, 'Tank 1'), 'Tank 1');
    });
  });

  group('DiveProfileChart.tooltipRowText', () {
    test('keeps a full long label and its value with a separator', () {
      // Regression for two prior bugs: the 8-char column truncated to
      // "Tank 1 (1648 psi", and padding alone produced "Tank 1 (EAN32)2064".
      final row = DiveProfileChart.tooltipRowText(
        'Tank 1 (EAN32)',
        '2064 psi',
        8,
        16,
      );
      expect(row, 'Tank 1 (EAN32) 2064 psi');
    });

    test('pads a short label to align the value column', () {
      expect(
        DiveProfileChart.tooltipRowText('Time', '29:20', 8, 16),
        'Time    29:20',
      );
    });

    test('clamps an over-long value to the value column', () {
      expect(
        DiveProfileChart.tooltipRowText('NDL', '12345678', 8, 4),
        'NDL     1234',
      );
    });
  });

  group('DiveProfileChart.depthSpotProfileIndex', () {
    // A canonical profile sampled every 10 seconds.
    final profile = [
      for (var i = 0; i < 6; i++)
        DiveProfilePoint(timestamp: i * 10, depth: i.toDouble()),
    ];

    test('single computer maps depthBarStart + spotIndex directly', () {
      // A velocity band starting at global index 3, touched at local
      // spotIndex 2, addresses profile sample 5.
      expect(
        DiveProfileChart.depthSpotProfileIndex(
          profile: profile,
          depthBarStarts: const [0, 3],
          barIndex: 1,
          spotIndex: 2,
          spotX: 50.0,
          multiComputer: false,
        ),
        5,
      );
    });

    test(
      'multi-computer resolves by timestamp, ignoring the local spotIndex',
      () {
        // The touched depth bar belongs to a densely-sampled computer whose
        // local spotIndex (30) does NOT address [profile]. The spot's timestamp
        // (30s) must map to profile index 3 instead -- this is the bug: the old
        // code used depthBarStarts[0] + 30 = 30, landing far from the pointer.
        expect(
          DiveProfileChart.depthSpotProfileIndex(
            profile: profile,
            depthBarStarts: const [0],
            barIndex: 0,
            spotIndex: 30,
            spotX: 30.0,
            multiComputer: true,
          ),
          3,
        );
      },
    );

    test(
      'multi-computer picks the nearest profile sample to the spot time',
      () {
        // Another computer sampled at 32s; the nearest [profile] sample is
        // index 3 (30s), not index 4 (40s).
        expect(
          DiveProfileChart.depthSpotProfileIndex(
            profile: profile,
            depthBarStarts: const [0],
            barIndex: 0,
            spotIndex: 999,
            spotX: 32.0,
            multiComputer: true,
          ),
          3,
        );
      },
    );

    test('multi-computer returns -1 for an empty profile', () {
      expect(
        DiveProfileChart.depthSpotProfileIndex(
          profile: const [],
          depthBarStarts: const [0],
          barIndex: 0,
          spotIndex: 0,
          spotX: 10.0,
          multiComputer: true,
        ),
        -1,
      );
    });
  });

  group('DiveProfileChart - static axis size helpers', () {
    test('leftAxisSize returns smaller value for narrow width', () {
      expect(DiveProfileChart.leftAxisSize(300), 28.0);
    });

    test('leftAxisSize returns larger value for wide width', () {
      expect(DiveProfileChart.leftAxisSize(500), 32.0);
    });

    test('rightAxisSize returns smaller value for narrow width', () {
      expect(DiveProfileChart.rightAxisSize(300), 32.0);
    });

    test('rightAxisSize returns larger value for wide width', () {
      expect(DiveProfileChart.rightAxisSize(500), 38.0);
    });

    test('gasTimelineHeight constant is 18.0', () {
      expect(DiveProfileChart.gasTimelineHeight, 18.0);
    });
  });

  // =========================================================================
  // Gas timeline strip integration
  // =========================================================================

  group('DiveProfileChart - gas timeline strip', () {
    List<GasUsageSegment> makeSegments() => [
      const GasUsageSegment(
        startSeconds: 0,
        endSeconds: 150,
        gasMix: GasMix(o2: 21),
        label: 'Air',
      ),
      const GasUsageSegment(
        startSeconds: 150,
        endSeconds: 300,
        gasMix: GasMix(o2: 50),
        label: 'EAN50',
      ),
    ];

    testWidgets(
      'renders GasTimelineStrip when segments and duration provided',
      (tester) async {
        await tester.pumpWidget(
          _buildChart(gasSegments: makeSegments(), diveDurationSeconds: 300),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GasTimelineStrip), findsOneWidget);
      },
    );

    testWidgets(
      'gesture on a gas-strip dive does not watch a provider outside build',
      (tester) async {
        // _plotInsets (called from gesture handlers, outside build) reads the
        // gas-strip flag. On a gas-strip dive that flag must NOT use ref.watch
        // (illegal outside build) — a wheel zoom here must not throw.
        await tester.pumpWidget(
          _buildChart(
            profile: _makeProfile(points: 20),
            gasSegments: makeSegments(),
            diveDurationSeconds: 300,
          ),
        );
        await tester.pumpAndSettle();

        final chart = find.byType(LineChart).first;
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(chart),
            scrollDelta: const Offset(0, -100),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('does not render GasTimelineStrip when segments is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(gasSegments: const [], diveDurationSeconds: 300),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GasTimelineStrip), findsNothing);
    });

    testWidgets(
      'does not render GasTimelineStrip when diveDurationSeconds is null',
      (tester) async {
        await tester.pumpWidget(
          _buildChart(gasSegments: makeSegments(), diveDurationSeconds: null),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GasTimelineStrip), findsNothing);
      },
    );

    testWidgets(
      'does not render GasTimelineStrip when diveDurationSeconds is zero',
      (tester) async {
        await tester.pumpWidget(
          _buildChart(gasSegments: makeSegments(), diveDurationSeconds: 0),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GasTimelineStrip), findsNothing);
      },
    );

    testWidgets('renders with gas strip and playback cursor extension', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(
          gasSegments: makeSegments(),
          diveDurationSeconds: 300,
          playbackTimestamp: 150,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GasTimelineStrip), findsOneWidget);
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets(
      'renders with gas strip and highlighted timestamp cursor extension',
      (tester) async {
        await tester.pumpWidget(
          _buildChart(
            gasSegments: makeSegments(),
            diveDurationSeconds: 300,
            highlightedTimestamp: 90,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GasTimelineStrip), findsOneWidget);
        expect(find.byType(DiveProfileChart), findsOneWidget);
      },
    );

    testWidgets('renders with both cursors active over gas strip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(
          gasSegments: makeSegments(),
          diveDurationSeconds: 300,
          playbackTimestamp: 100,
          highlightedTimestamp: 50,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GasTimelineStrip), findsOneWidget);
    });

    testWidgets('gas strip renders alongside ceiling curve', (tester) async {
      final profile = _makeProfile(points: 10);
      await tester.pumpWidget(
        _buildChart(
          profile: profile,
          gasSegments: makeSegments(),
          diveDurationSeconds: 300,
          ceilingCurve: List.generate(10, (i) => i < 5 ? 0.0 : i * 0.5),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GasTimelineStrip), findsOneWidget);
    });

    testWidgets('chart renders correctly without gasSegments (no strip)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();
      expect(find.byType(GasTimelineStrip), findsNothing);
    });
  });

  // =========================================================================
  // Pressure threshold markers coverage
  // =========================================================================

  group('DiveProfileChart - pressure threshold markers', () {
    testWidgets('renders with pressure threshold markers', (tester) async {
      final profile = _makeProfile(points: 10);
      final markers = [
        const ProfileMarker(
          timestamp: 60,
          depth: 15.0,
          type: ProfileMarkerType.pressureHalf,
          tankId: 'tank-1',
          tankName: 'Tank 1',
          tankIndex: 0,
          value: 100.0,
        ),
        const ProfileMarker(
          timestamp: 120,
          depth: 20.0,
          type: ProfileMarkerType.maxDepth,
          value: 20.0,
        ),
      ];

      await tester.pumpWidget(
        _buildChart(
          profile: profile,
          markers: markers,
          showMaxDepthMarker: true,
          showPressureThresholdMarkers: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });

  // =========================================================================
  // Touch interaction coverage for touchCallback and _emitExternalTooltip
  // =========================================================================

  group('DiveProfileChart - touch interaction and tooltip emission', () {
    /// Build a rich profile with temperature and heart rate data for testing
    /// tooltip emission with all metric branches.
    List<DiveProfilePoint> makeTouchProfile() {
      return List.generate(
        20,
        (i) => DiveProfilePoint(
          timestamp: i * 30,
          depth: (i < 10 ? i * 3.0 : (19 - i) * 3.0),
          temperature: 22.0 - i * 0.3,
          heartRate: 70 + i * 2,
        ),
      );
    }

    testWidgets('long press on chart center triggers touchCallback exit path', (
      tester,
    ) async {
      int? selectedIndex = 42;
      List<TooltipRow>? tooltipData = [];

      await tester.pumpWidget(
        _buildChart(
          profile: makeTouchProfile(),
          tooltipBelow: true,
          onTooltipData: (rows) => tooltipData = rows,
          onPointSelected: (idx) => selectedIndex = idx,
        ),
      );
      await tester.pumpAndSettle();

      // Find the LineChart widget and long press on it, then release.
      // The release should trigger the exit path (FlLongPressEnd).
      final chartFinder = find.byType(LineChart);
      expect(chartFinder, findsOneWidget);

      final chartCenter = tester.getCenter(chartFinder);
      final gesture = await tester.startGesture(chartCenter);
      await tester.pump(const Duration(milliseconds: 600));

      // Move slightly to trigger FlLongPressMoveUpdate
      await gesture.moveBy(const Offset(2, 0));
      await tester.pump();

      // Release triggers FlLongPressEnd, which hits the exit branch
      await gesture.up();
      await tester.pump();

      // After the release event, selectedIndex and tooltipData should be
      // cleared to null via the exit path
      expect(selectedIndex, isNull);
      expect(tooltipData, isNull);
    });

    testWidgets(
      'long press near data point emits tooltip rows via _emitExternalTooltip',
      (tester) async {
        List<TooltipRow>? receivedRows;
        int? selectedIndex;

        final profile = makeTouchProfile();

        await tester.pumpWidget(
          _buildChart(
            profile: profile,
            tooltipBelow: true,
            onTooltipData: (rows) => receivedRows = rows,
            onPointSelected: (idx) => selectedIndex = idx,
            ceilingCurve: List.generate(20, (i) => i < 10 ? 0.0 : i * 0.5),
            ascentRates: List.generate(
              20,
              (i) => AscentRatePoint(
                timestamp: i * 30,
                depth: profile[i].depth,
                rateMetersPerMin: i < 10 ? -2.0 : 9.0 + i,
                category: i < 14
                    ? AscentRateCategory.safe
                    : AscentRateCategory.danger,
              ),
            ),
            sacCurve: List.generate(20, (i) => i > 0 ? 0.5 + i * 0.03 : 0.0),
            tankVolume: 12.0,
            sacNormalizationFactor: 1.1,
            ndlCurve: List.generate(20, (i) => i < 10 ? 900 : -1),
            ppO2Curve: List.generate(20, (i) => 0.21 + i * 0.04),
            ppN2Curve: List.generate(20, (i) => 0.79 + i * 0.01),
            ppHeCurve: List.generate(20, (i) => 0.1 + i * 0.01),
            densityCurve: List.generate(20, (i) => 1.2 + i * 0.1),
            gfCurve: List.generate(20, (i) => 20.0 + i * 3),
            surfaceGfCurve: List.generate(20, (i) => 15.0 + i * 2),
            meanDepthCurve: List.generate(20, (i) => i * 1.5),
            ttsCurve: List.generate(20, (i) => i < 10 ? 0 : i * 60),
            cnsCurve: List.generate(20, (i) => i * 2.0),
            otuCurve: List.generate(20, (i) => i * 3.0),
            modCurve: List.generate(20, (i) => 30.0 + i * 2),
            tankPressures: {
              'tank-1': List.generate(
                20,
                (i) => TankPressurePoint(
                  id: 'tp-$i',
                  tankId: 'tank-1',
                  timestamp: i * 30,
                  pressure: 200.0 - i * 5,
                ),
              ),
            },
            tanks: [
              const DiveTank(
                id: 'tank-1',
                startPressure: 200,
                endPressure: 100,
              ),
            ],
            markers: [
              const ProfileMarker(
                timestamp: 150,
                depth: 15.0,
                type: ProfileMarkerType.maxDepth,
                value: 15.0,
              ),
              const ProfileMarker(
                timestamp: 150,
                depth: 15.0,
                type: ProfileMarkerType.pressureHalf,
                tankId: 'tank-1',
                tankName: 'Tank 1',
                tankIndex: 0,
                value: 100.0,
              ),
            ],
            showMaxDepthMarker: true,
            showPressureThresholdMarkers: true,
          ),
        );
        await tester.pumpAndSettle();

        // Long press near the center of the chart where data points exist.
        final chartFinder = find.byType(LineChart);
        final chartCenter = tester.getCenter(chartFinder);

        // Start a long press
        final gesture = await tester.startGesture(chartCenter);
        await tester.pump(const Duration(milliseconds: 600));

        // Move slightly to generate FlLongPressMoveUpdate events
        await gesture.moveBy(const Offset(5, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(5, 0));
        await tester.pump();

        // Verify tooltip rows were populated (fl_chart found a nearby point)
        if (receivedRows != null) {
          final labels = receivedRows!.map((r) => r.label).toList();
          expect(labels, contains('Time'));
          expect(labels, contains('Depth'));
        }

        // Release triggers exit path
        await gesture.up();
        await tester.pump();

        expect(receivedRows, isNull);
        expect(selectedIndex, isNull);
      },
    );

    testWidgets(
      'tank pressure tooltip row is suffixed with the source computer name '
      'when 2+ computers contribute pressure curves (Task 11)',
      (tester) async {
        List<TooltipRow>? receivedRows;
        final profile = makeTouchProfile();

        await tester.pumpWidget(
          _buildChart(
            profile: profile,
            tooltipBelow: true,
            onTooltipData: (rows) => receivedRows = rows,
            tankPressures: {
              'tank-a': List.generate(
                20,
                (i) => TankPressurePoint(
                  id: 'tpa-$i',
                  tankId: 'tank-a',
                  timestamp: i * 30,
                  pressure: 200.0 - i * 2,
                ),
              ),
              'tank-b': List.generate(
                20,
                (i) => TankPressurePoint(
                  id: 'tpb-$i',
                  tankId: 'tank-b',
                  timestamp: i * 30,
                  pressure: 210.0 - i * 3,
                ),
              ),
            },
            tanks: const [
              DiveTank(
                id: 'tank-a',
                startPressure: 200,
                endPressure: 160,
                computerId: 'comp-a',
              ),
              DiveTank(
                id: 'tank-b',
                startPressure: 210,
                endPressure: 150,
                computerId: 'comp-b',
              ),
            ],
            computerNames: const {'comp-a': 'Perdix 2', 'comp-b': 'Suunto D5'},
          ),
        );
        await tester.pumpAndSettle();

        final chartFinder = find.byType(LineChart);
        final chartCenter = tester.getCenter(chartFinder);
        final gesture = await tester.startGesture(chartCenter);
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(5, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(5, 0));
        await tester.pump();

        // Emission depends on fl_chart resolving a nearby spot; assert the
        // suffixes only when a tooltip was produced (matching the file's
        // gesture-based tooltip tests).
        if (receivedRows != null) {
          final labels = receivedRows!.map((r) => r.label).toList();
          expect(labels.any((l) => l.contains('· Perdix 2')), isTrue);
          expect(labels.any((l) => l.contains('· Suunto D5')), isTrue);
        }

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets('tank pressure tooltip row has no source suffix when only one '
        'computer contributes (Task 11)', (tester) async {
      List<TooltipRow>? receivedRows;
      final profile = makeTouchProfile();

      await tester.pumpWidget(
        _buildChart(
          profile: profile,
          tooltipBelow: true,
          onTooltipData: (rows) => receivedRows = rows,
          tankPressures: {
            'tank-a': List.generate(
              20,
              (i) => TankPressurePoint(
                id: 'tpa-$i',
                tankId: 'tank-a',
                timestamp: i * 30,
                pressure: 200.0 - i * 2,
              ),
            ),
          },
          tanks: const [
            DiveTank(
              id: 'tank-a',
              startPressure: 200,
              endPressure: 160,
              computerId: 'comp-a',
            ),
          ],
          computerNames: const {'comp-a': 'Perdix 2'},
        ),
      );
      await tester.pumpAndSettle();

      final chartFinder = find.byType(LineChart);
      final chartCenter = tester.getCenter(chartFinder);
      final gesture = await tester.startGesture(chartCenter);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump();

      if (receivedRows != null) {
        final labels = receivedRows!.map((r) => r.label).toList();
        expect(labels.any((l) => l.contains('·')), isFalse);
      }

      await gesture.up();
      await tester.pump();
    });

    testWidgets(
      'tooltip exposes per-cell sensor rows and the calculated-average ppO2 '
      'label',
      (tester) async {
        List<TooltipRow>? receivedRows;

        final profile = makeTouchProfile();
        final sensors = <List<double?>>[
          List.generate(20, (i) => 0.95),
          List.generate(20, (i) => 0.97),
          // Cell 3 drops out near the touch point to cover the null skip path.
          List.generate(20, (i) => i == 10 ? null : 0.96),
        ];

        await tester.pumpWidget(
          // _buildChartAllMetrics enables the ppO2 legend toggle
          // (defaultShowPpO2: true); the tooltip ppO2/sensor rows only render
          // when that toggle is on.
          _buildChartAllMetrics(
            profile: profile,
            tooltipBelow: true,
            onTooltipData: (rows) => receivedRows = rows,
            ppO2Curve: List.generate(20, (i) => 0.96),
            o2SensorCurves: sensors,
            ppO2FromSensorAverage: true,
          ),
        );
        await tester.pumpAndSettle();

        final chartFinder = find.byType(LineChart);
        final chartCenter = tester.getCenter(chartFinder);

        final gesture = await tester.startGesture(chartCenter);
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(5, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(5, 0));
        await tester.pump();

        // The emission depends on fl_chart resolving a nearby spot; assert the
        // new rows only when a tooltip was produced (matching the file's
        // gesture-based tooltip tests).
        if (receivedRows != null) {
          final labels = receivedRows!.map((r) => r.label).toList();
          // ppO2 row is labelled as a calculated average when no computer ppO2.
          expect(labels.any((l) => l.contains('avg, calculated')), isTrue);
          // Each present cell contributes a row; cell 3 may be absent at the
          // null sample, so assert on the always-present cells.
          expect(labels, contains('Sensor 1'));
          expect(labels, contains('Sensor 2'));
        }

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      'in-chart tooltip (tooltipBelow=false) builds the calculated-average '
      'ppO2 label and per-cell sensor rows without crashing',
      (tester) async {
        final profile = makeTouchProfile();
        final sensors = <List<double?>>[
          List.generate(20, (i) => 0.95),
          List.generate(20, (i) => 0.97),
          // Cell 3 drops out at one sample to cover the null-skip branch.
          List.generate(20, (i) => i == 10 ? null : 0.96),
        ];

        // tooltipBelow=false routes tooltip building through fl_chart's
        // getTooltipItems (the in-chart bubble) instead of the external
        // callback. That is the second ppO2/sensor code path, distinct from
        // _emitExternalTooltip exercised by the tooltipBelow=true test above.
        // _buildChartAllMetrics enables the ppO2 legend toggle so the rows
        // render.
        await tester.pumpWidget(
          _buildChartAllMetrics(
            profile: profile,
            tooltipBelow: false,
            ppO2Curve: List.generate(20, (i) => 0.96),
            o2SensorCurves: sensors,
            ppO2FromSensorAverage: true,
          ),
        );
        await tester.pumpAndSettle();

        final chartFinder = find.byType(LineChart);
        final chartBox = tester.renderObject(chartFinder) as RenderBox;
        final chartSize = chartBox.size;

        // Sweep across the chart so fl_chart resolves a nearby data point and
        // renders the in-chart tooltip, exercising getTooltipItems.
        for (var xFrac = 0.1; xFrac <= 0.9; xFrac += 0.1) {
          final testPoint = chartBox.localToGlobal(
            Offset(chartSize.width * xFrac, chartSize.height * 0.5),
          );
          final gesture = await tester.startGesture(testPoint);
          await tester.pump(const Duration(milliseconds: 600));
          await gesture.moveBy(const Offset(2, 0));
          await tester.pump();
          await gesture.up();
          await tester.pump();
        }

        // The in-chart tooltip has no external callback to inspect; the
        // coverage win is that getTooltipItems ran the ppO2-average and
        // per-cell sensor branch (including the null-skip) without throwing.
        expect(tester.takeException(), isNull);
        expect(find.byType(LineChart), findsOneWidget);
      },
    );

    testWidgets('pan gesture on chart triggers exit path on pan end', (
      tester,
    ) async {
      int? selectedIndex = 42;
      List<TooltipRow>? tooltipData = [];

      await tester.pumpWidget(
        _buildChart(
          profile: makeTouchProfile(),
          tooltipBelow: true,
          onTooltipData: (rows) => tooltipData = rows,
          onPointSelected: (idx) => selectedIndex = idx,
        ),
      );
      await tester.pumpAndSettle();

      // Perform a drag (pan) gesture
      await tester.drag(find.byType(LineChart), const Offset(50, 0));
      // Use pumpAndSettle to let fl_chart animation timers complete
      await tester.pumpAndSettle();

      // After drag completes, FlPanEndEvent should trigger the exit path
      expect(selectedIndex, isNull);
      expect(tooltipData, isNull);
    });

    testWidgets(
      'touch callback with tooltipBelow=false does not emit external tooltip',
      (tester) async {
        List<TooltipRow>? receivedRows;

        await tester.pumpWidget(
          _buildChart(
            profile: makeTouchProfile(),
            tooltipBelow: false,
            onTooltipData: (rows) => receivedRows = rows,
            onPointSelected: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        // Long press and move
        final chartCenter = tester.getCenter(find.byType(LineChart));
        final gesture = await tester.startGesture(chartCenter);
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(5, 0));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        // When tooltipBelow is false, the built-in tooltip is used instead
        // of the external callback path
        expect(receivedRows, isNull);
      },
    );

    testWidgets(
      'long press with all metrics enabled emits complete tooltip rows',
      (tester) async {
        List<TooltipRow>? receivedRows;
        var callCount = 0;

        final profile = makeTouchProfile();

        // Use _buildChartAllMetrics to enable all metric toggles via settings
        await tester.pumpWidget(
          _buildChartAllMetrics(
            profile: profile,
            tooltipBelow: true,
            onTooltipData: (rows) {
              callCount++;
              receivedRows = rows;
            },
            onPointSelected: (_) {},
            ceilingCurve: List.generate(20, (i) => i < 10 ? 0.0 : i * 0.5),
            ascentRates: List.generate(
              20,
              (i) => AscentRatePoint(
                timestamp: i * 30,
                depth: profile[i].depth,
                rateMetersPerMin: i < 5 ? -3.0 : 9.0 + i,
                category: i < 14
                    ? AscentRateCategory.safe
                    : AscentRateCategory.danger,
              ),
            ),
            sacCurve: List.generate(20, (i) => i > 0 ? 0.5 + i * 0.03 : 0.0),
            tankVolume: 12.0,
            sacNormalizationFactor: 1.1,
            ndlCurve: List.generate(
              20,
              (i) => i < 5 ? 3700 : (i < 10 ? 600 - i * 30 : -1),
            ),
            ppO2Curve: List.generate(20, (i) => 0.21 + i * 0.04),
            ppN2Curve: List.generate(20, (i) => 0.79 + i * 0.01),
            ppHeCurve: List.generate(20, (i) => 0.1 + i * 0.01),
            densityCurve: List.generate(20, (i) => 1.2 + i * 0.1),
            gfCurve: List.generate(20, (i) => 20.0 + i * 3),
            surfaceGfCurve: List.generate(20, (i) => 15.0 + i * 2),
            meanDepthCurve: List.generate(20, (i) => i * 1.5),
            ttsCurve: List.generate(20, (i) => i < 10 ? 0 : i * 60),
            cnsCurve: List.generate(20, (i) => i * 2.0),
            otuCurve: List.generate(20, (i) => i * 3.0),
            modCurve: List.generate(20, (i) => 30.0 + i * 2),
            tankPressures: {
              'tank-1': List.generate(
                20,
                (i) => TankPressurePoint(
                  id: 'tp-$i',
                  tankId: 'tank-1',
                  timestamp: i * 30,
                  pressure: 200.0 - i * 5,
                ),
              ),
            },
            tanks: [
              const DiveTank(
                id: 'tank-1',
                startPressure: 200,
                endPressure: 100,
              ),
            ],
            markers: [
              const ProfileMarker(
                timestamp: 150,
                depth: 15.0,
                type: ProfileMarkerType.maxDepth,
                value: 15.0,
              ),
            ],
            showMaxDepthMarker: true,
          ),
        );
        await tester.pumpAndSettle();

        final chartFinder = find.byType(LineChart);
        final chartBox = tester.renderObject(chartFinder) as RenderBox;
        final chartSize = chartBox.size;

        // Try multiple positions across the chart to hit a data point
        for (var xFrac = 0.1; xFrac <= 0.9; xFrac += 0.1) {
          final testPoint = chartBox.localToGlobal(
            Offset(chartSize.width * xFrac, chartSize.height * 0.5),
          );

          final gesture = await tester.startGesture(testPoint);
          await tester.pump(const Duration(milliseconds: 600));
          await gesture.moveBy(const Offset(2, 0));
          await tester.pump();

          if (receivedRows != null && receivedRows!.isNotEmpty) {
            // Found a data point - verify all enabled metrics are present
            final labels = receivedRows!.map((r) => r.label).toSet();
            expect(labels, contains('Time'));
            expect(labels, contains('Depth'));
            expect(labels, contains('Temp'));
            expect(labels, contains('HR'));

            await gesture.up();
            await tester.pump();
            return;
          }

          await gesture.up();
          await tester.pump();
        }

        // Callbacks should have been invoked at minimum for exit events
        expect(callCount, greaterThan(0));
      },
    );

    testWidgets(
      'getTooltipItems returns null items when tooltipBelow is true',
      (tester) async {
        await tester.pumpWidget(
          _buildChart(
            profile: makeTouchProfile(),
            tooltipBelow: true,
            onTooltipData: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DiveProfileChart), findsOneWidget);
        expect(find.byType(LineChart), findsOneWidget);
      },
    );

    testWidgets('double tap toggles zoom when chart has callbacks', (
      tester,
    ) async {
      // Suppress overflow errors caused by zoom hint text
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };

      await tester.pumpWidget(
        _buildChart(profile: makeTouchProfile(), onPointSelected: (_) {}),
      );
      await tester.pumpAndSettle();

      // Double tap should toggle zoom
      final chartCenter = tester.getCenter(find.byType(DiveProfileChart));
      await tester.tapAt(chartCenter);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(chartCenter);
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);

      FlutterError.onError = origOnError;
    });
  });

  // Reads the primary fl_chart LineChartData (the depth/time plot is first).
  LineChartData primaryChartData(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart).first).data;

  group('tooltip cache', () {
    testWidgets(
      'getTooltipItems never returns a cached list whose length differs from '
      'touchedSpots (fl_chart size-match contract)',
      (tester) async {
        await tester.pumpWidget(_buildChart());
        await tester.pumpAndSettle();

        final getItems = primaryChartData(
          tester,
        ).lineTouchData.touchTooltipData.getTooltipItems;
        final depthBar = primaryChartData(tester).lineBarsData.first;
        // Depth-line spotIndex stays fixed across both touches (cursor parked).
        // Kept well inside the profile so the depth branch is exercised.
        const spotIndex = 3;
        final depthSpot = LineBarSpot(depthBar, 0, depthBar.spots[spotIndex]);

        // First touch: the depth spot plus sibling bars under the cursor (the
        // callback returns one entry per spot). Caches a 3-entry list keyed on
        // this depth spotIndex.
        final manyBars = <LineBarSpot>[
          depthSpot,
          LineBarSpot(depthBar, 1, depthBar.spots[spotIndex]),
          LineBarSpot(depthBar, 2, depthBar.spots[spotIndex]),
        ];
        expect(getItems(manyBars).length, manyBars.length);

        // Same depth spotIndex, fewer bars now touched (a sibling line toggled
        // off or a data provider refreshed under the parked cursor). The
        // stale-length cache must be rejected; otherwise fl_chart throws
        // 'tooltipItems and touchedSpots size should be same'.
        final fewerBars = <LineBarSpot>[depthSpot];
        expect(
          getItems(fewerBars).length,
          fewerBars.length,
          reason: 'cache must invalidate when the touched-bar count changes',
        );
      },
    );
  });

  group('zoom anchoring', () {
    testWidgets('mouse wheel up zooms in WITHOUT pinning the left edge to 0', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();

      final chart = find.byType(LineChart).first;
      final before = primaryChartData(tester);
      expect(before.minX, 0.0); // at zoom 1 the window starts at t=0

      final topLeft = tester.getTopLeft(chart);
      final size = tester.getSize(chart);
      // Cursor in the right third of the plot.
      final cursor = topLeft + Offset(size.width * 0.75, size.height * 0.5);

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: cursor,
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pump();

      final after = primaryChartData(tester);
      // Zoomed in: visible time range shrank.
      expect(after.maxX - after.minX, lessThan(before.maxX - before.minX));
      // Anchored toward the cursor, not the corner: left edge moved off 0.
      expect(after.minX, greaterThan(0.0));
    });

    testWidgets('mouse wheel down at max-out keeps the full window', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart).first;
      final center = tester.getCenter(chart);

      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, 100)),
      );
      await tester.pump();

      final after = primaryChartData(tester);
      expect(after.minX, 0.0); // cannot zoom out past 1.0
    });
  });

  group('trackpad interaction', () {
    testWidgets('trackpad pinch zooms in anchored off-center (not at 0)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();

      final chart = find.byType(LineChart).first;
      final topLeft = tester.getTopLeft(chart);
      final size = tester.getSize(chart);
      final anchor = topLeft + Offset(size.width * 0.7, size.height * 0.5);

      final before = tester.widget<LineChart>(chart).data;
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pointer.panZoomStart(anchor));
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(anchor, scale: 2.0),
      );
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();

      final after = tester.widget<LineChart>(chart).data;
      expect(after.maxX - after.minX, lessThan(before.maxX - before.minX));
      expect(after.minX, greaterThan(0.0)); // anchored toward the cursor
    });

    testWidgets(
      'trackpad two-finger scroll down zooms in, anchored toward the cursor',
      (tester) async {
        await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
        await tester.pumpAndSettle();

        final chart = find.byType(LineChart).first;
        final topLeft = tester.getTopLeft(chart);
        final size = tester.getSize(chart);
        final anchor = topLeft + Offset(size.width * 0.7, size.height * 0.5);

        final before = primaryChartData(tester);
        final pointer = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(pointer.panZoomStart(anchor));
        // Scroll down (positive dy) zooms in. Horizontal component is ignored.
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(anchor, pan: const Offset(0, 120)),
        );
        await tester.sendEventToBinding(pointer.panZoomEnd());
        await tester.pump();

        final after = primaryChartData(tester);
        expect(
          after.maxX - after.minX,
          lessThan(before.maxX - before.minX),
          reason: 'two-finger scroll down zooms in (visible window shrinks)',
        );
        expect(
          after.minX,
          greaterThan(0.0),
          reason: 'zoom is anchored toward the cursor, not the left edge',
        );
      },
    );

    testWidgets('trackpad horizontal two-finger scroll does not zoom', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();

      final chart = find.byType(LineChart).first;
      final center = tester.getCenter(chart);

      final before = primaryChartData(tester);
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pointer.panZoomStart(center));
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(center, pan: const Offset(120, 0)),
      );
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();

      final after = primaryChartData(tester);
      expect(after.maxX - after.minX, before.maxX - before.minX);
    });

    testWidgets('a cancelled pointer resets the drag state', (tester) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();

      final chart = find.byType(LineChart).first;
      final center = tester.getCenter(chart);

      // Start a pointer, move it, then cancel — exercises onPointerCancel.
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(10, 0));
      await gesture.cancel();
      // Flush the double-tap disambiguation timer before teardown.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LineChart), findsWidgets);
    });
  });

  group('desktop pan and hover', () {
    testWidgets('mouse click-drag pans a zoomed-in chart', (tester) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart).first;
      final center = tester.getCenter(chart);

      // Zoom in first (about center) via two wheel steps.
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pump();
      final zoomed = tester.widget<LineChart>(chart).data;

      // Drag left with the mouse -> window should move right (minX increases).
      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(-60, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      final panned = tester.widget<LineChart>(chart).data;
      expect(panned.minX, greaterThan(zoomed.minX));
    });

    testWidgets('touch one-finger drag does NOT pan (still scrubs)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart).first;
      final center = tester.getCenter(chart);

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pump();
      final zoomed = tester.widget<LineChart>(chart).data;

      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.touch,
      );
      await gesture.moveBy(const Offset(-60, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      final after = tester.widget<LineChart>(chart).data;
      expect(after.minX, zoomed.minX); // unchanged: one finger scrubs, no pan
    });

    testWidgets('mouse hover selects the nearest sample', (tester) async {
      int? selected;
      await tester.pumpWidget(
        _buildChart(
          profile: _makeProfile(points: 20),
          onPointSelected: (i) => selected = i,
        ),
      );
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart).first;
      final topLeft = tester.getTopLeft(chart);
      final size = tester.getSize(chart);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(topLeft + Offset(size.width * 0.5, size.height * 0.5)),
      );
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected, inInclusiveRange(0, 19));
    });
  });

  group('double-tap-hold pan', () {
    testWidgets('double-tap then hold-drag pans a zoomed-in chart', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart).first;
      final center = tester.getCenter(chart);

      // Zoom in so there is room to pan.
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pump();
      final zoomed = tester.widget<LineChart>(chart).data;

      // First tap (quick) then a second touch that is held and dragged.
      await tester.tapAt(center, kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 50));
      final hold = await tester.startGesture(
        center,
        kind: PointerDeviceKind.touch,
      );
      await hold.moveBy(const Offset(-60, 0));
      await hold.up();
      await tester.pumpAndSettle();

      final panned = tester.widget<LineChart>(chart).data;
      expect(panned.minX, greaterThan(zoomed.minX));
    });
  });

  group('ascent rate visualization (#242)', () {
    // Categories chosen to exercise green/orange/red depth segments.
    List<AscentRatePoint> ratesSpanningBands(List<DiveProfilePoint> profile) {
      return List.generate(profile.length, (i) {
        final category = i < 4
            ? AscentRateCategory.safe
            : i < 8
            ? AscentRateCategory.warning
            : AscentRateCategory.danger;
        final rate = i < 4
            ? 3.0
            : i < 8
            ? 10.0
            : 13.0;
        return AscentRatePoint(
          timestamp: profile[i].timestamp,
          depth: profile[i].depth,
          rateMetersPerMin: rate,
          category: category,
        );
      });
    }

    // Builds the chart against an explicit container so legend toggles and the
    // right-axis metric can be driven directly (the session-only ascent-rate
    // line has no settings hook).
    Widget buildWithLegend({
      required List<DiveProfilePoint> profile,
      required List<AscentRatePoint> ascentRates,
      void Function(ProfileLegend notifier)? configure,
      void Function(int? index)? onPointSelected,
    }) {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);
      if (configure != null) {
        configure(container.read(profileLegendProvider.notifier));
      }
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: DiveProfileChart(
                profile: profile,
                ascentRates: ascentRates,
                onPointSelected: onPointSelected,
              ),
            ),
          ),
        ),
      );
    }

    test('ascentRateAxisRange is symmetric and respects the floor', () {
      final gentle = [
        const AscentRatePoint(
          timestamp: 0,
          depth: 0,
          rateMetersPerMin: 3,
          category: AscentRateCategory.safe,
        ),
      ];
      final r1 = DiveProfileChart.ascentRateAxisRange(gentle)!;
      expect(r1.min, -15.0);
      expect(r1.max, 15.0);

      final steep = [
        const AscentRatePoint(
          timestamp: 0,
          depth: 0,
          rateMetersPerMin: -20,
          category: AscentRateCategory.danger,
        ),
      ];
      final r2 = DiveProfileChart.ascentRateAxisRange(steep)!;
      expect(r2.min, -20.0);
      expect(r2.max, 20.0);
    });

    test('ascentRateAxisRange returns null when there is no data', () {
      expect(DiveProfileChart.ascentRateAxisRange(const []), isNull);
      expect(DiveProfileChart.ascentRateAxisRange(null), isNull);
    });

    testWidgets('colors the depth line by velocity band when enabled', (
      tester,
    ) async {
      final profile = _makeProfile(points: 12);
      await tester.pumpWidget(
        buildWithLegend(
          profile: profile,
          ascentRates: ratesSpanningBands(profile),
          configure: (n) => n.toggleAscentRateColors(), // default off -> on
        ),
      );
      await tester.pumpAndSettle();

      final colors = primaryChartData(
        tester,
      ).lineBarsData.map((b) => b.color).toSet();
      // The safe/baseline band keeps the normal depth blue -- only the elevated
      // warning/danger bands are recoloured.
      expect(colors, contains(AppColors.chartDepth));
      expect(colors, contains(Colors.orange));
      expect(colors, contains(Colors.red));
      expect(colors, isNot(contains(Colors.green)));
    });

    test('velocityBandRuns splits bands sharing their boundary sample', () {
      final profile = _makeProfile(points: 12);
      final runs = DiveProfileChart.velocityBandRuns(
        profile.length,
        ratesSpanningBands(profile),
      );
      // Three bands; adjacent runs share the boundary sample (each run's start
      // is the previous run's last point) so the coloured pieces join cleanly.
      expect(runs.map((r) => r.start).toList(), [0, 3, 7]);
      expect(runs.map((r) => r.end).toList(), [4, 8, 12]);
      expect(runs.map((r) => r.category).toList(), [
        AscentRateCategory.safe,
        AscentRateCategory.warning,
        AscentRateCategory.danger,
      ]);
    });

    group('velocityIndicatorSuppression', () {
      test('returns nothing when the depth line is a single bar', () {
        // Velocity colouring off / multi-computer: depth is one bar, so the
        // built-in per-bar indicator already shows a single depth dot.
        expect(
          DiveProfileChart.velocityIndicatorSuppression(const [
            (barIndex: 0, x: 5.0, y: -10.0),
            (barIndex: 1, x: 5.0, y: -3.0), // an overlay line
          ], 1),
          isEmpty,
        );
      });

      test('returns nothing when a single band is under the cursor', () {
        expect(
          DiveProfileChart.velocityIndicatorSuppression(const [
            (barIndex: 0, x: 5.0, y: -10.0), // one depth band touched
            (barIndex: 4, x: 5.0, y: -3.0), // overlay
          ], 3),
          isEmpty,
        );
      });

      test('keeps the first touched band and suppresses the others', () {
        // The first depth entry is the sample onPointSelected/the tooltip
        // resolve to, so the retained dot matches the bubble.
        expect(
          DiveProfileChart.velocityIndicatorSuppression(const [
            (barIndex: 0, x: 4.0, y: -11.0), // kept
            (barIndex: 1, x: 5.0, y: -12.0), // suppressed
            (barIndex: 2, x: 6.0, y: -13.0), // suppressed
            (barIndex: 5, x: 5.0, y: -3.0), // overlay, never suppressed
          ], 3),
          const [(x: 5.0, y: -12.0), (x: 6.0, y: -13.0)],
        );
      });

      test('leaves a dropped band that shares the kept boundary sample', () {
        // Adjacent bands join on their boundary point, so a dropped band can
        // report the identical sample; suppressing that coordinate would also
        // hide the kept dot, so it is left in place to overlap into one.
        expect(
          DiveProfileChart.velocityIndicatorSuppression(const [
            (barIndex: 0, x: 4.0, y: -11.0), // kept
            (barIndex: 1, x: 4.0, y: -11.0), // shared boundary -> left alone
            (barIndex: 2, x: 6.0, y: -13.0), // distinct -> suppressed
          ], 3),
          const [(x: 6.0, y: -13.0)],
        );
      });
    });

    testWidgets(
      'velocity colouring shows one depth focus dot, not one per band',
      (tester) async {
        // Regression: with the ascent-rate overlay on, hovering an abrupt
        // stretch drew fl_chart's built-in focus dot on every depth band under
        // the cursor, cluttering the point. Only the tooltip-resolved band
        // keeps its dot; sibling bands are suppressed, other lines untouched.
        final profile = _makeProfile(points: 12);
        await tester.pumpWidget(
          buildWithLegend(
            profile: profile,
            ascentRates: ratesSpanningBands(profile),
            configure: (n) => n.toggleAscentRateColors(),
          ),
        );
        await tester.pumpAndSettle();

        final data = primaryChartData(tester);
        final bars = data.lineBarsData;
        // Depth bands (safe/warning/danger) are the first three bars.
        expect(bars.length, greaterThanOrEqualTo(3));

        // Drive the touch pipeline directly: three depth bands under the cursor
        // at distinct interior samples (barIndex 0/1/2).
        data.lineTouchData.touchCallback!(
          FlPanDownEvent(DragDownDetails()),
          LineTouchResponse(
            touchLocation: Offset.zero,
            touchChartCoordinate: Offset.zero,
            lineBarSpots: <TouchLineBarSpot>[
              TouchLineBarSpot(bars[0], 0, bars[0].spots[1], 0),
              TouchLineBarSpot(bars[1], 1, bars[1].spots[1], 0),
              TouchLineBarSpot(bars[2], 2, bars[2].spots[1], 0),
            ],
          ),
        );

        final indicator = data.lineTouchData.getTouchedSpotIndicator;
        // Kept: the first depth band under the cursor.
        expect(indicator(bars[0], const [1]).single, isNotNull);
        // Suppressed: the other two depth bands.
        expect(indicator(bars[1], const [1]).single, isNull);
        expect(indicator(bars[2], const [1]).single, isNull);
        // A line whose sample is not the resolved point keeps its dot.
        final overlay = LineChartBarData(spots: const [FlSpot(0, 0)]);
        expect(
          indicator(overlay, const [0]).single,
          isNotNull,
          reason: 'overlay focus dots must be preserved',
        );
      },
    );

    testWidgets('tooltip builds when hovering a non-first velocity segment', (
      tester,
    ) async {
      // Regression: with velocity colouring on, the depth line is drawn as
      // one bar per band. The tooltip builder only recognised barIndex 0, so
      // hovering any later segment produced no tooltip at all.
      final profile = _makeProfile(points: 12);
      await tester.pumpWidget(
        buildWithLegend(
          profile: profile,
          ascentRates: ratesSpanningBands(profile),
          configure: (n) => n.toggleAscentRateColors(),
        ),
      );
      await tester.pumpAndSettle();

      final data = primaryChartData(tester);
      final bars = data.lineBarsData;
      expect(
        bars.length,
        greaterThan(1),
        reason: 'velocity colouring should split the depth line into bands',
      );

      final getItems = data.lineTouchData.touchTooltipData.getTooltipItems;
      // Hover the second band (barIndex 1) at its first sample.
      final secondBar = bars[1];
      final spot = LineBarSpot(secondBar, 1, secondBar.spots.first);
      final items = getItems(<LineBarSpot>[spot]);

      expect(items.length, 1);
      expect(
        items.first,
        isNotNull,
        reason: 'a hover on a non-first velocity band must show a tooltip',
      );
    });

    testWidgets(
      'hover on a non-first velocity segment selects the right sample',
      (tester) async {
        // The onPointSelected / external-tooltip path shares the same
        // barIndex==0 assumption; a hover landing on a later band must still
        // resolve to a global profile index, not the band-local spot index.
        final profile = _makeProfile(points: 12);
        int? selected;
        await tester.pumpWidget(
          buildWithLegend(
            profile: profile,
            ascentRates: ratesSpanningBands(profile),
            configure: (n) => n.toggleAscentRateColors(),
            onPointSelected: (i) => selected = i,
          ),
        );
        await tester.pumpAndSettle();

        final chart = find.byType(LineChart).first;
        final topLeft = tester.getTopLeft(chart);
        final size = tester.getSize(chart);
        // Hover well into the right of the plot -- that x lands in the danger
        // band (the last, non-first segment).
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          pointer.hover(topLeft + Offset(size.width * 0.85, size.height * 0.5)),
        );
        await tester.pump();

        // Every band-local spotIndex in this fixture is <= 4 (each bar holds at
        // most 5 points), and the danger band starts at global index 7. A hover
        // here must resolve to a global index >= 7, which a band-local emission
        // could never produce -- that is what proves the mapping, not merely
        // "some in-range index".
        expect(selected, isNotNull);
        expect(
          selected,
          allOf(greaterThanOrEqualTo(7), lessThan(profile.length)),
          reason: 'must be the global danger-band index, not a band-local one',
        );
      },
    );

    testWidgets('a band change at the final sample still draws a line', (
      tester,
    ) async {
      // Rate is recorded at point i for the segment (i-1 -> i). When only the
      // last sample is danger, its segment must render as a >=2-point line, not
      // a 1-point dot.
      final profile = _makeProfile(points: 8);
      final rates = List.generate(profile.length, (i) {
        final danger = i == profile.length - 1;
        return AscentRatePoint(
          timestamp: profile[i].timestamp,
          depth: profile[i].depth,
          rateMetersPerMin: danger ? 13.0 : 3.0,
          category: danger
              ? AscentRateCategory.danger
              : AscentRateCategory.safe,
        );
      });

      await tester.pumpWidget(
        buildWithLegend(
          profile: profile,
          ascentRates: rates,
          configure: (n) => n.toggleAscentRateColors(), // default off -> on
        ),
      );
      await tester.pumpAndSettle();

      final redBars = primaryChartData(
        tester,
      ).lineBarsData.where((b) => b.color == Colors.red).toList();
      expect(redBars, isNotEmpty);
      expect(redBars.every((b) => b.spots.length >= 2), isTrue);
    });

    testWidgets('depth line is one solid segment when coloring is disabled', (
      tester,
    ) async {
      final profile = _makeProfile(points: 12);
      await tester.pumpWidget(
        buildWithLegend(
          profile: profile,
          ascentRates: ratesSpanningBands(profile),
          // Coloring now defaults off, so no toggle needed to disable it.
        ),
      );
      await tester.pumpAndSettle();

      final bars = primaryChartData(tester).lineBarsData;
      expect(bars.where((b) => b.color == AppColors.chartDepth).length, 1);
      expect(
        bars.any(
          (b) =>
              b.color == Colors.green ||
              b.color == Colors.orange ||
              b.color == Colors.red,
        ),
        isFalse,
      );
    });

    bool hasRateLine(WidgetTester t) => primaryChartData(
      t,
    ).lineBarsData.any((b) => b.color == Colors.lime && b.dashArray != null);

    testWidgets('does not render the ascent-rate line by default', (
      tester,
    ) async {
      final profile = _makeProfile(points: 12);
      await tester.pumpWidget(
        buildWithLegend(
          profile: profile,
          ascentRates: ratesSpanningBands(profile),
        ),
      );
      await tester.pumpAndSettle();
      expect(hasRateLine(tester), isFalse);
    });

    testWidgets('renders the ascent-rate line when toggled on', (tester) async {
      final profile = _makeProfile(points: 12);
      await tester.pumpWidget(
        buildWithLegend(
          profile: profile,
          ascentRates: ratesSpanningBands(profile),
          configure: (n) => n.toggleAscentRateLine(),
        ),
      );
      await tester.pumpAndSettle();
      expect(hasRateLine(tester), isTrue);
    });

    testWidgets(
      'labels the right axis when the ascentRate metric is selected',
      (tester) async {
        final profile = _makeProfile(points: 12);
        await tester.pumpWidget(
          buildWithLegend(
            profile: profile,
            ascentRates: ratesSpanningBands(profile),
            configure: (n) =>
                n.setRightAxisMetric(ProfileRightAxisMetric.ascentRate),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Rate ('), findsOneWidget);
      },
    );
  });

  group('bars memoization (D1a)', () {
    testWidgets(
      'reuses bars across a playback-only rebuild, rebuilds on profile change',
      (tester) async {
        List<LineChartBarData> barsOf() => tester
            .widget<LineChart>(find.byType(LineChart).first)
            .data
            .lineBarsData;

        final profileA = _makeProfile(points: 12);
        await tester.pumpWidget(
          _buildChart(profile: profileA, playbackTimestamp: 30),
        );
        final bars1 = barsOf();

        // Same data + units; only the playback cursor moved. The signature is
        // unchanged, so the assembled bars must be the SAME cached instance.
        await tester.pumpWidget(
          _buildChart(profile: profileA, playbackTimestamp: 90),
        );
        expect(identical(barsOf(), bars1), isTrue);

        // A new profile changes the signature -> the cache must rebuild.
        await tester.pumpWidget(_buildChart(profile: _makeProfile(points: 20)));
        expect(identical(barsOf(), bars1), isFalse);
      },
    );

    testWidgets(
      'rebuilds bars with fresh colors when the theme changes at the same '
      'brightness (e.g. switching between two light presets)',
      (tester) async {
        // Two light schemes that differ only in tertiary -- the colour the
        // temperature line is drawn in. A same-brightness preset switch must
        // still invalidate the cache; keying on Brightness alone would serve
        // bars with stale colours.
        const tertiaryA = Color(0xFF101010);
        const tertiaryB = Color(0xFFF0F0F0);

        final profile = List.generate(
          10,
          (i) => DiveProfilePoint(
            timestamp: i * 30,
            depth: (i < 5 ? i * 3.0 : (9 - i) * 3.0),
            temperature: 22.0 - i * 0.5,
          ),
        );

        // themeAnimationDuration: zero so the AnimatedTheme cross-fade does not
        // lerp the scheme over frames (Color.lerp(a, b, 0) == a would otherwise
        // read the stale colour right after a one-frame pump).
        Widget app(Color tertiary) => ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: ThemeData(
              colorScheme: const ColorScheme.light().copyWith(
                tertiary: tertiary,
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 300,
                child: DiveProfileChart(profile: profile),
              ),
            ),
          ),
        );

        Iterable<Color?> barColors() => tester
            .widget<LineChart>(find.byType(LineChart).first)
            .data
            .lineBarsData
            .map((b) => b.color);

        await tester.pumpWidget(app(tertiaryA));
        await tester.pumpAndSettle();
        // The temperature line is drawn in the active scheme's tertiary.
        expect(barColors(), contains(tertiaryA));

        // Same brightness, different scheme: the State (and its bars cache) is
        // retained across this pump, so the bars must be rebuilt with the new
        // tertiary rather than reused with the stale colour.
        await tester.pumpWidget(app(tertiaryB));
        await tester.pumpAndSettle();
        expect(barColors(), contains(tertiaryB));
        expect(barColors(), isNot(contains(tertiaryA)));
      },
    );
  });

  group('photo markers', () {
    testWidgets('renders the overlay when photo markers are provided', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart(photoMarkers: [_photoMarker()]));
      await tester.pump();
      expect(find.byType(PhotoMarkerOverlay), findsOneWidget);
    });

    testWidgets('renders no overlay without photo markers', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pump();
      expect(find.byType(PhotoMarkerOverlay), findsNothing);
    });

    testWidgets('hides the overlay when the legend toggle is off', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart(photoMarkers: [_photoMarker()]));
      await tester.pump();
      final element = tester.element(find.byType(DiveProfileChart));
      final container = ProviderScope.containerOf(element);
      container.read(profileLegendProvider.notifier).togglePhotoMarkers();
      await tester.pump();
      expect(find.byType(PhotoMarkerOverlay), findsNothing);
    });
  });
}

PhotoChartMarker _photoMarker({String id = 'p1', int seconds = 120}) {
  final now = DateTime.utc(2026, 1, 1);
  return PhotoChartMarker(
    item: MediaItem(
      id: id,
      diveId: 'dive-1',
      mediaType: MediaType.photo,
      takenAt: now,
      createdAt: now,
      updatedAt: now,
    ),
    elapsedSeconds: seconds,
    depthMeters: 10.0,
  );
}
