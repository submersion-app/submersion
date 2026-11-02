import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_placement_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_marker_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Placement mode on the dive profile (#4109): a tap, or a hold that ends
/// anywhere, places an annotation at the second under the finger; a
/// right-click reports its spot for the context menu; nothing happens
/// outside placement mode.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _profile = List.generate(41, (i) {
  final t = i * 30;
  final depth = t < 180
      ? 30.0 * t / 180
      : t < 900
      ? 30.0
      : 30.0 * (1200 - t) / 300;
  return DiveProfilePoint(timestamp: t, depth: depth);
});

typedef _Placed = ({int seconds, double? depth});
typedef _Secondary = ({int seconds, double? depth, Offset at});

Widget _chart({
  bool placement = true,
  List<ProfileEvent>? events,
  void Function(_Placed)? onPlaced,
  void Function(_Secondary)? onSecondary,
  void Function(ProfileEvent)? onTap,
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
        child: DiveProfileChart(
          profile: _profile,
          events: events,
          annotationPlacement: placement,
          onAnnotationPlaced: (s, d) => onPlaced?.call((seconds: s, depth: d)),
          onSecondaryTapAt: (s, d, at) =>
              onSecondary?.call((seconds: s, depth: d, at: at)),
          onAnnotationTap: (a, _) => onTap?.call(a),
        ),
      ),
    ),
  ),
);

Rect _plot(WidgetTester tester) => tester.getRect(find.byType(LineChart));

void main() {
  testWidgets('in placement mode a tap reports the seconds and depth under '
      'the finger', (tester) async {
    final placed = <_Placed>[];
    await tester.pumpWidget(_chart(onPlaced: placed.add));
    await tester.pumpAndSettle();
    final plot = _plot(tester);

    await tester.tapAt(Offset(plot.left + plot.width * 0.3, plot.center.dy));
    await tester.pump();
    await tester.tapAt(Offset(plot.left + plot.width * 0.7, plot.center.dy));
    await tester.pump();

    expect(placed, hasLength(2));
    expect(placed[0].seconds, inInclusiveRange(150, 600));
    expect(placed[1].seconds, inInclusiveRange(600, 1150));
    expect(placed[1].seconds, greaterThan(placed[0].seconds));
    for (final p in placed) {
      expect(p.depth, profileDepthAt(_profile, p.seconds));
    }
  });

  testWidgets('a tap past the plot edge clamps to the dive', (tester) async {
    final placed = <_Placed>[];
    await tester.pumpWidget(_chart(onPlaced: placed.add));
    await tester.pumpAndSettle();
    final plot = _plot(tester);
    await tester.tapAt(Offset(plot.right - 1, plot.center.dy));
    await tester.pump();
    expect(placed.single.seconds, inInclusiveRange(1100, 1200));
  });

  testWidgets('a hold then release places where the finger lifted', (
    tester,
  ) async {
    final placed = <_Placed>[];
    await tester.pumpWidget(_chart(onPlaced: placed.add));
    await tester.pumpAndSettle();
    final plot = _plot(tester);
    final start = Offset(plot.left + plot.width * 0.3, plot.center.dy);

    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();

    await tester.tapAt(start + const Offset(80, 0));
    await tester.pump();

    expect(placed, hasLength(2));
    expect(placed[0].seconds, closeTo(placed[1].seconds, 3));
  });

  testWidgets('outside placement mode a tap reports nothing', (tester) async {
    final placed = <_Placed>[];
    await tester.pumpWidget(_chart(placement: false, onPlaced: placed.add));
    await tester.pumpAndSettle();
    await tester.tapAt(_plot(tester).center);
    await tester.pump();
    expect(placed, isEmpty);
  });

  testWidgets('a right-click reports seconds, depth and the global position', (
    tester,
  ) async {
    final placed = <_Placed>[];
    final secondary = <_Secondary>[];
    await tester.pumpWidget(
      _chart(
        placement: false,
        onPlaced: placed.add,
        onSecondary: secondary.add,
      ),
    );
    await tester.pumpAndSettle();
    final at = Offset(_plot(tester).left + _plot(tester).width * 0.5, 150);

    final gesture = await tester.startGesture(
      at,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(placed, isEmpty);
    final hit = secondary.single;
    expect(hit.at, at);
    expect(hit.seconds, inInclusiveRange(400, 800));
    expect(hit.depth, profileDepthAt(_profile, hit.seconds));
  });

  testWidgets('a tap on the dot in placement mode places instead of opening', (
    tester,
  ) async {
    final placed = <_Placed>[];
    final opened = <ProfileEvent>[];
    final annotation = ProfileEvent.annotation(
      id: 'a',
      diveId: 'd',
      timestamp: 600,
      words: 'w',
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      _chart(events: [annotation], onPlaced: placed.add, onTap: opened.add),
    );
    await tester.pumpAndSettle();
    final layerFinder = find.byType(AnnotationMarkerLayer);
    final layer = tester.widget<AnnotationMarkerLayer>(layerFinder);
    expect(layer.interactive, isFalse);
    final dot = annotationDotCenters(
      annotations: layer.annotations,
      size: tester.getSize(layerFinder),
      insets: layer.insets,
      visibleMinSeconds: layer.visibleMinSeconds,
      visibleMaxSeconds: layer.visibleMaxSeconds,
      visibleMinDepth: layer.visibleMinDepth,
      visibleMaxDepth: layer.visibleMaxDepth,
      depthAt: layer.depthAt,
    ).single!;

    await tester.tapAt(tester.getTopLeft(layerFinder) + dot);
    await tester.pump();

    expect(opened, isEmpty);
    expect(placed.single.seconds, closeTo(600, 10));
  });

  test('the placement provider starts off, moves, and cancels', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(annotationPlacementProvider('d1').notifier);
    expect(container.read(annotationPlacementProvider('d1')), isNull);
    notifier.startNew();
    expect(container.read(annotationPlacementProvider('d1'))?.movingId, isNull);
    expect(container.read(annotationPlacementProvider('d1')), isNotNull);
    notifier.startMove('a1');
    expect(container.read(annotationPlacementProvider('d1'))?.movingId, 'a1');
    notifier.cancel();
    expect(container.read(annotationPlacementProvider('d1')), isNull);
  });
}
