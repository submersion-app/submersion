import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_marker_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_overlay.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Annotations on the dive profile (#4109): solid amber lines that never
/// lose to a computer event or to a neighbour, dots on the curve, and a tap
/// on a dot that reports the annotation.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.settings = const AppSettings()]);

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _profile() => List.generate(41, (i) {
  final t = i * 30;
  final double depth;
  if (t < 180) {
    depth = 30.0 * t / 180;
  } else if (t < 900) {
    depth = 30;
  } else if (t < 1110) {
    depth = 30.0 * (1110 - t) / 210;
  } else {
    depth = 4;
  }
  return DiveProfilePoint(timestamp: t, depth: depth);
});

ProfileEvent _ann(String id, int t, [String words = 'felt sick']) =>
    ProfileEvent.annotation(
      id: id,
      diveId: 'd1',
      timestamp: t,
      words: words,
      createdAt: DateTime(2026),
    );

ProfileEvent _warning(int t) => ProfileEvent(
  id: 'w$t',
  diveId: 'd1',
  timestamp: t,
  eventType: ProfileEventType.ascentRateWarning,
  severity: EventSeverity.warning,
  createdAt: DateTime(2026),
);

final _containers = <ProviderContainer>[];

Widget _chart(
  List<ProfileEvent> events, {
  List<DiveProfilePoint>? profile,
  void Function(ProfileEvent, Offset)? onAnnotationTap,
  String? focusedAnnotationId,
  AppSettings settings = const AppSettings(),
  void Function(int?)? onPointSelected,
  List<PhotoChartMarker>? photoMarkers,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 300,
        child: Consumer(
          builder: (context, ref, _) {
            _containers.add(ProviderScope.containerOf(context));
            return DiveProfileChart(
              profile: profile ?? _profile(),
              events: events,
              onAnnotationTap: onAnnotationTap,
              focusedAnnotationId: focusedAnnotationId,
              onPointSelected: onPointSelected,
              photoMarkers: photoMarkers,
            );
          },
        ),
      ),
    ),
  ),
);

AnnotationMarkerLayer _layer(WidgetTester tester) =>
    tester.widget<AnnotationMarkerLayer>(find.byType(AnnotationMarkerLayer));

/// Where the only annotation's dot sits on screen, or null when it is off.
Offset? _dot(WidgetTester tester) {
  final layerFinder = find.byType(AnnotationMarkerLayer);
  final layer = _layer(tester);
  final center = annotationDotCenters(
    annotations: layer.annotations,
    size: tester.getSize(layerFinder),
    insets: layer.insets,
    visibleMinSeconds: layer.visibleMinSeconds,
    visibleMaxSeconds: layer.visibleMaxSeconds,
    visibleMinDepth: layer.visibleMinDepth,
    visibleMaxDepth: layer.visibleMaxDepth,
    depthAt: layer.depthAt,
  ).single;
  return center == null ? null : tester.getTopLeft(layerFinder) + center;
}

/// Wheel-zooms in about the plot's left end, far from a late annotation.
Future<void> _zoomLeft(WidgetTester tester) async {
  final plot = tester.getRect(find.byType(LineChart).first);
  for (var i = 0; i < 6; i++) {
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: plot.centerLeft + const Offset(40, 0),
        scrollDelta: const Offset(0, -100),
      ),
    );
    await tester.pump();
  }
}

List<VerticalLine> _lines(WidgetTester tester) => tester
    .widget<LineChart>(find.byType(LineChart).first)
    .data
    .extraLinesData
    .verticalLines
    .where(
      (l) => l.dashArray != null || l.color == ProfileMetricColors.annotation,
    )
    .toList();

List<VerticalLine> _annotationLines(WidgetTester tester) => _lines(
  tester,
).where((l) => l.color == ProfileMetricColors.annotation).toList();

