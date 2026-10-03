import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/pages/trip_day_map_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _site = DiveSite(
  id: 'site-a',
  name: 'Blue Corner',
  location: GeoPoint(12.1, -68.2),
);

Dive _dive(String id, int hour) => Dive(
  id: id,
  dateTime: DateTime(2026, 3, 8, hour),
  maxDepth: 20,
  site: _site,
);

TripStoryDay _day() => TripStoryDay(
  date: DateTime(2026, 3, 8),
  dayNumber: 2,
  kind: TripStoryDayKind.past,
  dives: [_dive('d1', 9), _dive('d2', 14)],
);

TripStoryMapPoint _pin(String id, int number) => TripStoryMapPoint(
  latitude: 12.1,
  longitude: -68.2,
  dayIndex: 1,
  label: 'Blue Corner',
  siteId: 'site-a',
  diveId: id,
  diveNumber: number,
);

Future<void> _pump(WidgetTester tester) async {
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            TripDayMapPage(day: _day(), points: [_pin('d1', 1), _pin('d2', 2)]),
      ),
      GoRoute(
        path: '/dives/:id',
        builder: (_, state) =>
            Scaffold(body: Text('DIVE ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('titles the page with the day and fills it with the map', (
    tester,
  ) async {
    await _pump(tester);
    final date = const UnitFormatter(
      AppSettings(),
    ).formatMonthDay(DateTime(2026, 3, 8));
    expect(find.text('Day 2 · $date'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const Key('day-map-expand')), findsNothing);
    expect(find.byType(DiveListItem), findsNothing);
  });

  testWidgets('tapping a pin docks that dive, tapping it again undocks', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('day-map-pin-d2')));
    await tester.pumpAndSettle();
    final docked = tester.widget<DiveListItem>(find.byType(DiveListItem));
    expect(docked.summary.id, 'd2');
    expect(docked.isHighlighted, isTrue);
    await tester.tap(find.byKey(const Key('day-map-pin-d2')));
    await tester.pumpAndSettle();
    expect(find.byType(DiveListItem), findsNothing);
  });

  testWidgets('tapping the docked row opens the dive', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('day-map-pin-d1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DiveListItem));
    await tester.pumpAndSettle();
    expect(find.text('DIVE d1'), findsOneWidget);
  });

  testWidgets('tapping the map background undocks the row', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('day-map-pin-d1')));
    await tester.pumpAndSettle();
    expect(find.byType(DiveListItem), findsOneWidget);
    await tester.tapAt(
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(40, 40),
    );
    // A tap on the map body arms flutter_map's double-tap timer.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(DiveListItem), findsNothing);
  });
}
