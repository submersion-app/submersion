import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Touch interaction model tests for the profile chart:
///  - one-finger drag scrubs at zoom 1 and pans when zoomed;
///  - two-finger pinch/pan always wins the arena (even when the first finger
///    already moved, which used to hand the gesture to fl_chart's pan);
///  - double-tap zoom is detected manually from event timestamps, so a
///    plain tap resolves instantly (no 300 ms double-tap arena hold);
///  - long-press drag still scrubs while zoomed.
///
/// Gestures are driven with explicit `timeStamp:` values because flutter_test
/// defaults every pointer event to Duration.zero, which would make any two
/// taps look simultaneous to the timestamp-based double-tap detector.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _makeProfile({
  int points = 20,
  bool temperature = false,
}) {
  return List.generate(
    points,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: (i < points / 2 ? i * 3.0 : (points - i) * 3.0),
      temperature: temperature ? 20.0 - i * 0.1 : null,
    ),
  );
}

Widget _buildChart({
  void Function(int? index)? onPointSelected,
  bool temperature = false,
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
            profile: _makeProfile(temperature: temperature),
            onPointSelected: onPointSelected,
          ),
        ),
      ),
    ),
  );
}

LineChartData _chartData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart).first).data;

double _visibleSpan(WidgetTester tester) {
  final data = _chartData(tester);
  return data.maxX - data.minX;
}

/// Mouse-wheel zoom in at the chart center (existing, already-working path)
/// used to arrange a zoomed viewport for the touch pan/scrub tests.
Future<void> _wheelZoomIn(WidgetTester tester, {int clicks = 4}) async {
  final center = tester.getCenter(find.byType(LineChart).first);
  for (var i = 0; i < clicks; i++) {
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, -100)),
    );
    await tester.pump();
  }
}

/// Ignores RenderFlex overflow noise from the zoom hint row on the small
/// 400x300 test surface.
void _ignoreOverflowErrors() {
  final origOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    origOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = origOnError);
}

