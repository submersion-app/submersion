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
  void Function(int timestamp, double depth)? onTap,
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
            onTap: onTap,
          ),
        ),
      ),
    ),
  );
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
