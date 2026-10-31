import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_editor_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.settings = const AppSettings()]);

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
  AppSettings settings = const AppSettings(),
  EditorMode mode = EditorMode.select,
  ({int start, int end})? selectedRange,
  void Function(int timestamp, double depth)? onTap,
  void Function(int startTimestamp, int endTimestamp)? onRangeChanged,
  VoidCallback? onRangeCleared,
}) {
  final points = profile ?? _makeProfile();
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: ProfileEditorChart(
            originalProfile: points,
            editedProfile: points,
            mode: mode,
            selectedRange: selectedRange,
            onTap: onTap,
            onRangeChanged: onRangeChanged,
            onRangeCleared: onRangeCleared,
          ),
        ),
      ),
    ),
  );
}

/// Where [seconds] falls on the plot of a chart showing [profile], whose x
/// axis runs 5% past each end of the dive. The plot starts after the depth
/// axis's 40px reserved width.
///
/// Aim between samples: a pixel maps back to chart time in floating point, so
/// a point aimed exactly at a sample can land just short of it and snap out to
/// the one before.
Offset _plotPoint(
  WidgetTester tester,
  double seconds, {
  List<DiveProfilePoint>? profile,
}) {
  final points = profile ?? _makeProfile();
  final first = points.first.timestamp.toDouble();
  final last = points.last.timestamp.toDouble();
  final pad = (last - first) * 0.05;
  final rect = tester.getRect(find.byType(LineChart));
  final left = rect.left + 40;
  final fraction = (seconds - (first - pad)) / (last - first + 2 * pad);
  return Offset(left + fraction * (rect.right - left), rect.center.dy);
}

