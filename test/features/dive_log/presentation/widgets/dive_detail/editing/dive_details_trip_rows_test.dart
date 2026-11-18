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
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
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

  /// When set, every lookup fails with it.
  Object? failWith;

  @override
  Future<Trip?> getTripById(String id) async {
    await gate?.future;
    final error = failWith;
    if (error != null) throw error;
    return byId[id];
  }
}

class _Centers extends DiveCenterRepository {
  _Centers(this.byId);

  final Map<String, DiveCenter> byId;

  /// When set, every lookup fails with it.
  Object? failWith;

  @override
  Future<DiveCenter?> getDiveCenterById(String id) async {
    final error = failWith;
    if (error != null) throw error;
    return byId[id];
  }
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
  late _Centers centers;
  // One per test, so no test inherits what the one before it left.
  late ValueNotifier<bool> showRows;
  // The sitting the rows are bound to, so a test can hand them another.
  late ValueNotifier<EditSession<Dive>> boundSession;
  // What the new-trip page was opened with: its prefilled draft.
  Object? newTripExtra;

  Future<RecordEditController<Dive>> pumpRows(
    WidgetTester tester,
    Dive dive, {
    Trip? suggested,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    newTripExtra = null;
    showRows = ValueNotifier<bool>(true);
    addTearDown(showRows.dispose);
    centers = _Centers({
      for (final c in [blueHole, reef, newCenter]) c.id: c,
    });
    trips = _Trips({
      for (final t in [redSea, maldives, created]) t.id: t,
    });
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(dive)
      ..openCard('details');
    addTearDown(controller.dispose);
    boundSession = ValueNotifier<EditSession<Dive>>(controller.session!);
    addTearDown(boundSession.dispose);

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
              child: ListenableBuilder(
                listenable: Listenable.merge([showRows, boundSession]),
                builder: (context, _) => Column(
                  children: [
                    if (showRows.value)
                      DiveTripRow(session: boundSession.value),
                    if (showRows.value)
                      DiveCenterRow(session: boundSession.value),
                  ],
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/trips/new',
          builder: (context, state) {
            newTripExtra = state.extra;
            return stub('save the trip', 'new-trip');
          },
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
          diveCenterRepositoryProvider.overrideWithValue(centers),
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

    // A trip id whose trip did not load (deleted on another device, say)
    // read as no trip, but Save would keep the id. The row says the trip is
    // not there and offers the clear, and taking it is a change like any
    // other.
    testWidgets('a trip that did not load can be cleared', (tester) async {
      final controller = await pumpRows(tester, bare.copyWith(tripId: 'gone'));

      expect(find.text(l.diveLog_edit_row_tripNotFound), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(working(controller).tripId, isNull);
      expect(working(controller).trip, isNull);
      expect(controller.isDirty, isTrue);
      expect(find.byIcon(Icons.clear), findsNothing);
      expect(find.text(l.diveLog_edit_row_tripNotFound), findsNothing);
      expect(find.text(l.diveLog_edit_row_notSet), findsNWidgets(2));
    });

    testWidgets('a trip picked over one that did not load replaces it', (
      tester,
    ) async {
      final controller = await pumpRows(tester, bare.copyWith(tripId: 'gone'));

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      await openTripSheet(tester);
      await tester.tap(find.text('Red Sea North').last);
      await tester.pumpAndSettle();

      expect(working(controller).tripId, redSea.id);
      expect(working(controller).trip?.id, redSea.id);
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

    testWidgets('a new trip that cannot be read back says so and sets '
        'nothing', (tester) async {
      final controller = await pumpRows(tester, bare);
      trips.failWith = StateError('the trip could not be read');
      await openTripSheet(tester);
      await tester.tap(find.text(l.trips_picker_newTrip));
      await tester.pumpAndSettle();

      await tester.tap(find.text('save the trip'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(l.diveLog_edit_newRecordNotAdded), findsOneWidget);
      // Not an invitation to make it a second time.
      expect(find.text(l.common_error_tryAgain), findsNothing);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('a new trip that is not there to read back says so', (
      tester,
    ) async {
      final controller = await pumpRows(tester, bare);
      trips.byId.remove('new-trip');
      await openTripSheet(tester);
      await tester.tap(find.text(l.trips_picker_newTrip));
      await tester.pumpAndSettle();

      await tester.tap(find.text('save the trip'));
      await tester.pumpAndSettle();

      expect(find.text(l.diveLog_edit_newRecordNotAdded), findsOneWidget);
      // Not an invitation to make it a second time.
      expect(find.text(l.common_error_tryAgain), findsNothing);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('the new-trip form is prefilled from the sitting its picker '
        'was opened in', (tester) async {
      await pumpRows(tester, bare);
      await openTripSheet(tester);

      // The row is handed a sitting on another dive while the sheet is open.
      final other = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(Dive(id: 'other', dateTime: DateTime.utc(2026, 7, 1, 10)))
        ..openCard('details');
      addTearDown(other.dispose);
      boundSession.value = other.session!;
      await tester.pump();

      await tester.tap(find.text(l.trips_picker_newTrip));
      await tester.pumpAndSettle();

      // The dive the picker was opened for is on 9 March.
      final draft = newTripExtra! as TripDraft;
      expect(
        (draft.trip.startDate.year, draft.trip.startDate.month),
        (2026, 3),
      );
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

    testWidgets('a new trip belongs to the sitting its picker was opened '
        'in', (tester) async {
      final controller = await pumpRows(tester, bare);
      await openTripSheet(tester);
      await tester.tap(find.text(l.trips_picker_newTrip));
      await tester.pumpAndSettle();

      // The same row is handed another sitting while the new-trip page is
      // still open.
      final other = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(bare)
        ..openCard('details');
      addTearDown(other.dispose);
      boundSession.value = other.session!;
      await tester.pump();

      await tester.tap(find.text('save the trip'));
      await tester.pumpAndSettle();

      expect(other.isDirty, isFalse);
      expect(working(controller).tripId, 'new-trip');
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

  testWidgets('both clear buttons say what they do', (tester) async {
    await pumpRows(
      tester,
      bare.copyWith(trip: redSea, tripId: redSea.id, diveCenter: blueHole),
    );

    expect(find.byTooltip(l.common_action_remove), findsNWidgets(2));
  });

  testWidgets('the suggestion lines up with the caption it gives way to', (
    tester,
  ) async {
    final controller = await pumpRows(tester, bare, suggested: redSea);
    final suggestion = find.text(l.diveLog_edit_tripSuggested('Red Sea North'));
    // Past the icon and its gap, the words would sit further in: compare
    // the row's own left edge with the caption's.
    final suggestionLeft = tester
        .getTopLeft(
          find.ancestor(of: suggestion, matching: find.byType(Row)).first,
        )
        .dx;

    await tester.tap(find.text(l.diveLog_edit_tripUse));
    await tester.pumpAndSettle();

    const units = UnitFormatter(AppSettings());
    final caption = find.text(
      units.formatDateRange(redSea.startDate, redSea.endDate, l10n: l),
    );
    expect(controller.session!.working.tripId, 'red-sea');
    expect(tester.getTopLeft(caption).dx, suggestionLeft);
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

    testWidgets('a new center that cannot be read back says so and sets '
        'nothing', (tester) async {
      final controller = await pumpRows(tester, bare);
      centers.failWith = StateError('the center could not be read');
      await openCenterSheet(tester);
      await tester.tap(find.text(l.diveCenters_picker_newCenter));
      await tester.pumpAndSettle();

      await tester.tap(find.text('save the center'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(l.diveLog_edit_newRecordNotAdded), findsOneWidget);
      // Not an invitation to make it a second time.
      expect(find.text(l.common_error_tryAgain), findsNothing);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('a new center belongs to the sitting its picker was opened '
        'in', (tester) async {
      final controller = await pumpRows(tester, bare);
      await openCenterSheet(tester);
      await tester.tap(find.text(l.diveCenters_picker_newCenter));
      await tester.pumpAndSettle();

      final other = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(bare)
        ..openCard('details');
      addTearDown(other.dispose);
      boundSession.value = other.session!;
      await tester.pump();

      await tester.tap(find.text('save the center'));
      await tester.pumpAndSettle();

      expect(other.isDirty, isFalse);
      expect(working(controller).diveCenter?.id, 'new-center');
    });

    testWidgets('a new center that is not there to read back says so', (
      tester,
    ) async {
      final controller = await pumpRows(tester, bare);
      centers.byId.remove('new-center');
      await openCenterSheet(tester);
      await tester.tap(find.text(l.diveCenters_picker_newCenter));
      await tester.pumpAndSettle();

      await tester.tap(find.text('save the center'));
      await tester.pumpAndSettle();

      expect(find.text(l.diveLog_edit_newRecordNotAdded), findsOneWidget);
      // Not an invitation to make it a second time.
      expect(find.text(l.common_error_tryAgain), findsNothing);
      expect(controller.isDirty, isFalse);
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
