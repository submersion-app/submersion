import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_editor_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

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
  EditorMode mode = EditorMode.select,
  List<OutlierResult>? outliers,
  List<ProfileWaypoint>? waypoints,
}) {
  final points = profile ?? _makeProfile();
  return ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
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
          ),
        ),
      ),
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
  group('ProfileEditorChart markers (issue #3867)', () {
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

    testWidgets('paint skips the dot walk when a mode has nothing to mark', (
      tester,
    ) async {
      Future<bool> dotsShownIn(
        EditorMode mode, {
        List<OutlierResult>? outliers,
      }) async {
        await tester.pumpWidget(
          _buildChart(mode: mode, outliers: outliers, waypoints: waypoints),
        );
        await tester.pumpAndSettle();
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        return chart.data.lineBarsData[1].dotData.show;
      }

      expect(await dotsShownIn(EditorMode.select), isFalse);
      expect(await dotsShownIn(EditorMode.smooth), isFalse);
      expect(await dotsShownIn(EditorMode.trim), isFalse);
      expect(await dotsShownIn(EditorMode.outlier), isFalse);
      expect(
        await dotsShownIn(EditorMode.outlier, outliers: const []),
        isFalse,
      );
      expect(await dotsShownIn(EditorMode.outlier, outliers: outliers), isTrue);
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

      expect(flagged.reads, lessThanOrEqualTo(profile.length + flagged.length));

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
        _buildChart(profile: profile, mode: EditorMode.draw, waypoints: placed),
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

      testWidgets('waypoint markers follow adds and removals', (tester) async {
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
}
