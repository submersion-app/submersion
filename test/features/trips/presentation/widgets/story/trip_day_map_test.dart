import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_map.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

TripStoryDay _day() => TripStoryDay(
  date: DateTime(2026, 3, 8),
  dayNumber: 2,
  kind: TripStoryDayKind.past,
);

const _port = TripStoryMapPoint(
  latitude: 12.15,
  longitude: -68.27,
  dayIndex: 1,
  label: 'Kralendijk',
);
const _dive1 = TripStoryMapPoint(
  latitude: 12.1,
  longitude: -68.2,
  dayIndex: 1,
  label: 'Blue Corner',
  siteId: 'site-a',
  diveId: 'd1',
  diveNumber: 1,
);
const _dive2 = TripStoryMapPoint(
  latitude: 12.1,
  longitude: -68.2,
  dayIndex: 1,
  label: 'Blue Corner',
  siteId: 'site-a',
  diveId: 'd2',
  diveNumber: 2,
);

Future<List<String?>> _pump(
  WidgetTester tester, {
  required List<TripStoryMapPoint> points,
  String? highlighted,
  VoidCallback? onExpand,
}) async {
  final taps = <String?>[];
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 180,
            child: TripDayMap(
              day: _day(),
              points: points,
              highlightedDiveId: highlighted,
              onDiveTap: taps.add,
              onExpand: onExpand,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return taps;
}

void main() {
  testWidgets('draws a pin per dive numbered like the rows, and the port', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, points: [_port, _dive1, _dive2]);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.bySemanticsLabel('Dive 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Dive 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Kralendijk'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Map of day 2')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tapping a dive pin reports its dive', (tester) async {
    final taps = await _pump(tester, points: [_dive1]);
    await tester.tap(find.byKey(const Key('day-map-pin-d1')));
    await tester.pump();
    expect(taps, ['d1']);
  });

  testWidgets('a screen reader can activate a dive pin', (tester) async {
    final handle = tester.ensureSemantics();
    final taps = await _pump(tester, points: [_dive1]);
    final node = tester.getSemantics(find.byKey(const Key('day-map-pin-d1')));
    expect(node.label, 'Dive 1');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(taps, ['d1']);
    handle.dispose();
  });

  testWidgets('tapping the highlighted pin clears the highlight', (
    tester,
  ) async {
    final taps = await _pump(tester, points: [_dive1], highlighted: 'd1');
    await tester.tap(find.byKey(const Key('day-map-pin-d1')));
    await tester.pump();
    expect(taps, [null]);
  });

  testWidgets('same-site dives get distinct pins', (tester) async {
    final taps = await _pump(tester, points: [_dive1, _dive2]);
    final a = tester.getCenter(find.byKey(const Key('day-map-pin-d1')));
    final b = tester.getCenter(find.byKey(const Key('day-map-pin-d2')));
    expect(a.dy, b.dy);
    // Each pin answers a tap on its own dot, though the hit boxes overlap.
    await tester.tapAt(a);
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(b);
    await tester.pump(const Duration(seconds: 1));
    expect(taps, ['d1', 'd2']);
  });

  testWidgets('the port pin is not a button', (tester) async {
    final taps = await _pump(tester, points: [_port]);
    expect(find.byKey(const Key('day-map-pin-port-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('day-map-pin-port-0')));
    // A tap on the map body arms flutter_map's double-tap timer.
    await tester.pump(const Duration(seconds: 1));
    expect(taps, isEmpty);
  });

  testWidgets('the expand button shows only with a handler', (tester) async {
    await _pump(tester, points: [_dive1]);
    expect(find.byTooltip('View fullscreen map'), findsNothing);
    var expanded = 0;
    await _pump(tester, points: [_dive1], onExpand: () => expanded++);
    await tester.tap(find.byTooltip('View fullscreen map'));
    expect(expanded, 1);
  });

  testWidgets('new points re-fit the camera', (tester) async {
    await _pump(tester, points: [_dive1]);
    const far = TripStoryMapPoint(
      latitude: -8.5,
      longitude: 119.4,
      dayIndex: 1,
      label: 'Komodo',
      siteId: 'site-k',
      diveId: 'd9',
      diveNumber: 9,
    );
    await _pump(tester, points: [far]);
    await tester.pump(const Duration(seconds: 1));
    final camera = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera;
    expect(camera.center.latitude, closeTo(-8.5, 0.5));
    expect(camera.center.longitude, closeTo(119.4, 0.5));
  });
}
