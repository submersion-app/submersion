import 'dart:collection';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/presentation/widgets/chart_zoom_controls.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_cursor_tooltip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What a pointer frame rebuilds.
///
/// Pan, zoom and hover all fire once per pointer frame. Only the plot reads
/// the state they change, so they must rebuild only the plot: the legend, the
/// zoom hint and the per-build profile scans stay put. Each legend check here
/// reads the widget instance, since the chart's build makes a new one and so
/// an identical instance proves that build did not run.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.settings = const AppSettings()]);

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _profile() => List.generate(600, (i) {
  final phase = (i % 200) / 200.0;
  return DiveProfilePoint(
    timestamp: i * 5,
    depth: 5 + 25 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2),
    temperature: 20.0 - i * 0.005,
    heartRate: 70 + i % 20,
  );
});

/// A profile that counts how many samples are read from it.
class _CountingProfile extends ListBase<DiveProfilePoint> {
  _CountingProfile(this._points);

  final List<DiveProfilePoint> _points;
  int reads = 0;

  @override
  int get length => _points.length;

  @override
  set length(int value) => throw UnsupportedError('read only');

  @override
  DiveProfilePoint operator [](int index) {
    reads++;
    return _points[index];
  }

  @override
  void operator []=(int index, DiveProfilePoint value) =>
      throw UnsupportedError('read only');
}

Widget _buildChart({
  List<DiveProfilePoint>? profile,
  GlobalKey? exportKey,
  double width = 800,
  AppSettings settings = const AppSettings(),
  List<double>? ppO2Curve,
  List<double>? sacCurve,
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: 500,
            child: DiveProfileChart(
              profile: profile ?? _profile(),
              exportKey: exportKey,
              ppO2Curve: ppO2Curve,
              sacCurve: sacCurve,
              tooltipPresentation: TooltipPresentation.inChart,
            ),
          ),
        ),
      ),
    ),
  );
}

LineChartData _chartData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart).first).data;

DiveProfileLegend _legend(WidgetTester tester) =>
    tester.widget<DiveProfileLegend>(find.byType(DiveProfileLegend));

Offset _chartCenter(WidgetTester tester) =>
    tester.getCenter(find.byType(LineChart).first);

Future<void> _wheelZoom(
  WidgetTester tester, {
  required int clicks,
  double scrollDy = -100,
}) async {
  for (var i = 0; i < clicks; i++) {
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: _chartCenter(tester),
        scrollDelta: Offset(0, scrollDy),
      ),
    );
    await tester.pump();
  }
}

