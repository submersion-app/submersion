import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/profile_zoom_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Time only zoom (issue #5069): every zoom input scales the time axis and
/// leaves depth running from the surface to the deepest point.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A 50-minute W-shaped dive, 5 s samples, 5 to 30 m.
List<DiveProfilePoint> _profile() => List.generate(600, (i) {
  final phase = (i % 200) / 200.0;
  return DiveProfilePoint(
    timestamp: i * 5,
    depth: 5 + 25 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2),
  );
});

Widget _chart({required bool timeOnly}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith(
      (ref) =>
          _TestSettingsNotifier(AppSettings(profileZoomTimeOnly: timeOnly)),
    ),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 500,
        child: DiveProfileChart(profile: _profile()),
      ),
    ),
  ),
);

LineChartData _data(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart).first).data;

double _timeSpan(WidgetTester tester) =>
    _data(tester).maxX - _data(tester).minX;

double _depthSpan(WidgetTester tester) =>
    _data(tester).maxY - _data(tester).minY;

Offset _plotCenter(WidgetTester tester) =>
    tester.getCenter(find.byType(LineChart).first);

Future<void> _wheelIn(WidgetTester tester, int clicks) async {
  for (var i = 0; i < clicks; i++) {
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: _plotCenter(tester),
        scrollDelta: const Offset(0, -100),
      ),
    );
    await tester.pump();
  }
}

void _ignoreOverflowErrors() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  testWidgets('wheel zoom in Time only keeps the full depth window', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_chart(timeOnly: true));
    await tester.pumpAndSettle();
    final fullTime = _timeSpan(tester);
    final fullDepth = _depthSpan(tester);
    final fullMinY = _data(tester).minY;

    await _wheelIn(tester, 10);

    expect(_timeSpan(tester), lessThan(fullTime / 2));
    expect(_depthSpan(tester), closeTo(fullDepth, 1e-9));
    expect(_data(tester).minY, closeTo(fullMinY, 1e-9));
  });

  testWidgets('the zoom-in button in Time only scales time only', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_chart(timeOnly: true));
    await tester.pumpAndSettle();
    final fullTime = _timeSpan(tester);
    final fullDepth = _depthSpan(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(_timeSpan(tester), lessThan(fullTime));
    expect(_depthSpan(tester), closeTo(fullDepth, 1e-9));
  });

  testWidgets('double-tap in Time only zooms time only', (tester) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_chart(timeOnly: true));
    await tester.pumpAndSettle();
    final fullTime = _timeSpan(tester);
    final fullDepth = _depthSpan(tester);

    final center = _plotCenter(tester);
    final g1 = await tester.createGesture();
    await g1.down(center, timeStamp: Duration.zero);
    await g1.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pump();
    final g2 = await tester.createGesture();
    await g2.down(center, timeStamp: const Duration(milliseconds: 140));
    await g2.up(timeStamp: const Duration(milliseconds: 180));
    await tester.pump();

    expect(_timeSpan(tester), lessThan(fullTime));
    expect(_depthSpan(tester), closeTo(fullDepth, 1e-9));
  });

  testWidgets('trackpad zoom in Time only keeps the full depth window', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_chart(timeOnly: true));
    await tester.pumpAndSettle();
    final fullTime = _timeSpan(tester);
    final fullDepth = _depthSpan(tester);

    // Several updates with a pump between each: a remount mid-gesture would
    // drop the later ones (#2350).
    final pad = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await pad.panZoomStart(_plotCenter(tester));
    for (var i = 1; i <= 5; i++) {
      await pad.panZoomUpdate(_plotCenter(tester), scale: 1 + 0.3 * i);
      await tester.pump();
    }
    await pad.panZoomEnd();
    await tester.pump();

    expect(_timeSpan(tester), lessThan(fullTime / 2));
    expect(_depthSpan(tester), closeTo(fullDepth, 1e-9));
  });

  testWidgets('a vertical mouse drag in Time only does not move depth', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_chart(timeOnly: true));
    await tester.pumpAndSettle();
    await _wheelIn(tester, 10);
    final minY = _data(tester).minY;
    final maxY = _data(tester).maxY;

    final drag = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await drag.down(_plotCenter(tester));
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await drag.up();
    await tester.pump();

    expect(_data(tester).minY, closeTo(minY, 1e-9));
    expect(_data(tester).maxY, closeTo(maxY, 1e-9));
  });

  testWidgets('switching to Time only while zoomed snaps depth to full and '
      'keeps the time window', (tester) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_chart(timeOnly: false));
    await tester.pumpAndSettle();
    final fullDepth = _depthSpan(tester);
    await _wheelIn(tester, 10);
    expect(_depthSpan(tester), lessThan(fullDepth));
    final minX = _data(tester).minX;
    final maxX = _data(tester).maxX;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveProfileChart)),
    );
    container
        .read(profileLegendProvider.notifier)
        .setZoomMode(ProfileZoomMode.timeOnly);
    await tester.pumpAndSettle();

    expect(_depthSpan(tester), closeTo(fullDepth, 1e-9));
    expect(_data(tester).minX, closeTo(minX, 1e-6));
    expect(_data(tester).maxX, closeTo(maxX, 1e-6));
  });

  testWidgets('a both-axes zoom still scales depth', (tester) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_chart(timeOnly: false));
    await tester.pumpAndSettle();
    final fullDepth = _depthSpan(tester);

    await _wheelIn(tester, 10);

    expect(_depthSpan(tester), lessThan(fullDepth / 2));
  });
}
