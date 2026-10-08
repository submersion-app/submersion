import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_cylinders_summary_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The story's cylinders line while a trip is under way (#2845).
void main() {
  final at = DateTime.utc(2026, 3, 9, 8);
  final now = DateTime.now();

  Trip trip({int startOffset = -1}) {
    final start = DateTime(now.year, now.month, now.day + startOffset);
    return Trip(
      id: 't1',
      name: 'Bonaire',
      startDate: start,
      endDate: DateTime(start.year, start.month, start.day + 4),
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );
  }

  TripCylinderState full(String id) => foldCylinderState(
    cylinder: TripCylinder(
      id: id,
      tripId: 't1',
      label: id,
      workingPressure: 207,
      createdAt: at,
      updatedAt: at,
    ),
    events: [
      TripCylinderEvent(
        id: 'f-$id',
        tripCylinderId: id,
        kind: TripCylinderEventKind.fill,
        occurredAt: at,
        pressure: 207,
        o2Percent: 32,
        createdAt: at,
        updatedAt: at,
      ),
    ],
    uses: const [],
  );

  const forecast = FillForecast(
    fullCount: 1,
    partialCount: 0,
    todayDemand: 2,
    tomorrowDemand: 4,
    tomorrowSupply: 0,
    todayShortfall: 1,
    tomorrowShortfall: 4,
    deadlineMinutes: 1020,
    remainingDemand: 12,
    days: [],
  );

  Future<List<String>> pump(
    WidgetTester tester,
    Trip onTrip,
    List<TripCylinderState> slots,
  ) async {
    final pushed = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(body: TripCylindersSummaryCard(trip: onTrip)),
        ),
        GoRoute(
          path: '/trips/:tripId/cylinders',
          builder: (_, s) {
            pushed.add(s.uri.path);
            return const Scaffold();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tripCylinderStatesProvider('t1').overrideWith((ref) async => slots),
          tripFillForecastProvider('t1').overrideWith((ref) async => forecast),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return pushed;
  }

  const card = Key('trip-cylinders-summary');

  testWidgets('a trip in progress with slots shows the counts and forecast', (
    tester,
  ) async {
    await pump(tester, trip(), [full('a')]);
    expect(find.text('Full 1 · Partial 0 · Empty 0'), findsOneWidget);
    expect(find.byKey(const Key('trip-cylinders-forecast')), findsOneWidget);
  });

  testWidgets('tapping it opens the board', (tester) async {
    final pushed = await pump(tester, trip(), [full('a')]);
    await tester.tap(find.byKey(card));
    await tester.pumpAndSettle();
    expect(pushed, ['/trips/t1/cylinders']);
  });

  testWidgets('an upcoming trip shows nothing', (tester) async {
    await pump(tester, trip(startOffset: 10), [full('a')]);
    expect(find.byKey(card), findsNothing);
  });

  testWidgets('a trip in progress with no slots shows nothing', (tester) async {
    await pump(tester, trip(), const []);
    expect(find.byKey(card), findsNothing);
  });

  testWidgets('a past trip shows nothing', (tester) async {
    await pump(tester, trip(startOffset: -20), [full('a')]);
    expect(find.byKey(card), findsNothing);
  });
}