void main() {
  group('a pointer frame rebuilds only the plot', () {
    testWidgets('mouse drag pan', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();
      await _wheelZoom(tester, clicks: 10);

      final legend = _legend(tester);
      final minX = _chartData(tester).minX;
      final drag = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(drag.removePointer);
      await drag.down(_chartCenter(tester));
      for (var i = 0; i < 10; i++) {
        await drag.moveBy(const Offset(-12, 0));
        await tester.pump();
        expect(_legend(tester), same(legend));
      }
      await drag.up();
      await tester.pump();

      expect(_chartData(tester).minX, greaterThan(minX));
    });

    testWidgets('one-finger touch pan', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();
      await _wheelZoom(tester, clicks: 10);

      final legend = _legend(tester);
      final minX = _chartData(tester).minX;
      final drag = await tester.createGesture(kind: PointerDeviceKind.touch);
      await drag.down(_chartCenter(tester));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await drag.moveBy(const Offset(-12, 0));
        await tester.pump();
        expect(_legend(tester), same(legend));
      }
      await drag.up();
      await tester.pump();

      expect(_chartData(tester).minX, greaterThan(minX));
    });

    testWidgets('wheel zoom', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      final legend = _legend(tester);
      final width = _chartData(tester).maxX - _chartData(tester).minX;
      await _wheelZoom(tester, clicks: 6);

      expect(_legend(tester), same(legend));
      expect(
        _chartData(tester).maxX - _chartData(tester).minX,
        lessThan(width),
      );
    });

    testWidgets('trackpad pinch', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      final legend = _legend(tester);
      final width = _chartData(tester).maxX - _chartData(tester).minX;
      final pinch = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await pinch.panZoomStart(_chartCenter(tester));
      for (var i = 1; i <= 6; i++) {
        await pinch.panZoomUpdate(_chartCenter(tester), scale: 1 + i * 0.2);
        await tester.pump();
        expect(_legend(tester), same(legend));
      }
      await pinch.panZoomEnd();
      await tester.pump();

      expect(
        _chartData(tester).maxX - _chartData(tester).minX,
        lessThan(width),
      );
    });

    testWidgets('a pan frame does not rescan the profile', (tester) async {
      final profile = _CountingProfile(_profile());
      await tester.pumpWidget(_buildChart(profile: profile));
      await tester.pumpAndSettle();
      await _wheelZoom(tester, clicks: 10);

      final drag = await tester.createGesture(kind: PointerDeviceKind.touch);
      await drag.down(_chartCenter(tester));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await drag.moveBy(const Offset(-8, 0));
        await tester.pump();
      }

      // Past the slop the pan is claimed, and these frames stay inside one
      // decimation bucket: nothing is left that needs every sample.
      profile.reads = 0;
      for (var i = 0; i < 6; i++) {
        await drag.moveBy(const Offset(-1, 0));
        await tester.pump();
      }
      await drag.up();
      await tester.pump();

      expect(profile.reads, lessThan(profile.length));
    });

    testWidgets('a pan held against the edge does not rebuild it', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();
      await _wheelZoom(tester, clicks: 10);

      final drag = await tester.createGesture(kind: PointerDeviceKind.touch);
      await drag.down(_chartCenter(tester));
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await drag.moveBy(const Offset(120, 0));
        await tester.pump();
      }
      expect(_chartData(tester).minX, 0);

      final plot = tester.widget<LineChart>(find.byType(LineChart).first);
      for (var i = 0; i < 3; i++) {
        await drag.moveBy(const Offset(40, 0));
        await tester.pump();
        expect(
          tester.widget<LineChart>(find.byType(LineChart).first),
          same(plot),
        );
      }
      await drag.up();
      await tester.pump();
    });

    testWidgets('mouse hover', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: _chartCenter(tester));
      await tester.pump();
      await mouse.moveBy(const Offset(4, 0));
      await tester.pump();

      final legend = _legend(tester);
      final cursor = tester
          .widget<ProfileCursorTooltip>(find.byType(ProfileCursorTooltip))
          .cursorLocal;
      for (var i = 0; i < 5; i++) {
        await mouse.moveBy(const Offset(10, 0));
        await tester.pump();
        expect(_legend(tester), same(legend));
      }

      expect(
        tester
            .widget<ProfileCursorTooltip>(find.byType(ProfileCursorTooltip))
            .cursorLocal
            .dx,
        cursor.dx + 50,
      );
    });
  });

  group('what sits outside the plot still follows the zoom', () {
    String zoomLabel(WidgetTester tester) {
      final controls = find.byType(ChartZoomControls);
      final text = tester.widget<Text>(
        find.descendant(of: controls, matching: find.textContaining('x')),
      );
      return text.data!;
    }

    testWidgets('the zoom level readout', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();
      expect(zoomLabel(tester), '1.0x');

      await _wheelZoom(tester, clicks: 8);

      expect(zoomLabel(tester), '2.1x');
    });

    testWidgets('the zoom buttons', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.fit_screen), findsNothing);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(zoomLabel(tester), '1.5x');
      expect(find.byIcon(Icons.fit_screen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.fit_screen));
      await tester.pump();
      expect(zoomLabel(tester), '1.0x');
      expect(_chartData(tester).minX, 0);
    });

    testWidgets('the zoom hint', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();
      expect(find.textContaining('Zoom:'), findsNothing);

      await _wheelZoom(tester, clicks: 8);
      expect(find.textContaining('Zoom: 2.1x'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.fit_screen));
      await tester.pump();
      expect(find.textContaining('Zoom:'), findsNothing);
    });

    testWidgets('the tooltip headroom when the reset button wraps the legend', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrappingLegendChart());
      await tester.pumpAndSettle();
      final unzoomed = tester.getSize(find.byType(DiveProfileLegend)).height;

      await _wheelZoom(tester, clicks: 2);
      await tester.pump();
      final zoomed = tester.getSize(find.byType(DiveProfileLegend)).height;
      expect(zoomed, greaterThan(unzoomed), reason: 'the legend must wrap');

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: _chartCenter(tester));
      await tester.pump();
      await mouse.moveBy(const Offset(4, 0));
      await tester.pump();

      expect(
        tester
            .widget<ProfileCursorTooltip>(find.byType(ProfileCursorTooltip))
            .extraHeadroomAbove,
        tester.getSize(find.byType(DiveProfileLegend)).height,
      );
    });
  });

  group('what a pan frame skips still follows the data', () {
    List<double> rightAxisTicks(WidgetTester tester) => [
      for (final title in tester.widgetList<SideTitleWidget>(
        find.byType(SideTitleWidget),
      ))
        if (title.meta.axisSide == AxisSide.right)
          double.parse((title.child as Text).data!),
    ];

    testWidgets('the right axis rescales for a new profile', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();
      expect(
        rightAxisTicks(tester).reduce((a, b) => a > b ? a : b),
        lessThan(25),
      );

      final warmer = [
        for (final point in _profile())
          DiveProfilePoint(
            timestamp: point.timestamp,
            depth: point.depth,
            temperature: point.temperature! + 15,
          ),
      ];
      await tester.pumpWidget(_buildChart(profile: warmer));
      await tester.pumpAndSettle();

      expect(
        rightAxisTicks(tester).reduce((a, b) => a > b ? a : b),
        greaterThan(30),
      );
    });
  });

  test('only the chart build watches providers', () {
    // A plot-only rebuild does not run the consumer's build(), the one place
    // old watches are dropped, and each select() is a new key: a watch below
    // build() adds a subscription per frame, which slowed panning and leaked
    // until the next full rebuild. Reads stay fresh because build() watches.
    final source = File(
      p.join(
        'lib',
        'features',
        'dive_log',
        'presentation',
        'widgets',
        'dive_profile_chart.dart',
      ),
    ).readAsStringSync();
    final buildStart = source.indexOf('Widget build(BuildContext context) {');
    final buildEnd = source.indexOf('  /// Stacks the zoom hint behind [plot]');
    expect(buildStart, isNot(-1));
    expect(buildEnd, greaterThan(buildStart));

    final codeBeforeBuild = source.substring(0, buildStart);
    final codeAfterBuild = source.substring(buildEnd);
    expect(codeBeforeBuild, isNot(contains('ref.watch(')));
    expect(codeAfterBuild, isNot(contains('ref.watch(')));
  });

  group('the plot repaints on its own layer', () {
    bool plotHasOwnLayer(WidgetTester tester) {
      var ancestor = tester
          .renderObject<RenderObject>(find.byType(LineChart).first)
          .parent;
      final chart = tester.renderObject<RenderObject>(
        find.byType(DiveProfileChart),
      );
      while (ancestor != null && ancestor != chart) {
        if (ancestor.isRepaintBoundary) return true;
        ancestor = ancestor.parent;
      }
      return false;
    }

    testWidgets('with no export key', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      expect(plotHasOwnLayer(tester), isTrue);
    });

    testWidgets('with an export key, which names that same boundary', (
      tester,
    ) async {
      final exportKey = GlobalKey();
      await tester.pumpWidget(_buildChart(exportKey: exportKey));
      await tester.pumpAndSettle();

      expect(plotHasOwnLayer(tester), isTrue);
      expect(
        exportKey.currentContext!.findRenderObject(),
        isA<RenderRepaintBoundary>(),
      );
    });
  });
}

/// Doubled text, at a width that fits the legend's entries on one row at 1x
/// but not beside the reset button that appears once zoomed. At normal text
/// sizes the zoom buttons are taller than two rows of entries, so wrapping
/// leaves the legend's height alone.
Widget _wrappingLegendChart() => _buildChart(
  width: 1085,
  settings: const AppSettings(
    defaultShowHeartRate: true,
    defaultShowSac: true,
    defaultShowPpO2: true,
  ),
  ppO2Curve: List.filled(600, 1.2),
  sacCurve: List.filled(600, 15.0),
  textScale: 2,
);
