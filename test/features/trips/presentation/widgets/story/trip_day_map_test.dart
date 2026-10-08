import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
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

/// Two entries of one pier: different sites a few metres apart.
const _pierNorth = TripStoryMapPoint(
  latitude: 12.1,
  longitude: -68.2,
  dayIndex: 1,
  label: 'Pier North',
  siteId: 'site-n',
  diveId: 'd1',
  diveNumber: 1,
);
const _pierSouth = TripStoryMapPoint(
  latitude: 12.09996,
  longitude: -68.20002,
  dayIndex: 1,
  label: 'Pier South',
  siteId: 'site-s',
  diveId: 'd2',
  diveNumber: 2,
);
const _farDive = TripStoryMapPoint(
  latitude: 12.3,
  longitude: -68.4,
  dayIndex: 1,
  label: 'Klein Bonaire',
  siteId: 'site-k',
  diveId: 'd3',
  diveNumber: 3,
);

/// A hundred metres apart.
const _reefA = TripStoryMapPoint(
  latitude: 12.1,
  longitude: -68.2,
  dayIndex: 1,
  label: 'Reef A',
  siteId: 'site-ra',
  diveId: 'd4',
  diveNumber: 4,
);
const _reefB = TripStoryMapPoint(
  latitude: 12.1,
  longitude: -68.1991,
  dayIndex: 1,
  label: 'Reef B',
  siteId: 'site-rb',
  diveId: 'd5',
  diveNumber: 5,
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
    await _pump(tester, points: [_port, _dive1, _farDive]);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.bySemanticsLabel('Dive 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Dive 3'), findsOneWidget);
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

  testWidgets('same-site dives share one badge', (tester) async {
    await _pump(tester, points: [_dive1, _dive2]);
    expect(find.byKey(const Key('day-map-group-d1')), findsOneWidget);
    expect(find.byKey(const Key('day-map-pin-d1')), findsNothing);
    expect(find.byKey(const Key('day-map-pin-d2')), findsNothing);
  });

  testWidgets('dives at nearby sites share one badge (#2883)', (tester) async {
    await _pump(tester, points: [_pierNorth, _pierSouth]);
    final badge = find.byKey(const Key('day-map-group-d1'));
    expect(badge, findsOneWidget);
    expect(find.byKey(const Key('day-map-pin-d1')), findsNothing);
    expect(find.byKey(const Key('day-map-pin-d2')), findsNothing);
    // The earliest dive's number, with the group's size on its corner.
    expect(
      find.descendant(of: badge, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: badge, matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('distant dives keep their own pins', (tester) async {
    await _pump(tester, points: [_dive1, _farDive]);
    expect(find.byKey(const Key('day-map-pin-d1')), findsOneWidget);
    expect(find.byKey(const Key('day-map-pin-d3')), findsOneWidget);
    expect(find.byKey(const Key('day-map-group-d1')), findsNothing);
  });

  testWidgets('a screen reader reads the badge as its dive count', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, points: [_pierNorth, _pierSouth]);
    final node = tester.getSemantics(find.byKey(const Key('day-map-group-d1')));
    expect(node.label, '2 dives here');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('tapping the badge lists its dives; choosing one reports it', (
    tester,
  ) async {
    final taps = await _pump(tester, points: [_pierNorth, _pierSouth]);
    await tester.tap(find.byKey(const Key('day-map-group-d1')));
    await tester.pumpAndSettle();
    expect(find.text('Dive 1 \u00b7 Pier North'), findsOneWidget);
    expect(find.text('Dive 2 \u00b7 Pier South'), findsOneWidget);
    await tester.tap(find.text('Dive 2 \u00b7 Pier South'));
    await tester.pumpAndSettle();
    expect(taps, ['d2']);
  });

  testWidgets('choosing the highlighted dive from the badge clears it', (
    tester,
  ) async {
    final taps = await _pump(
      tester,
      points: [_pierNorth, _pierSouth],
      highlighted: 'd2',
    );
    await tester.tap(find.byKey(const Key('day-map-group-d1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dive 2 \u00b7 Pier South'));
    await tester.pumpAndSettle();
    expect(taps, [null]);
  });

  testWidgets('the badge shows as selected while one of its dives is', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, points: [_pierNorth, _pierSouth], highlighted: 'd2');
    final node = tester.getSemantics(find.byKey(const Key('day-map-group-d1')));
    expect(node, isSemantics(isSelected: true, isButton: true));
    handle.dispose();
  });

  testWidgets('zooming in splits a badge back into pins', (tester) async {
    // The port, kilometres off, keeps the fitted zoom wide enough that two
    // dives a hundred metres apart land on the same pixels.
    await _pump(tester, points: [_port, _reefA, _reefB]);
    expect(find.byKey(const Key('day-map-group-d4')), findsOneWidget);
    tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .move(const LatLng(12.1, -68.2), 18);
    await tester.pump();
    expect(find.byKey(const Key('day-map-group-d4')), findsNothing);
    expect(find.byKey(const Key('day-map-pin-d4')), findsOneWidget);
    expect(find.byKey(const Key('day-map-pin-d5')), findsOneWidget);
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