void main() {
  setUp(_containers.clear);

  testWidgets(
    'two annotations three seconds apart both draw, solid and amber',
    (tester) async {
      await tester.pumpWidget(_chart([_ann('a', 1000), _ann('b', 1003)]));
      await tester.pumpAndSettle();
      final lines = _annotationLines(tester);
      expect(lines.map((l) => l.x), [1000.0, 1003.0]);
      for (final l in lines) {
        expect(l.dashArray, isNull);
        expect(l.strokeWidth, 1.5);
      }
    },
  );

  testWidgets(
    'an annotation at a warning\'s second survives the severity rule',
    (tester) async {
      await tester.pumpWidget(_chart([_warning(900), _ann('a', 900)]));
      await tester.pumpAndSettle();
      expect(_lines(tester), hasLength(2));
      expect(_annotationLines(tester), hasLength(1));
    },
  );

  testWidgets('the annotation line carries the words as its label', (
    tester,
  ) async {
    await tester.pumpWidget(_chart([_ann('a', 600, 'Octo free-flow')]));
    await tester.pumpAndSettle();
    final line = _annotationLines(tester).single;
    expect(line.label.labelResolver(line), 'Octo free-flow');
  });

  testWidgets('annotations draw while events are hidden', (tester) async {
    await tester.pumpWidget(_chart([_warning(300), _ann('a', 600)]));
    await tester.pumpAndSettle();
    expect(_lines(tester), hasLength(2));

    _containers.first.read(profileLegendProvider.notifier).toggleEvents();
    await tester.pumpAndSettle();
    final lines = _lines(tester);
    expect(lines, hasLength(1));
    expect(lines.single.color, ProfileMetricColors.annotation);
  });

  testWidgets('the annotations toggle hides the markers and the dots', (
    tester,
  ) async {
    await tester.pumpWidget(_chart([_warning(300), _ann('a', 600)]));
    await tester.pumpAndSettle();
    expect(_annotationLines(tester), hasLength(1));
    expect(find.byType(AnnotationMarkerLayer), findsOneWidget);

    _containers.first.read(profileLegendProvider.notifier).toggleAnnotations();
    await tester.pumpAndSettle();
    expect(_annotationLines(tester), isEmpty);
    expect(find.byType(AnnotationMarkerLayer), findsNothing);
    expect(_lines(tester), hasLength(1), reason: 'the warning stays');
  });

  testWidgets('a two-finger gesture ending on the dot opens nothing', (
    tester,
  ) async {
    final taps = <ProfileEvent>[];
    await tester.pumpWidget(
      _chart([_ann('a', 600)], onAnnotationTap: (a, _) => taps.add(a)),
    );
    await tester.pumpAndSettle();
    final dot = _dot(tester)!;

    final first = await tester.startGesture(dot, pointer: 1);
    final second = await tester.startGesture(
      dot + const Offset(5, 0),
      pointer: 2,
    );
    await tester.pump();
    await second.up();
    await first.up();
    await tester.pump();

    expect(taps, isEmpty);
  });

  testWidgets('focusing an annotation outside a zoomed window pans the plot '
      'to it and opens at its dot', (tester) async {
    final taps = <(ProfileEvent, Offset)>[];
    void onTap(ProfileEvent a, Offset at) => taps.add((a, at));
    final events = [_ann('a', 1100)];
    await tester.pumpWidget(_chart(events, onAnnotationTap: onTap));
    await tester.pumpAndSettle();
    await _zoomLeft(tester);
    expect(_layer(tester).visibleMaxSeconds, lessThan(1100));
    expect(_dot(tester), isNull);

    await tester.pumpWidget(
      _chart(events, onAnnotationTap: onTap, focusedAnnotationId: 'a'),
    );
    await tester.pumpAndSettle();

    final layer = _layer(tester);
    expect(layer.visibleMinSeconds, lessThan(1100));
    expect(layer.visibleMaxSeconds, greaterThan(1100));
    expect(taps.single.$1.id, 'a');
    expect(taps.single.$2, offsetMoreOrLessEquals(_dot(tester)!));
  });

  testWidgets('focusing an annotation at a visible time but an off-window '
      'depth pans to it too', (tester) async {
    final taps = <(ProfileEvent, Offset)>[];
    void onTap(ProfileEvent a, Offset at) => taps.add((a, at));
    // Shallow at the top-left of a zoom, deep a little later in the window.
    final events = [_ann('a', 240)];
    await tester.pumpWidget(_chart(events, onAnnotationTap: onTap));
    await tester.pumpAndSettle();
    final plot = tester.getRect(find.byType(LineChart).first);
    for (var i = 0; i < 6; i++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: plot.topLeft + const Offset(60, 20),
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pump();
    }
    final zoomed = _layer(tester);
    expect(zoomed.visibleMaxSeconds, greaterThan(240));
    expect(zoomed.depthAt(240), greaterThan(zoomed.visibleMaxDepth));

    await tester.pumpWidget(
      _chart(events, onAnnotationTap: onTap, focusedAnnotationId: 'a'),
    );
    await tester.pumpAndSettle();

    final layer = _layer(tester);
    expect(layer.depthAt(240), lessThan(layer.visibleMaxDepth));
    expect(taps.single.$2, offsetMoreOrLessEquals(_dot(tester)!));
  });

  testWidgets('the pan finds the depth in the diver\'s units', (tester) async {
    const feet = AppSettings(depthUnit: DepthUnit.feet);
    final events = [_ann('a', 800)];
    await tester.pumpWidget(_chart(events, settings: feet));
    await tester.pumpAndSettle();
    await _zoomLeft(tester);
    expect(_dot(tester), isNull);

    await tester.pumpWidget(
      _chart(events, settings: feet, focusedAnnotationId: 'a'),
    );
    await tester.pumpAndSettle();

    final layer = _layer(tester);
    final depth = layer.depthAt(800)!;
    expect(depth, greaterThan(layer.visibleMinDepth));
    expect(depth, lessThan(layer.visibleMaxDepth));
  });

  testWidgets('focusing an annotation no pan can reach still opens it once', (
    tester,
  ) async {
    final taps = <ProfileEvent>[];
    void onTap(ProfileEvent a, Offset _) => taps.add(a);
    final events = [_ann('a', 5000)];
    await tester.pumpWidget(_chart(events, onAnnotationTap: onTap));
    await tester.pumpAndSettle();
    await _zoomLeft(tester);

    await tester.pumpWidget(
      _chart(events, onAnnotationTap: onTap, focusedAnnotationId: 'a'),
    );
    await tester.pumpAndSettle();

    expect(taps.map((a) => a.id), ['a']);
  });

  testWidgets('tapping the dot reports the annotation', (tester) async {
    final taps = <ProfileEvent>[];
    await tester.pumpWidget(
      _chart([_ann('a', 600)], onAnnotationTap: (a, _) => taps.add(a)),
    );
    await tester.pumpAndSettle();
    final layerFinder = find.byType(AnnotationMarkerLayer);
    final layer = tester.widget<AnnotationMarkerLayer>(layerFinder);
    final centers = annotationDotCenters(
      annotations: layer.annotations,
      size: tester.getSize(layerFinder),
      insets: layer.insets,
      visibleMinSeconds: layer.visibleMinSeconds,
      visibleMaxSeconds: layer.visibleMaxSeconds,
      visibleMinDepth: layer.visibleMinDepth,
      visibleMaxDepth: layer.visibleMaxDepth,
      depthAt: layer.depthAt,
    );
    final dot = centers.single!;
    await tester.tapAt(tester.getTopLeft(layerFinder) + dot);
    await tester.pump();
    expect(taps.map((a) => a.id), ['a']);

    // Far from the dot nothing is reported.
    await tester.tapAt(
      tester.getTopLeft(layerFinder) + dot + const Offset(60, 0),
    );
    await tester.pump();
    expect(taps, hasLength(1));
  });

  testWidgets('a touch far from a dot still reaches the chart below', (
    tester,
  ) async {
    final points = <int?>[];
    await tester.pumpWidget(
      _chart([_ann('a', 600)], onPointSelected: points.add),
    );
    await tester.pumpAndSettle();
    final plot = tester.getRect(find.byType(LineChart).first);

    // Only fl_chart answers a touch; the hover fallback on the Listener
    // around the stack is for a mouse, so it cannot hide a blocked pointer.
    await tester.tapAt(Offset(plot.left + 60, plot.center.dy));
    await tester.pump(const Duration(milliseconds: 400));

    expect(points, isNotEmpty);
  });

  testWidgets('a photo chip over a dot takes the tap', (tester) async {
    final taps = <ProfileEvent>[];
    final at = DateTime.utc(2026);
    await tester.pumpWidget(
      _chart(
        [_ann('a', 600)],
        onAnnotationTap: (a, _) => taps.add(a),
        photoMarkers: [
          PhotoChartMarker(
            item: MediaItem(
              id: 'p1',
              diveId: 'd1',
              mediaType: MediaType.photo,
              takenAt: at,
              createdAt: at,
              updatedAt: at,
            ),
            elapsedSeconds: 600,
            depthMeters: 30,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(
        find.descendant(
          of: find.byType(PhotoMarkerOverlay),
          matching: find.byType(Icon),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('photoMarkerCard')), findsOneWidget);
    expect(taps, isEmpty);
  });

  testWidgets('annotations alone offer no Events toggle', (tester) async {
    await tester.pumpWidget(_chart([_ann('a', 600)]));
    await tester.pumpAndSettle();
    final config = tester
        .widget<DiveProfileLegend>(find.byType(DiveProfileLegend))
        .config;
    expect(config.hasEvents, isFalse);
    expect(config.hasAnnotations, isTrue);
  });

  testWidgets('a computer event beside an annotation keeps the Events toggle', (
    tester,
  ) async {
    await tester.pumpWidget(_chart([_ann('a', 600), _warning(300)]));
    await tester.pumpAndSettle();
    final config = tester
        .widget<DiveProfileLegend>(find.byType(DiveProfileLegend))
        .config;
    expect(config.hasEvents, isTrue);
  });

  test('nearestAnnotationIndex picks the closest dot inside the radius', () {
    const centers = [Offset(10, 10), Offset(50, 10), null, Offset(100, 10)];
    expect(nearestAnnotationIndex(centers, const Offset(45, 12)), 1);
    expect(nearestAnnotationIndex(centers, const Offset(12, 10)), 0);
    expect(nearestAnnotationIndex(centers, const Offset(75, 10)), isNull);
    expect(
      nearestAnnotationIndex(centers, const Offset(74, 10), radius: 30),
      1,
    );
  });

  testWidgets('a right-click on a dot leaves the moment to the chart', (
    tester,
  ) async {
    final tapped = <String>[];
    final secondary = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
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
                profile: _profile(),
                events: [_ann('a', 600)],
                onAnnotationTap: (a, _) => tapped.add(a.id),
                onSecondaryTapAt: (seconds, _, _) => secondary.add(seconds),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final dot = _dot(tester)!;

    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await mouse.addPointer(location: dot);
    addTearDown(mouse.removePointer);
    await mouse.down(dot);
    await tester.pump();
    await mouse.up();
    await tester.pump();

    expect(secondary, hasLength(1));
    expect(tapped, isEmpty);
  });

  testWidgets(
    'an annotation\'s label reads in the surface\'s own text colour',
    (tester) async {
      await tester.pumpWidget(_chart([_ann('a', 600), _warning(300)]));
      await tester.pump();

      final lines = tester
          .widget<LineChart>(find.byType(LineChart).first)
          .data
          .extraLinesData
          .verticalLines;
      final annotation = lines.firstWhere((l) => l.x == 600);
      final warning = lines.firstWhere((l) => l.x == 300);
      final onSurface = Theme.of(
        tester.element(find.byType(DiveProfileChart)),
      ).colorScheme.onSurface;
      expect(annotation.label.style?.color, onSurface);
      expect(annotation.color, ProfileMetricColors.annotation);
      expect(warning.label.style?.color, isNot(onSurface));
    },
  );
}
