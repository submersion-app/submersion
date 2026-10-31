import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';
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

/// Counts every element read from it. ListBase sends `any`, `map` and plain
/// iteration through [operator []], so no way of scanning the list slips past.
class _CountingList<E> extends ListBase<E> {
  _CountingList(this._items);

  final List<E> _items;
  int reads = 0;

  @override
  int get length => _items.length;

  @override
  set length(int newLength) => throw UnsupportedError('read only');

  @override
  E operator [](int index) {
    reads++;
    return _items[index];
  }

  @override
  void operator []=(int index, E value) => throw UnsupportedError('read only');
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
  List<OutlierResult>? outliers,
  List<ProfileWaypoint>? waypoints,
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
            outliers: outliers,
            waypoints: waypoints,
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

/// The dots a paint would draw on the edited line (bar 1), keyed by timestamp.
/// Follows fl_chart's drawDots: a painter is only asked for once
/// checkToShowDot lets the sample through.
Map<int, FlDotCirclePainter> _paintedDots(WidgetTester tester) {
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  final bar = chart.data.lineBarsData[1];
  return {
    for (var i = 0; i < bar.spots.length; i++)
      if (bar.dotData.show && bar.dotData.checkToShowDot(bar.spots[i], bar))
        bar.spots[i].x.toInt():
            bar.dotData.getDotPainter(bar.spots[i], 0, bar, i)
                as FlDotCirclePainter,
  };
}

OutlierResult _outlierAt(int timestamp) => OutlierResult(
  index: 0,
  timestamp: timestamp,
  depth: 10,
  depthDelta: 5,
  zScore: 4,
);

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

    group('markers (issue #3867)', () {
      const outliers = [
        OutlierResult(
          index: 2,
          timestamp: 60,
          depth: 6,
          depthDelta: 5,
          zScore: 4,
        ),
        OutlierResult(
          index: 5,
          timestamp: 150,
          depth: 15,
          depthDelta: 5,
          zScore: 4,
        ),
      ];
      const waypoints = [
        ProfileWaypoint(timestamp: 90, depth: 9),
        ProfileWaypoint(timestamp: 210, depth: 12),
      ];

      testWidgets('Outlier mode rings each outlier in the error colours', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildChart(mode: EditorMode.outlier, outliers: outliers),
        );
        await tester.pumpAndSettle();

        final dots = _paintedDots(tester);
        expect(dots.keys, [60, 150]);
        final scheme = Theme.of(
          tester.element(find.byType(ProfileEditorChart)),
        ).colorScheme;
        for (final dot in dots.values) {
          expect(dot.radius, 5);
          expect(dot.color, scheme.error);
          expect(dot.strokeWidth, 1.5);
          expect(dot.strokeColor, scheme.onError);
        }
      });

      testWidgets('Draw mode marks each waypoint in blue', (tester) async {
        await tester.pumpWidget(
          _buildChart(mode: EditorMode.draw, waypoints: waypoints),
        );
        await tester.pumpAndSettle();

        final dots = _paintedDots(tester);
        expect(dots.keys, [90, 210]);
        for (final dot in dots.values) {
          expect(dot.radius, 6);
          expect(dot.color, Colors.blue);
          expect(dot.strokeWidth, 2);
        }
      });

      testWidgets('each mode marks only its own list', (tester) async {
        Future<Iterable<int>> markedIn(EditorMode mode) async {
          await tester.pumpWidget(
            _buildChart(mode: mode, outliers: outliers, waypoints: waypoints),
          );
          await tester.pumpAndSettle();
          return _paintedDots(tester).keys;
        }

        expect(await markedIn(EditorMode.outlier), [60, 150]);
        expect(await markedIn(EditorMode.draw), [90, 210]);
        expect(await markedIn(EditorMode.select), isEmpty);
        expect(await markedIn(EditorMode.smooth), isEmpty);
        expect(await markedIn(EditorMode.trim), isEmpty);
      });

      testWidgets('marks nothing before outliers are detected', (tester) async {
        await tester.pumpWidget(_buildChart(mode: EditorMode.outlier));
        await tester.pumpAndSettle();

        expect(_paintedDots(tester), isEmpty);
      });

      testWidgets('marks nothing before a waypoint is placed', (tester) async {
        await tester.pumpWidget(_buildChart(mode: EditorMode.draw));
        await tester.pumpAndSettle();

        expect(_paintedDots(tester), isEmpty);
      });

