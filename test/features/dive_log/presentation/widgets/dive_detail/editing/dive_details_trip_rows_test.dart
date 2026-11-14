import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/services/dive_center_picker_ranking.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_picker.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

Trip _trip(String id, String name) => Trip(
  id: id,
  name: name,
  startDate: DateTime(2026, 3, 7),
  endDate: DateTime(2026, 3, 14),
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

DiveCenter _center(String id, String name, {String? city}) => DiveCenter(
  id: id,
  name: name,
  city: city,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

/// Answers lookups from a map, optionally only once [gate] opens.
class _Trips extends TripRepository {
  _Trips(this.byId);

  final Map<String, Trip> byId;
  Completer<void>? gate;

  @override
  Future<Trip?> getTripById(String id) async {
    await gate?.future;
    return byId[id];
  }
}

class _Centers extends DiveCenterRepository {
  _Centers(this.byId);

  final Map<String, DiveCenter> byId;

  @override
  Future<DiveCenter?> getDiveCenterById(String id) async => byId[id];
}

/// The trip and dive center rows of the Details card (issue #4527).
void main() {
  final l = AppLocalizationsEn();
  final redSea = _trip('red-sea', 'Red Sea North');
  final maldives = _trip('maldives', 'Maldives South');
  final created = _trip('new-trip', 'Brand New Trip');
  final blueHole = _center('blue-hole', 'Blue Hole Divers', city: 'Dahab');
  final reef = _center('reef', 'Reef Riders');
  final newCenter = _center('new-center', 'Brand New Center');
  final bare = Dive(id: 'dive', dateTime: DateTime.utc(2026, 3, 9, 10));

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  late _Trips trips;
  final showRows = ValueNotifier<bool>(true);

  Future<RecordEditController<Dive>> pumpRows(
    WidgetTester tester,
    Dive dive, {
    Trip? suggested,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    showRows.value = true;
    trips = _Trips({
      for (final t in [redSea, maldives, created]) t.id: t,
    });
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(dive)
      ..openCard('details');
    addTearDown(controller.dispose);
    final EditSession<Dive> session = controller.session!;

    Widget stub(String label, String id) => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.pop(id),
            child: Text(label),
          ),
        ),
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: RecordEditScope<Dive>(
              controller: controller,
              child: ValueListenableBuilder<bool>(
                valueListenable: showRows,
                builder: (context, show, _) => Column(
                  children: [
                    if (show) DiveTripRow(session: session),
                    if (show) DiveCenterRow(session: session),
                  ],
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/trips/new',
          builder: (context, state) => stub('save the trip', 'new-trip'),
        ),
        GoRoute(
          path: '/dive-centers/new',
          builder: (context, state) => stub('save the center', 'new-center'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          allTripsProvider.overrideWith((ref) async => [redSea, maldives]),
          tripForDateProvider.overrideWith((ref, day) async => suggested),
          tripRepositoryProvider.overrideWithValue(trips),
          allDiveCentersProvider.overrideWith((ref) async => [blueHole, reef]),
          diveCenterRepositoryProvider.overrideWithValue(
            _Centers({
              for (final c in [blueHole, reef, newCenter]) c.id: c,
            }),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Dive working(RecordEditController<Dive> controller) =>
      controller.session!.working;

  Future<void> openTripSheet(WidgetTester tester) async {
    await tester.tap(find.text(l.diveLog_edit_row_trip));
    await tester.pumpAndSettle();
  }

  Future<void> openCenterSheet(WidgetTester tester) async {
    await tester.tap(find.text(l.diveLog_edit_row_diveCenter));
    await tester.pumpAndSettle();
  }

  group('the trip row', () {
    testWidgets('a dive on a trip shows its name and its dates', (
      tester,
    ) async {
      await pumpRows(tester, bare.copyWith(trip: redSea, tripId: redSea.id));

      expect(find.text('Red Sea North'), findsOneWidget);
      const units = UnitFormatter(AppSettings());
      expect(
        find.text(
          units.formatDateRange(redSea.startDate, redSea.endDate, l10n: l),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a dive on no trip says Not set and shows no dates', (
      tester,
    ) async {
      await pumpRows(tester, bare);

      expect(find.text(l.diveLog_edit_row_notSet), findsNWidgets(2));
    });

    testWidgets('clearing the trip sets none', (tester) async {
      final controller = await pumpRows(
        tester,
        bare.copyWith(trip: redSea, tripId: redSea.id),
      );

      await tester.tap(find.byIcon(Icons.clear).first);
      await tester.pumpAndSettle();

      expect(working(controller).trip, isNull);
      expect(working(controller).tripId, isNull);
      expect(find.text('Red Sea North'), findsNothing);
    });

    testWidgets('picking a trip in the sheet sets it and closes the sheet', (
      tester,
    ) async {
      final controller = await pumpRows(tester, bare);
      await openTripSheet(tester);
      expect(find.text(l.trips_picker_sheetTitle), findsOneWidget);

      await tester.tap(find.text('Maldives South'));
      await tester.pumpAndSettle();

      expect(working(controller).trip?.id, 'maldives');
      expect(working(controller).tripId, 'maldives');
      expect(find.text(l.trips_picker_sheetTitle), findsNothing);
      expect(find.text('Maldives South'), findsOneWidget);
    });

    testWidgets('a dive on no trip is offered the trip its day falls in', (
      tester,
    ) async {
      final controller = await pumpRows(tester, bare, suggested: redSea);

      expect(
        find.text(l.diveLog_edit_tripSuggested('Red Sea North')),
        findsOneWidget,
      );
      await tester.tap(find.text(l.diveLog_edit_tripUse));
      await tester.pumpAndSettle();

      expect(working(controller).tripId, 'red-sea');
      expect(
        find.text(l.diveLog_edit_tripSuggested('Red Sea North')),
        findsNothing,
      );
    });

    testWidgets('a dive on a trip is offered none', (tester) async {
      await pumpRows(
        tester,
        bare.copyWith(trip: maldives, tripId: maldives.id),
        suggested: redSea,
      );

      expect(find.text(l.diveLog_edit_tripUse), findsNothing);
    });

    testWidgets('a new trip made from the sheet is set when its page '
        'returns', (tester) async {
      final controller = await pumpRows(tester, bare);
      await openTripSheet(tester);
      await tester.tap(find.text(l.trips_picker_newTrip));
      await tester.pumpAndSettle();

      await tester.tap(find.text('save the trip'));
      await tester.pumpAndSettle();

      expect(working(controller).tripId, 'new-trip');
      expect(find.text('Brand New Trip'), findsOneWidget);
    });

    testWidgets('a new trip that returns after the sitting was cancelled '
        'sets nothing', (tester) async {
      final controller = await pumpRows(tester, bare);
      await openTripSheet(tester);
      await tester.tap(find.text(l.trips_picker_newTrip));
      await tester.pumpAndSettle();

      controller.lock();
      await tester.tap(find.text('save the trip'));
      await tester.pumpAndSettle();

      expect(controller.isUnlocked, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a new trip that returns while the sitting is saved sets '
        'nothing', (tester) async {
      final controller = await pumpRows(tester, bare);
      await openTripSheet(tester);
      await tester.tap(find.text(l.trips_picker_newTrip));
      await tester.pumpAndSettle();

      controller.session!.freeze();
      await tester.tap(find.text('save the trip'));
      await tester.pumpAndSettle();
      controller.session!.thaw();

      expect(working(controller).tripId, isNull);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('the row gone before its lookup answers sets nothing', (
      tester,
    ) async {
      final controller = await pumpRows(tester, bare);
      trips.gate = Completer<void>();
      await openTripSheet(tester);
      await tester.tap(find.text(l.trips_picker_newTrip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('save the trip'));
      await tester.pumpAndSettle();

      showRows.value = false;
      await tester.pump();
      trips.gate!.complete();
      await tester.pumpAndSettle();

      expect(controller.isDirty, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('the dive center row', () {
    testWidgets('a dive center shows its name and where it is', (tester) async {
      await pumpRows(tester, bare.copyWith(diveCenter: blueHole));

      expect(find.text('Blue Hole Divers'), findsOneWidget);
      expect(find.text('Dahab'), findsOneWidget);
    });

    testWidgets('clearing the center sets none', (tester) async {
      final controller = await pumpRows(
        tester,
        bare.copyWith(diveCenter: blueHole),
      );

      await tester.tap(find.byIcon(Icons.clear).first);
      await tester.pumpAndSettle();

      expect(working(controller).diveCenter, isNull);
    });

    testWidgets('picking a center sets it and closes the sheet', (
      tester,
    ) async {
      final controller = await pumpRows(tester, bare);
      await openCenterSheet(tester);
      expect(find.text(l.diveCenters_picker_title), findsOneWidget);

      await tester.tap(find.text('Reef Riders'));
      await tester.pumpAndSettle();

      expect(working(controller).diveCenter?.id, 'reef');
      expect(find.text(l.diveCenters_picker_title), findsNothing);
    });

    testWidgets('the picker is given the site as its reference', (
      tester,
    ) async {
      const site = DiveSite(
        id: 'site',
        name: 'Blue Hole',
        location: GeoPoint(28.57, 34.54),
      );
      await pumpRows(tester, bare.copyWith(site: site));
      await openCenterSheet(tester);

      final sheet = tester.widget<DiveCenterPickerSheet>(
        find.byType(DiveCenterPickerSheet),
      );
      expect(sheet.reference?.source, DiveCenterReferenceSource.site);
    });

    testWidgets('with no site and no GPS the picker has no reference', (
      tester,
    ) async {
      await pumpRows(tester, bare);
      await openCenterSheet(tester);

      final sheet = tester.widget<DiveCenterPickerSheet>(
        find.byType(DiveCenterPickerSheet),
      );
      expect(sheet.reference, isNull);
    });

    testWidgets('a new center made from the sheet is set when its page '
        'returns', (tester) async {
      final controller = await pumpRows(tester, bare);
      await openCenterSheet(tester);
      await tester.tap(find.text(l.diveCenters_picker_newCenter));
      await tester.pumpAndSettle();

      await tester.tap(find.text('save the center'));
      await tester.pumpAndSettle();

      expect(working(controller).diveCenter?.id, 'new-center');
      expect(find.text('Brand New Center'), findsOneWidget);
    });

    testWidgets('a new center that returns after the sitting ended sets '
        'nothing', (tester) async {
      final controller = await pumpRows(tester, bare);
      await openCenterSheet(tester);
      await tester.tap(find.text(l.diveCenters_picker_newCenter));
      await tester.pumpAndSettle();

      controller.lock();
      await tester.tap(find.text('save the center'));
      await tester.pumpAndSettle();

      expect(controller.isUnlocked, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