void main() {
  testWidgets('fast tap-then-drag scrubs instead of panning (the reported '
      'Android bug)', (tester) async {
    final selections = <int?>[];
    await tester.pumpWidget(_buildChart(onPointSelected: selections.add));
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(LineChart).first);

    // First tap.
    final tap = await tester.createGesture();
    await tap.down(center, timeStamp: Duration.zero);
    await tap.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pump();

    // Second touch lands 100 ms later (inside the double-tap window) and
    // immediately slides: this must scrub, not arm a double-tap or pan.
    selections.clear();
    final drag = await tester.createGesture();
    await drag.down(center, timeStamp: const Duration(milliseconds: 140));
    for (var i = 1; i <= 4; i++) {
      await drag.moveBy(
        const Offset(15, 0),
        timeStamp: Duration(milliseconds: 140 + i * 16),
      );
      await tester.pump();
    }
    expect(
      selections.whereType<int>(),
      isNotEmpty,
      reason: 'the drag must scrub (select points) despite following a tap',
    );

    await drag.up(timeStamp: const Duration(milliseconds: 300));
    await tester.pump();

    final data = _chartData(tester);
    expect(data.minX, 0.0, reason: 'no pan/zoom may result from the drag');
    expect(_visibleSpan(tester), 570.0, reason: 'zoom must stay at 1x');
  });

  testWidgets('a single tap reports a selection without waiting out a '
      'double-tap window', (tester) async {
    final selections = <int?>[];
    await tester.pumpWidget(_buildChart(onPointSelected: selections.add));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byType(LineChart).first));
    // A single frame, no 300 ms wait: the tap must already have resolved.
    await tester.pump();
    expect(
      selections,
      isNotEmpty,
      reason: 'fl_chart tap events must fire as soon as the finger lifts',
    );
  });

  testWidgets('double-tap zooms in and a second double-tap resets', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_buildChart());
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(LineChart).first);
    final fullSpan = _visibleSpan(tester);

    Future<void> doubleTap(Duration base) async {
      final g1 = await tester.createGesture();
      await g1.down(center, timeStamp: base);
      await g1.up(timeStamp: base + const Duration(milliseconds: 40));
      await tester.pump();
      final g2 = await tester.createGesture();
      await g2.down(
        center,
        timeStamp: base + const Duration(milliseconds: 140),
      );
      await g2.up(timeStamp: base + const Duration(milliseconds: 180));
      await tester.pump();
    }

    await doubleTap(Duration.zero);
    expect(
      _visibleSpan(tester),
      lessThan(fullSpan),
      reason: 'double-tap must zoom in',
    );

    await doubleTap(const Duration(seconds: 2));
    expect(
      _visibleSpan(tester),
      fullSpan,
      reason: 'double-tap while zoomed must reset',
    );
  });

  testWidgets('a mouse double-click zooms too (desktop parity)', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_buildChart());
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(LineChart).first);
    final fullSpan = _visibleSpan(tester);

    final g1 = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g1.down(center, timeStamp: Duration.zero);
    await g1.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pump();
    final g2 = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g2.down(center, timeStamp: const Duration(milliseconds: 140));
    await g2.up(timeStamp: const Duration(milliseconds: 180));
    await tester.pump();

    expect(_visibleSpan(tester), lessThan(fullSpan));
  });

  testWidgets('a second tap landing on the right-axis metric selector strip '
      'does not zoom the chart', (tester) async {
    await tester.pumpWidget(_buildChart(temperature: true));
    await tester.pumpAndSettle();

    // The strip only exists when a right-axis metric is active.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == 'Change right axis metric',
      ),
      findsOneWidget,
    );

    final chartTopRight = tester.getTopRight(find.byType(LineChart).first);
    final fullSpan = _visibleSpan(tester);

    // First tap on the plot just left of the strip, second tap inside the
    // strip within the double-tap window and slop: the second tap belongs
    // to the selector (it opens the metric menu), not a chart double-tap.
    final g1 = await tester.createGesture();
    await g1.down(
      chartTopRight + const Offset(-90, 60),
      timeStamp: Duration.zero,
    );
    await g1.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pump();
    final g2 = await tester.createGesture();
    await g2.down(
      chartTopRight + const Offset(-25, 60),
      timeStamp: const Duration(milliseconds: 140),
    );
    await g2.up(timeStamp: const Duration(milliseconds: 180));
    await tester.pumpAndSettle();

    expect(
      _visibleSpan(tester),
      fullSpan,
      reason: 'a selector-strip tap must never double as a chart double-tap',
    );
  });

  testWidgets('a selector-strip tap does not seed a double-tap for a '
      'following plot tap', (tester) async {
    await tester.pumpWidget(_buildChart(temperature: true));
    await tester.pumpAndSettle();

    final chartTopRight = tester.getTopRight(find.byType(LineChart).first);
    final fullSpan = _visibleSpan(tester);

    // First tap inside the strip (opens the metric menu), second tap on the
    // plot nearby within the double-tap window: must not zoom. In the real
    // app the modal menu blocks the second tap anyway; this pins the
    // bookkeeping so the model does not depend on that.
    final g1 = await tester.createGesture();
    await g1.down(
      chartTopRight + const Offset(-25, 60),
      timeStamp: Duration.zero,
    );
    await g1.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pump();
    // Dismiss the menu the strip tap opened before tapping the plot.
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    final g2 = await tester.createGesture();
    await g2.down(
      chartTopRight + const Offset(-90, 60),
      timeStamp: const Duration(milliseconds: 140),
    );
    await g2.up(timeStamp: const Duration(milliseconds: 180));
    await tester.pump();

    expect(_visibleSpan(tester), fullSpan);
  });

  testWidgets('two slow taps do not zoom', (tester) async {
    await tester.pumpWidget(_buildChart());
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(LineChart).first);
    final fullSpan = _visibleSpan(tester);

    final g1 = await tester.createGesture();
    await g1.down(center, timeStamp: Duration.zero);
    await g1.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pump();
    // Outside kDoubleTapTimeout (300 ms).
    final g2 = await tester.createGesture();
    await g2.down(center, timeStamp: const Duration(milliseconds: 500));
    await g2.up(timeStamp: const Duration(milliseconds: 540));
    await tester.pump();

    expect(_visibleSpan(tester), fullSpan);
  });

  testWidgets('two-finger pinch zooms even when the first finger already '
      'moved (async-finger case)', (tester) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_buildChart());
    await tester.pumpAndSettle();

    final chartTopLeft = tester.getTopLeft(find.byType(LineChart).first);
    final p1Start = chartTopLeft + const Offset(120, 150);
    final p2Start = chartTopLeft + const Offset(220, 150);
    final fullSpan = _visibleSpan(tester);

    final p1 = await tester.createGesture();
    await p1.down(p1Start, timeStamp: Duration.zero);
    // First finger drifts 50 px before the second lands: fl_chart's pan
    // recognizer wins this pointer's arena (a scrub starts). The pinch must
    // still work.
    await p1.moveBy(
      const Offset(50, 0),
      timeStamp: const Duration(milliseconds: 50),
    );
    await tester.pump();

    final p2 = await tester.createGesture();
    await p2.down(p2Start, timeStamp: const Duration(milliseconds: 80));
    await tester.pump();

    // Spread: distance grows from 150 px to 270 px.
    await p1.moveBy(
      const Offset(-60, 0),
      timeStamp: const Duration(milliseconds: 120),
    );
    await p2.moveBy(
      const Offset(60, 0),
      timeStamp: const Duration(milliseconds: 120),
    );
    await tester.pump();

    expect(
      _visibleSpan(tester),
      lessThan(fullSpan),
      reason: 'the pinch must zoom in regardless of finger landing order',
    );

    await p1.up(timeStamp: const Duration(milliseconds: 200));
    await p2.up(timeStamp: const Duration(milliseconds: 200));
    await tester.pump();
  });

  testWidgets('two-finger parallel drag pans the zoomed viewport without '
      'changing zoom', (tester) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_buildChart());
    await tester.pumpAndSettle();
    await _wheelZoomIn(tester);

    final before = _chartData(tester);
    final span = before.maxX - before.minX;
    final chartTopLeft = tester.getTopLeft(find.byType(LineChart).first);

    final p1 = await tester.createGesture();
    final p2 = await tester.createGesture();
    await p1.down(
      chartTopLeft + const Offset(150, 150),
      timeStamp: Duration.zero,
    );
    await p2.down(
      chartTopLeft + const Offset(250, 150),
      timeStamp: Duration.zero,
    );
    await tester.pump();
    for (var i = 1; i <= 3; i++) {
      final t = Duration(milliseconds: i * 16);
      await p1.moveBy(const Offset(-20, 0), timeStamp: t);
      await p2.moveBy(const Offset(-20, 0), timeStamp: t);
      await tester.pump();
    }
    await p1.up(timeStamp: const Duration(milliseconds: 100));
    await p2.up(timeStamp: const Duration(milliseconds: 100));
    await tester.pump();

    final after = _chartData(tester);
    expect(
      after.minX,
      greaterThan(before.minX),
      reason: 'dragging both fingers left must pan the window right',
    );
    expect(
      (after.maxX - after.minX),
      closeTo(span, span * 0.01),
      reason: 'a parallel drag must not change the zoom level',
    );
  });

  testWidgets('one-finger drag pans when zoomed (drag to pan, as the hint '
      'promises) and does not scrub', (tester) async {
    _ignoreOverflowErrors();
    final selections = <int?>[];
    await tester.pumpWidget(_buildChart(onPointSelected: selections.add));
    await tester.pumpAndSettle();
    await _wheelZoomIn(tester);

    final before = _chartData(tester);
    selections.clear();

    final center = tester.getCenter(find.byType(LineChart).first);
    final drag = await tester.createGesture();
    await drag.down(center, timeStamp: Duration.zero);
    for (var i = 1; i <= 4; i++) {
      await drag.moveBy(
        const Offset(-15, 0),
        timeStamp: Duration(milliseconds: i * 16),
      );
      await tester.pump();
    }
    await drag.up(timeStamp: const Duration(milliseconds: 120));
    await tester.pump();

    final after = _chartData(tester);
    expect(
      after.minX,
      greaterThan(before.minX),
      reason: 'a one-finger drag on a zoomed chart must pan',
    );
    // fl_chart emits one selection at finger-down (pan-down/tap deadline)
    // before the claim wins the arena; what matters is that the claim clears
    // it and no stale scrub selection survives the pan.
    expect(
      selections.lastOrNull,
      isNull,
      reason: 'no stale scrub selection may survive a claimed pan drag',
    );
  });

  testWidgets('one-finger drag still scrubs at zoom 1', (tester) async {
    final selections = <int?>[];
    await tester.pumpWidget(_buildChart(onPointSelected: selections.add));
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(LineChart).first);
    final drag = await tester.createGesture();
    await drag.down(center, timeStamp: Duration.zero);
    for (var i = 1; i <= 4; i++) {
      await drag.moveBy(
        const Offset(15, 0),
        timeStamp: Duration(milliseconds: i * 16),
      );
      await tester.pump();
    }
    await drag.up(timeStamp: const Duration(milliseconds: 120));
    await tester.pump();

    expect(selections.whereType<int>(), isNotEmpty);
    expect(_chartData(tester).minX, 0.0);
  });

  testWidgets('long-press drag scrubs while zoomed instead of panning', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    final selections = <int?>[];
    await tester.pumpWidget(_buildChart(onPointSelected: selections.add));
    await tester.pumpAndSettle();
    await _wheelZoomIn(tester);

    final before = _chartData(tester);
    selections.clear();

    final center = tester.getCenter(find.byType(LineChart).first);
    final press = await tester.createGesture();
    await press.down(center, timeStamp: Duration.zero);
    // Hold past the long-press timeout: fl_chart's long-press recognizer
    // takes the arena before our claim recognizer sees any movement.
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 1; i <= 4; i++) {
      await press.moveBy(
        const Offset(15, 0),
        timeStamp: Duration(milliseconds: 600 + i * 16),
      );
      await tester.pump();
    }
    await press.up(timeStamp: const Duration(milliseconds: 800));
    await tester.pump();

    expect(
      selections.whereType<int>(),
      isNotEmpty,
      reason: 'a long-press drag must keep scrubbing while zoomed',
    );
    expect(
      _chartData(tester).minX,
      before.minX,
      reason: 'the long-press scrub must not pan the viewport',
    );
  });
}
