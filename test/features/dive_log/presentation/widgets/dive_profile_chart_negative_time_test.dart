import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_selection_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A source placed on the primary's timeline before the primary started (its
/// computer was switched on first, or its clock is wrong) has negative
/// timestamps. The time axis starts at the earliest of them instead of at 0,
/// so those samples are drawn rather than clipped off the left edge (#4296).

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A 50-minute dive whose first 10 minutes fall before the primary's start.
List<DiveProfilePoint> _profile({int start = -600}) => [
  for (var t = start; t <= start + 3000; t += 5)
    DiveProfilePoint(timestamp: t, depth: 5 + 20 * ((t - start) % 1000) / 1000),
];

Widget _buildChart(
  List<DiveProfilePoint> profile, {
  List<ChartSourceOverlay>? overlays,
  void Function(List<TooltipRow>? rows)? onTooltipData,
  void Function(int seconds)? onSecondaryTapAt,
  ({int startSeconds, int endSeconds, int minSeconds, int maxSeconds})?
  rangeSelection,
}) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 500,
        child: DiveProfileChart(
          profile: profile,
          overlays: overlays,
          rangeSelection: rangeSelection,
          onRangeChanged: rangeSelection == null ? null : (_, _) {},
          tooltipPresentation: onTooltipData != null
              ? TooltipPresentation.external
              : TooltipPresentation.inChart,
          onTooltipData: onTooltipData,
          onSecondaryTapAt: onSecondaryTapAt == null
              ? null
              : (seconds, _, _) => onSecondaryTapAt(seconds),
        ),
      ),
    ),
  ),
);

LineChartData _chartData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart).first).data;

void _ignoreOverflowErrors() {
  final origOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    origOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = origOnError);
}

void main() {
  testWidgets('the axis starts at the earliest negative sample', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_buildChart(_profile()));
    await tester.pumpAndSettle();

    final data = _chartData(tester);
    expect(data.minX, -600);
    expect(data.maxX, 2400);
  });

  testWidgets('an axis with no negative sample still starts at 0', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_buildChart(_profile(start: 60)));
    await tester.pumpAndSettle();

    expect(_chartData(tester).minX, 0);
  });

  testWidgets('an overlay starting before the active source widens the axis', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(
      _buildChart(
        _profile(start: 0),
        overlays: [
          ChartSourceOverlay(
            sourceId: 'other',
            name: 'Other computer',
            computerId: null,
            points: _profile(start: -900),
            color: Colors.orange,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(_chartData(tester).minX, -900);
  });

  testWidgets('panning a zoomed chart reaches the earliest sample', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_buildChart(_profile()));
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(LineChart).first);
    for (var i = 0; i < 10; i++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pump();
    }
    final zoomed = _chartData(tester);
    expect(zoomed.maxX - zoomed.minX, lessThan(3000));

    // Drag far right, past the start of the data.
    final drag = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await drag.down(center);
    for (var i = 0; i < 20; i++) {
      await drag.moveBy(const Offset(100, 0));
      await tester.pump();
    }
    await drag.up();
    await drag.removePointer();
    await tester.pump();

    expect(_chartData(tester).minX, closeTo(-600, 1));
  });

  /// Right-clicks the plot at [fraction] of the chart's width.
  Future<void> rightClickAt(WidgetTester tester, double fraction) async {
    final rect = tester.getRect(find.byType(LineChart).first);
    final at = Offset(rect.left + rect.width * fraction, rect.center.dy);
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await mouse.addPointer(location: at);
    addTearDown(mouse.removePointer);
    await mouse.down(at);
    await tester.pump();
    await mouse.up();
    await tester.pump();
  }

  testWidgets('a plot position left of the start maps to a negative second', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    final seconds = <int>[];
    await tester.pumpWidget(
      _buildChart(_profile(), onSecondaryTapAt: seconds.add),
    );
    await tester.pumpAndSettle();

    // A seventh of the way across a -600..2400 axis; a 0-based mapping of
    // the same position reads a positive second.
    await rightClickAt(tester, 0.15);

    expect(seconds, hasLength(1));
    expect(seconds.single, inInclusiveRange(-600, -1));
  });

  testWidgets('a plot position is clamped to the active profile, not to a '
      'longer overlay', (tester) async {
    _ignoreOverflowErrors();
    final seconds = <int>[];
    await tester.pumpWidget(
      _buildChart(
        _profile(start: 0),
        overlays: [
          ChartSourceOverlay(
            sourceId: 'other',
            name: 'Other computer',
            computerId: null,
            points: _profile(start: 1200),
            color: Colors.orange,
          ),
        ],
        onSecondaryTapAt: seconds.add,
      ),
    );
    await tester.pumpAndSettle();

    // Past the active profile's last sample (3000 s) on a 0..4200 axis.
    await rightClickAt(tester, 0.97);

    expect(seconds, [3000]);
  });

  testWidgets('hovering left of the start reads a signed time', (tester) async {
    _ignoreOverflowErrors();
    List<TooltipRow>? rows;
    await tester.pumpWidget(
      _buildChart(_profile(), onTooltipData: (r) => rows = r),
    );
    await tester.pumpAndSettle();

    // A tenth of the way across the plot: about -300 s on a -600..2400 axis,
    // where a 0-based mapping would read about +300 s.
    final rect = tester.getRect(find.byType(LineChart).first);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final at = Offset(rect.left + rect.width * 0.15, rect.center.dy);
    await mouse.addPointer(location: at - const Offset(4, 0));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await mouse.moveTo(at);
    await tester.pump();

    expect(rows, isNotNull);
    final time = rows!.first.value;
    expect(time, matches(RegExp(r'^-\d+:[0-5]\d$')));
  });

  testWidgets('the mini chart starts at the earliest negative sample', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: DiveProfileMiniChart(profile: _profile()),
          ),
        ),
      ),
    );

    expect(_chartData(tester).minX, -600);
  });

  testWidgets("the range handles stop at the range state's start", (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(
      _buildChart(
        _profile(),
        rangeSelection: (
          startSeconds: -300,
          endSeconds: 1200,
          minSeconds: -600,
          maxSeconds: 2400,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final overlay = tester.widget<RangeSelectionOverlay>(
      find.byType(RangeSelectionOverlay),
    );
    expect(overlay.minSeconds, -600);
    expect(overlay.maxSeconds, 2400);
  });
}