      testWidgets('Draw mode keeps its touch indicator without waypoints', (
        tester,
      ) async {
        await tester.pumpWidget(_buildChart(mode: EditorMode.draw));
        await tester.pumpAndSettle();

        // fl_chart sizes the touched dot from this flag, so hiding the dots
        // while no waypoint exists would change the indicator under a finger.
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.data.lineBarsData[1].dotData.show, isTrue);
      });

      testWidgets('paint does not rescan the outliers for each sample', (
        tester,
      ) async {
        final profile = _makeProfile(points: 2000);
        final flagged = _CountingList([
          for (var i = 0; i < profile.length; i += 2)
            _outlierAt(profile[i].timestamp),
        ]);

        await tester.pumpWidget(
          _buildChart(
            profile: profile,
            mode: EditorMode.outlier,
            outliers: flagged,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          flagged.reads,
          lessThanOrEqualTo(profile.length + flagged.length),
        );

        // Later paints reuse the index built with the chart data.
        final readsAfterBuild = flagged.reads;
        expect(_paintedDots(tester), hasLength(flagged.length));
        expect(flagged.reads, readsAfterBuild);
      });

      testWidgets('paint does not rescan the waypoints for each sample', (
        tester,
      ) async {
        final profile = _makeProfile(points: 2000);
        final placed = _CountingList([
          for (var i = 0; i < profile.length; i += 2)
            ProfileWaypoint(timestamp: profile[i].timestamp, depth: 5),
        ]);

        await tester.pumpWidget(
          _buildChart(
            profile: profile,
            mode: EditorMode.draw,
            waypoints: placed,
          ),
        );
        await tester.pumpAndSettle();

        expect(placed.reads, lessThanOrEqualTo(profile.length + placed.length));

        final readsAfterBuild = placed.reads;
        expect(_paintedDots(tester), hasLength(placed.length));
        expect(placed.reads, readsAfterBuild);
      });

      group('through an editing session', () {
        // A spike too fast to be real: samples 4s apart, 20m out and back.
        final noisy = [
          for (var i = 0; i < 40; i++)
            DiveProfilePoint(timestamp: i * 4, depth: i == 20 ? 40 : 20),
        ];

        late ProfileEditorNotifier notifier;
        late StateSetter rebuild;

        Future<void> pumpSession(WidgetTester tester) async {
          notifier = ProfileEditorNotifier(
            originalProfile: noisy,
            editingService: ProfileEditingService(),
          );
          addTearDown(notifier.dispose);
          await tester.pumpWidget(
            StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                final state = notifier.state;
                return _buildChart(
                  profile: state.editedProfile,
                  mode: state.mode,
                  outliers: state.detectedOutliers,
                  waypoints: state.waypoints,
                );
              },
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> act(WidgetTester tester, VoidCallback action) async {
          action();
          rebuild(() {});
          await tester.pump();
        }

        testWidgets('outlier markers follow edits and undo', (tester) async {
          await pumpSession(tester);
          await act(tester, () {
            notifier
              ..setMode(EditorMode.outlier)
              ..detectOutliers();
          });

          final detected = _paintedDots(tester).keys.toList();
          expect(detected, contains(80));
          expect(
            detected,
            notifier.state.detectedOutliers!.map((o) => o.timestamp).toList(),
          );

          // Outliers describe one version of the profile, so an edit or its
          // undo drops the markers until the diver detects again.
          await act(tester, notifier.applySmoothing);
          expect(_paintedDots(tester), isEmpty);

          await act(tester, notifier.undo);
          expect(_paintedDots(tester), isEmpty);

          await act(tester, notifier.detectOutliers);
          expect(_paintedDots(tester).keys, detected);
        });

        testWidgets('a removed outlier loses its marker', (tester) async {
          await pumpSession(tester);
          await act(tester, () {
            notifier
              ..setMode(EditorMode.outlier)
              ..detectOutliers();
          });
          final detected = notifier.state.detectedOutliers!;

          await act(
            tester,
            () => notifier.removeSelectedOutliers([detected.first]),
          );

          expect(
            _paintedDots(tester).keys,
            notifier.state.detectedOutliers!.map((o) => o.timestamp).toList(),
          );
          expect(
            _paintedDots(tester).keys,
            isNot(contains(detected.first.timestamp)),
          );
        });

        testWidgets('waypoint markers follow adds and removals', (
          tester,
        ) async {
          await pumpSession(tester);
          await act(tester, () => notifier.setMode(EditorMode.draw));

          await act(
            tester,
            () => notifier.addWaypoint(
              const ProfileWaypoint(timestamp: 40, depth: 20),
            ),
          );
          expect(_paintedDots(tester).keys, [40]);

          await act(
            tester,
            () => notifier.addWaypoint(
              const ProfileWaypoint(timestamp: 12, depth: 20),
            ),
          );
          expect(_paintedDots(tester).keys, [12, 40]);

          await act(tester, () => notifier.removeWaypoint(1));
          expect(_paintedDots(tester).keys, [12]);

          await act(tester, notifier.clearWaypoints);
          expect(_paintedDots(tester), isEmpty);
        });
      });
    });
  });
}