/// Drags in steps, as a real pointer stream does, so the drag clears the
/// recognizers' slop before its last positions arrive.
Future<void> _drag(
  WidgetTester tester,
  Offset from,
  Offset to, {
  bool release = true,
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final gesture = await tester.startGesture(from, kind: kind);
  for (var step = 1; step <= 10; step++) {
    await gesture.moveTo(Offset.lerp(from, to, step / 10)!);
    await tester.pump();
  }
  if (release) {
    await gesture.up();
    await tester.pump();
  }
}

/// Taps the plotted spot at [spotIndex] on the edited line (bar 1) through the
/// chart's real touch callback, the way fl_chart reports a tap.
void _tapPlottedSpot(WidgetTester tester, int spotIndex) {
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  final bar = chart.data.lineBarsData[1];
  chart.data.lineTouchData.touchCallback!(
    FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
    LineTouchResponse(
      touchLocation: Offset.zero,
      touchChartCoordinate: Offset.zero,
      lineBarSpots: [TouchLineBarSpot(bar, 1, bar.spots[spotIndex], 0)],
    ),
  );
}

void main() {
  group('ProfileEditorChart', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileEditorChart), findsOneWidget);
    });

    testWidgets('chart data changes are not implicitly animated', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      // Editing rebuilds the chart data (adding a waypoint shifts marker
      // indices; range selection shading tracks the pointer). fl_chart's
      // default 150ms lerp would slide markers between unrelated positions
      // and lag the selection behind the cursor, so the editor must render
      // every data change immediately.
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.duration, Duration.zero);
    });

    group('range selection (issue #3909)', () {
      late List<(int, int)> ranges;
      late int clears;

      Future<void> pumpChart(
        WidgetTester tester, {
        List<DiveProfilePoint>? profile,
        EditorMode mode = EditorMode.select,
        void Function(int timestamp, double depth)? onTap,
      }) async {
        ranges = [];
        clears = 0;
        await tester.pumpWidget(
          _buildChart(
            profile: profile,
            mode: mode,
            onTap: onTap,
            onRangeChanged: (start, end) => ranges.add((start, end)),
            onRangeCleared: () => clears++,
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('a drag in Select mode selects the samples it crosses', (
        tester,
      ) async {
        await pumpChart(tester);

        await _drag(tester, _plotPoint(tester, 70), _plotPoint(tester, 170));

        // Samples are 30s apart, so each end snaps out to a sample.
        expect(ranges.last, (60, 180));
      });

      testWidgets('the selection follows the pointer during the drag', (
        tester,
      ) async {
        await pumpChart(tester);

        await _drag(
          tester,
          _plotPoint(tester, 40),
          _plotPoint(tester, 230),
          release: false,
        );

        expect(ranges.last, (30, 240));
        expect(ranges.map((r) => r.$2).toSet().length, greaterThan(1));
      });

      testWidgets('a right-to-left drag gives an ordered range', (
        tester,
      ) async {
        await pumpChart(tester);

        await _drag(tester, _plotPoint(tester, 200), _plotPoint(tester, 100));

        expect(ranges.last, (90, 210));
      });

      testWidgets('a mouse drag selects too', (tester) async {
        await pumpChart(tester);

        await _drag(
          tester,
          _plotPoint(tester, 100),
          _plotPoint(tester, 200),
          kind: PointerDeviceKind.mouse,
        );

        expect(ranges.last, (90, 210));
      });

      testWidgets('a drag held in place first still selects', (tester) async {
        await pumpChart(tester);

        final from = _plotPoint(tester, 100);
        final to = _plotPoint(tester, 200);
        final gesture = await tester.startGesture(from);
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        for (var step = 1; step <= 10; step++) {
          await gesture.moveTo(Offset.lerp(from, to, step / 10)!);
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();

        expect(ranges.last, (90, 210));
      });

      testWidgets('a drag past the plot stops at the dive ends', (
        tester,
      ) async {
        await pumpChart(tester);

        await _drag(tester, _plotPoint(tester, 130), _plotPoint(tester, 900));
        expect(ranges.last, (120, 270));

        await _drag(tester, _plotPoint(tester, 130), _plotPoint(tester, -5));
        expect(ranges.last, (0, 150));
      });

      testWidgets('a drag between two samples selects both of them', (
        tester,
      ) async {
        const sparse = [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 600, depth: 20),
          DiveProfilePoint(timestamp: 1800, depth: 20),
          DiveProfilePoint(timestamp: 2400, depth: 0),
        ];
        await pumpChart(tester, profile: sparse);

        await _drag(
          tester,
          _plotPoint(tester, 800, profile: sparse),
          _plotPoint(tester, 1600, profile: sparse),
        );

        expect(ranges.last, (600, 1800));
      });

      testWidgets('a drag wholly past the end of the dive selects nothing', (
        tester,
      ) async {
        // A long tail of padding beside one short sample run would need a
        // huge chart, so the drag starts on the right padding instead.
        await pumpChart(tester);

        await _drag(tester, _plotPoint(tester, 275), _plotPoint(tester, 900));

        expect(ranges, isEmpty);
      });

      testWidgets('reports a range only when it changes', (tester) async {
        ranges = [];
        ({int start, int end})? selected;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => _buildChart(
              selectedRange: selected,
              // The page hands each reported range back to the chart.
              onRangeChanged: (start, end) {
                ranges.add((start, end));
                setState(() => selected = (start: start, end: end));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Stays between the 90s and 120s samples for the whole drag.
        await _drag(
          tester,
          _plotPoint(tester, 91),
          _plotPoint(tester, 119),
          kind: PointerDeviceKind.mouse,
        );

        expect(ranges, [(90, 120)]);
      });

      testWidgets('a tap clears the selection', (tester) async {
        await pumpChart(tester);

        await tester.tapAt(_plotPoint(tester, 120));
        await tester.pump();

        expect(clears, 1);
        expect(ranges, isEmpty);
      });

      testWidgets('a drag does not clear the selection it makes', (
        tester,
      ) async {
        await pumpChart(tester);

        await _drag(tester, _plotPoint(tester, 90), _plotPoint(tester, 210));

        expect(clears, 0);
      });

      testWidgets('Smooth mode selects a range as well', (tester) async {
        await pumpChart(tester, mode: EditorMode.smooth);

        await _drag(tester, _plotPoint(tester, 100), _plotPoint(tester, 200));

        expect(ranges.last, (90, 210));
      });

      for (final mode in [EditorMode.outlier, EditorMode.trim]) {
        testWidgets('${mode.name} mode ignores the chart', (tester) async {
          await pumpChart(tester, mode: mode);

          await _drag(tester, _plotPoint(tester, 90), _plotPoint(tester, 210));
          await tester.tapAt(_plotPoint(tester, 120));
          await tester.pump();

          expect(ranges, isEmpty);
          expect(clears, 0);
        });
      }

      testWidgets('Draw mode still places waypoints and selects no range', (
        tester,
      ) async {
        final taps = <int>[];
        await pumpChart(
          tester,
          mode: EditorMode.draw,
          onTap: (timestamp, depth) => taps.add(timestamp),
        );

        await _drag(tester, _plotPoint(tester, 90), _plotPoint(tester, 210));
        await tester.tapAt(_plotPoint(tester, 120));
        await tester.pump();

        expect(ranges, isEmpty);
        expect(clears, 0);
        expect(taps, [120]);
      });

      testWidgets('selecting shows no tooltip, only Draw mode does', (
        tester,
      ) async {
        LineTouchData touchData() =>
            tester.widget<LineChart>(find.byType(LineChart)).data.lineTouchData;

        await pumpChart(tester);
        expect(touchData().enabled, isTrue);
        expect(touchData().handleBuiltInTouches, isFalse);

        await pumpChart(tester, mode: EditorMode.draw);
        expect(touchData().handleBuiltInTouches, isTrue);
      });
    });

    group('draw mode tap', () {
      const profile = [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 60, depth: 20),
        DiveProfilePoint(timestamp: 120, depth: 0),
      ];

      testWidgets('reports metres when the depth unit is feet', (tester) async {
        final taps = <(int, double)>[];
        await tester.pumpWidget(
          _buildChart(
            profile: profile,
            settings: const AppSettings(depthUnit: DepthUnit.feet),
            mode: EditorMode.draw,
            onTap: (timestamp, depth) => taps.add((timestamp, depth)),
          ),
        );
        await tester.pumpAndSettle();

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.data.lineBarsData[1].spots[1].y, closeTo(-65.6168, 1e-6));

        _tapPlottedSpot(tester, 1);

        expect(taps, hasLength(1));
        expect(taps.single.$1, 60);
        expect(taps.single.$2, closeTo(20, 1e-9));
      });

      testWidgets('reports metres when the depth unit is metres', (
        tester,
      ) async {
        final taps = <(int, double)>[];
        await tester.pumpWidget(
          _buildChart(
            profile: profile,
            mode: EditorMode.draw,
            onTap: (timestamp, depth) => taps.add((timestamp, depth)),
          ),
        );
        await tester.pumpAndSettle();

        _tapPlottedSpot(tester, 1);

        expect(taps, hasLength(1));
        expect(taps.single.$1, 60);
        expect(taps.single.$2, closeTo(20, 1e-9));
      });

      testWidgets('drawing along a profile in feet preserves its depth', (
        tester,
      ) async {
        final waypoints = <ProfileWaypoint>[];
        await tester.pumpWidget(
          _buildChart(
            profile: profile,
            settings: const AppSettings(depthUnit: DepthUnit.feet),
            mode: EditorMode.draw,
            onTap: (timestamp, depth) => waypoints.add(
              ProfileWaypoint(timestamp: timestamp, depth: depth),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (var i = 0; i < profile.length; i++) {
          _tapPlottedSpot(tester, i);
        }

        final generated = ProfileEditingService().interpolateWaypoints(
          waypoints,
        );
        final atDeepest = generated.firstWhere((p) => p.timestamp == 60);
        expect(atDeepest.depth, closeTo(20, 1e-9));
      });

      testWidgets('ignores taps outside draw mode', (tester) async {
        final taps = <(int, double)>[];
        await tester.pumpWidget(
          _buildChart(
            profile: profile,
            settings: const AppSettings(depthUnit: DepthUnit.feet),
            onTap: (timestamp, depth) => taps.add((timestamp, depth)),
          ),
        );
        await tester.pumpAndSettle();

        _tapPlottedSpot(tester, 1);

        expect(taps, isEmpty);
      });
    });
  });
}
