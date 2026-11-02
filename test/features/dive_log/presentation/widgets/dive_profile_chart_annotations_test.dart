import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_marker_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Annotations on the dive profile (#4109): solid amber lines that never
/// lose to a computer event or to a neighbour, dots on the curve, and a tap
/// on a dot that reports the annotation.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

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
  bool showAnnotations = true,
  List<DiveProfilePoint>? profile,
  void Function(ProfileEvent, Offset)? onAnnotationTap,
}) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
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
              showAnnotations: showAnnotations,
              onAnnotationTap: onAnnotationTap,
            );
          },
        ),
      ),
    ),
  ),
);

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
    final layerFinder = find.byType(AnnotationMarkerLayer);
    final layer = tester.widget<AnnotationMarkerLayer>(layerFinder);
    final dot =
        tester.getTopLeft(layerFinder) +
        annotationDotCenters(
          annotations: layer.annotations,
          size: tester.getSize(layerFinder),
          insets: layer.insets,
          visibleMinSeconds: layer.visibleMinSeconds,
          visibleMaxSeconds: layer.visibleMaxSeconds,
          visibleMinDepth: layer.visibleMinDepth,
          visibleMaxDepth: layer.visibleMaxDepth,
          depthAt: layer.depthAt,
        ).single!;

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

  testWidgets('showAnnotations false hides the lines and the layer', (
    tester,
  ) async {
    await tester.pumpWidget(_chart([_ann('a', 600)], showAnnotations: false));
    await tester.pumpAndSettle();
    expect(_annotationLines(tester), isEmpty);
    expect(find.byType(AnnotationMarkerLayer), findsNothing);
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
}
