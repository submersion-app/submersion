import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/editing/trip_header_card_editor.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/overview/trip_prepare_overview.dart';
import 'package:submersion/features/trips/presentation/widgets/part_of_trip_field.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_trip_page.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../pages/trip_detail_page_unlock_harness.dart';

/// The trip page's header block edited in place (issue #4527, phase 3):
/// the form's header values and rules, and who the trip is shared with.
void main() {
  final l = AppLocalizationsEn();
  final header = l.settings_conflict_ref_trip;

  Future<void> openHeader(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l.recordEdit_editCardTooltip(header)));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  /// Opens the date picker of [tile], types [date] (month/day/year) into
  /// it and confirms.
  Future<void> pickDate(WidgetTester tester, String tile, String date) async {
    await tester.tap(find.byKey(Key(tile)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      ),
      date,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  EditSession<Trip> sessionOf(WidgetTester tester) {
    final element = tester.element(find.byType(RecordCardFrame<Trip>).first);
    return RecordEditScope.maybeOf<Trip>(element)!.session!;
  }

  group('values', () {
    testWidgets('the header editor shows every header value', (tester) async {
      await pumpTripPage(
        tester,
        trip: redSea.copyWith(
          resortName: 'Oasis',
          liveaboardName: 'MV Old',
          returnFlightAt: DateTime.utc(2030, 6, 9, 14, 30),
        ),
      );
      await openHeader(tester);

      String text(String key) =>
          tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
      expect(text('trip-edit-name'), 'Red Sea');
      expect(text('trip-edit-location'), 'Hurghada');
      expect(text('trip-edit-resort'), 'Oasis');
      expect(text('trip-edit-liveaboard-name'), 'MV Old');
      expect(find.byKey(const Key('trip-edit-start')), findsOneWidget);
      expect(find.byKey(const Key('trip-edit-end')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TripHeaderCardEditor),
          matching: find.text(l.trips_edit_returnFlightNotSet),
        ),
        findsNothing,
      );
      expect(find.byTooltip(l.trips_edit_returnFlightClear), findsOneWidget);
    });

    testWidgets('each value sets only the header card', (tester) async {
      final harness = await pumpTripPage(tester);
      await openHeader(tester);
      await tester.enterText(
        find.byKey(const Key('trip-edit-location')),
        'Safaga',
      );
      await tester.enterText(
        find.byKey(const Key('trip-edit-resort')),
        'Oasis',
      );
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls.single.cards, {'header'});
      expect(harness.save.calls.single.after.location, 'Safaga');
      expect(harness.save.calls.single.after.resortName, 'Oasis');
    });

    testWidgets('choosing Day Trip collapses the dates', (tester) async {
      await pumpTripPage(tester);
      await openHeader(tester);

      await tester.tap(find.text(l.trips_type_dayTrip));
      await tester.pumpAndSettle();

      final working = sessionOf(tester).working;
      expect(working.tripType, TripType.dayTrip);
      expect(working.endDate, working.startDate);
      expect(find.text(l.trips_type_description_dayTrip), findsOneWidget);
    });

    testWidgets('leaving Day Trip keeps the dates', (tester) async {
      final day = redSea.copyWith(
        tripType: TripType.dayTrip,
        endDate: redSea.startDate,
      );
      await pumpTripPage(tester, trip: day);
      await openHeader(tester);

      await tester.tap(find.text(l.trips_type_resort));
      await tester.pumpAndSettle();

      expect(sessionOf(tester).working.endDate, day.startDate);
    });

    testWidgets('a one-day Day Trip locks its end date', (tester) async {
      await pumpTripPage(
        tester,
        trip: redSea.copyWith(
          tripType: TripType.dayTrip,
          endDate: redSea.startDate,
        ),
      );
      await openHeader(tester);

      final end = tester.widget<ListTile>(
        find.byKey(const Key('trip-edit-end')),
      );
      expect(end.enabled, isFalse);
    });

    testWidgets('a stored multi-day Day Trip keeps its end editable', (
      tester,
    ) async {
      await pumpTripPage(
        tester,
        trip: redSea.copyWith(tripType: TripType.dayTrip),
      );
      await openHeader(tester);

      final end = tester.widget<ListTile>(
        find.byKey(const Key('trip-edit-end')),
      );
      expect(end.enabled, isTrue);
    });

    testWidgets("the editor's duration counts calendar days across a "
        'spring-forward', (tester) async {
      await pumpTripPage(
        tester,
        // Evening to morning: elapsed time floors to one day in any zone,
        // the calendar counts three.
        trip: redSea.copyWith(
          startDate: DateTime(2030, 3, 9, 18),
          endDate: DateTime(2030, 3, 11, 9),
        ),
      );
      await openHeader(tester);

      expect(find.text(l.trips_edit_durationDays(3)), findsOneWidget);
    });

    testWidgets('tapping the start date opens the date picker', (tester) async {
      await pumpTripPage(tester);
      await openHeader(tester);

      await tester.tap(find.byKey(const Key('trip-edit-start')));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('the end date picker opens at no earlier than the start', (
      tester,
    ) async {
      await pumpTripPage(tester);
      await openHeader(tester);

      await tester.tap(find.byKey(const Key('trip-edit-end')));
      await tester.pumpAndSettle();

      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, redSea.startDate);
    });

    testWidgets('clearing the return flight is a change', (tester) async {
      final harness = await pumpTripPage(
        tester,
        trip: redSea.copyWith(returnFlightAt: DateTime.utc(2030, 6, 9, 12)),
      );
      await openHeader(tester);

      await tester.tap(find.byTooltip(l.trips_edit_returnFlightClear));
      await tester.pumpAndSettle();
      await save(tester);

      expect(harness.save.calls.single.after.returnFlightAt, isNull);
    });

    testWidgets('a trip without side trips offers a larger trip', (
      tester,
    ) async {
      await pumpTripPage(tester);
      await openHeader(tester);

      expect(find.byType(PartOfTripField), findsOneWidget);
    });

    testWidgets('a start picked in the dialog is held and shown', (
      tester,
    ) async {
      await pumpTripPage(tester);
      await openHeader(tester);

      await pickDate(tester, 'trip-edit-start', '05/20/2030');

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(sessionOf(tester).working.startDate, DateTime(2030, 5, 20));
      // In the diver's date format, the picked date, not the stored one.
      const format = UnitFormatter(AppSettings());
      Finder onStartTile(DateTime date) => find.descendant(
        of: find.byKey(const Key('trip-edit-start')),
        matching: find.text(format.formatDate(date)),
      );
      expect(onStartTile(DateTime(2030, 5, 20)), findsOneWidget);
      expect(onStartTile(redSea.startDate), findsNothing);
    });

    testWidgets('a Day Trip moves its end with a start picked', (tester) async {
      await pumpTripPage(
        tester,
        trip: redSea.copyWith(
          tripType: TripType.dayTrip,
          endDate: redSea.startDate,
        ),
      );
      await openHeader(tester);

      await pickDate(tester, 'trip-edit-start', '05/20/2030');

      final working = sessionOf(tester).working;
      expect(working.startDate, DateTime(2030, 5, 20));
      expect(working.endDate, working.startDate);
    });

    testWidgets('a return flight is set through the date and time pickers', (
      tester,
    ) async {
      await pumpTripPage(tester);
      await openHeader(tester);
      expect(
        find.descendant(
          of: find.byType(TripHeaderCardEditor),
          matching: find.text(l.trips_edit_returnFlightNotSet),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('trip-edit-return-flight')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byTooltip(l.trips_edit_returnFlightClear), findsOneWidget);
      // Wall clock as UTC: the end day at noon, the time picked.
      expect(
        sessionOf(tester).working.returnFlightAt,
        DateTime.utc(2030, 6, 8, 12),
      );
    });

    testWidgets('a larger trip chosen is written at Save', (tester) async {
      final indonesia = Trip(
        id: 'p2',
        diverId: 'd1',
        name: 'Indonesia',
        startDate: DateTime(2030, 5, 1),
        endDate: DateTime(2030, 7, 1),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final harness = await pumpTripPage(
        tester,
        extraOverrides: [
          allTripsProvider.overrideWith((ref) async => [redSea, indonesia]),
        ],
      );
      await openHeader(tester);

      await tester.tap(find.text(l.trips_edit_field_partOf));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Indonesia').last);
      await tester.pumpAndSettle();
      await save(tester);

      final call = harness.save.calls.single;
      expect(call.after.parentTripId, 'p2');
      expect(call.cards, {'header'});
    });

    testWidgets('a trip with side trips offers no larger trip', (tester) async {
      await pumpTripPage(tester, hasSideTrips: true);
      await openHeader(tester);

      expect(find.byType(PartOfTripField), findsNothing);
    });

    testWidgets('a blank name cannot be saved', (tester) async {
      final harness = await pumpTripPage(tester);
      await openHeader(tester);
      await tester.enterText(find.byKey(const Key('trip-edit-name')), ' ');
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls, isEmpty);
      expect(find.text(l.trips_edit_validation_nameRequired), findsOneWidget);
      expect(find.byType(RecordEditBar), findsOneWidget);
    });
  });

  group('sharing', () {
    testWidgets('hidden with one diver', (tester) async {
      await pumpTripPage(tester, activeDiverId: 'd1');
      await openHeader(tester);

      expect(find.text(l.sharedItems_sharedWith_label), findsNothing);
    });

    testWidgets('open for the owner, and a change is written at Save', (
      tester,
    ) async {
      final harness = await pumpTripPage(
        tester,
        divers: twoDivers,
        activeDiverId: 'd1',
      );
      await openHeader(tester);
      final field = tester.widget<ItemSharingField>(
        find.byType(ItemSharingField),
      );
      expect(field.mayShare, isTrue);

      field.onChanged(ItemSharing.all);
      await tester.pumpAndSettle();
      expect(harness.shares.setCalls, isEmpty);
      await save(tester);

      expect(harness.shares.setCalls.single, ('t1', ItemSharing.all));
      expect(harness.save.calls.single.cards, {'header'});
    });

    testWidgets('locked for another profile, naming the owner', (tester) async {
      await pumpTripPage(tester, divers: twoDivers, activeDiverId: 'd2');
      await openHeader(tester);

      final field = tester.widget<ItemSharingField>(
        find.byType(ItemSharingField),
      );
      expect(field.mayShare, isFalse);
      expect(field.ownerId, 'd1');
    });

    testWidgets('locked while a profile switch reads the profile again', (
      tester,
    ) async {
      final active = GatedActiveProfile.settled('d1');
      await pumpTripPage(
        tester,
        divers: twoDivers,
        extraOverrides: [
          validatedCurrentDiverIdProvider.overrideWith((_) => active.read()),
        ],
      );
      await openHeader(tester);
      ItemSharingField field() =>
          tester.widget<ItemSharingField>(find.byType(ItemSharingField));
      expect(field().mayShare, isTrue);

      ProviderScope.containerOf(
        tester.element(find.byType(ItemSharingField)),
      ).invalidate(validatedCurrentDiverIdProvider);
      await tester.pump();
      expect(field().mayShare, isNull);

      active.settle('d2');
      await tester.pumpAndSettle();
      expect(field().mayShare, isFalse);
    });

    testWidgets('locked while the profile cannot be read', (tester) async {
      await pumpTripPage(
        tester,
        divers: twoDivers,
        extraOverrides: [
          validatedCurrentDiverIdProvider.overrideWith(
            (_) => Future<String?>.error(StateError('no profile')),
          ),
        ],
      );
      await openHeader(tester);

      expect(
        tester.widget<ItemSharingField>(find.byType(ItemSharingField)).mayShare,
        isNull,
      );
    });

    testWidgets('locked while the sharing cannot be read', (tester) async {
      await pumpTripPage(
        tester,
        divers: twoDivers,
        activeDiverId: 'd1',
        shares: _UnreadableShares(),
      );
      await openHeader(tester);

      final field = tester.widget<ItemSharingField>(
        find.byType(ItemSharingField),
      );
      expect(field.mayShare, isNull);
    });

    testWidgets('a failed read never unshares at Save', (tester) async {
      final shares = _UnreadableShares();
      final harness = await pumpTripPage(
        tester,
        trip: redSea.copyWith(isShared: true),
        divers: twoDivers,
        activeDiverId: 'd1',
        shares: shares,
      );
      await openHeader(tester);
      await tester.enterText(find.byKey(const Key('trip-edit-name')), 'Egypt');
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls, hasLength(1));
      expect(shares.setCalls, isEmpty);
    });

    testWidgets('unchanged sharing holds nothing', (tester) async {
      final harness = await pumpTripPage(
        tester,
        divers: twoDivers,
        activeDiverId: 'd1',
      );
      await openHeader(tester);
      await tester.enterText(find.byKey(const Key('trip-edit-name')), 'Egypt');
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.shares.setCalls, isEmpty);
    });

    testWidgets("a stale share row is rewritten by the owner's Save", (
      tester,
    ) async {
      final shares = FakeItemShares({'t1': ItemSharing.all})
        ..staleRows['t1'] = {'d2'};
      await pumpTripPage(
        tester,
        divers: twoDivers,
        activeDiverId: 'd1',
        shares: shares,
      );
      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();
      sessionOf(tester).set(tripNotesField, 'Windy');
      await tester.pumpAndSettle();

      await save(tester);

      expect(shares.setCalls.single, ('t1', ItemSharing.all));
    });

    testWidgets('a refused change fails the whole Save with the sharing '
        'message and writes nothing', (tester) async {
      final shares = FakeItemShares()..refuseSet = true;
      final harness = await pumpTripPage(
        tester,
        divers: twoDivers,
        activeDiverId: 'd1',
        shares: shares,
      );
      await openHeader(tester);
      tester
          .widget<ItemSharingField>(find.byType(ItemSharingField))
          .onChanged(ItemSharing.all);
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls, isEmpty);
      expect(find.text(sharingRefusedMessage(l)), findsOneWidget);
      expect(find.byType(RecordEditBar), findsOneWidget);
    });
  });

  testWidgets('locked, the header shows location, resort and the type only '
      'when set', (tester) async {
    await pumpTripPage(
      tester,
      trip: redSea.copyWith(resortName: 'Oasis', tripType: TripType.resort),
    );

    expect(find.text('Hurghada'), findsOneWidget);
    expect(find.text('Oasis'), findsOneWidget);
    expect(find.text(l.trips_type_resort), findsOneWidget);
  });

  testWidgets('locked, a liveaboard with none of them shows no header rows', (
    tester,
  ) async {
    await pumpTripPage(tester, trip: liveaboard.copyWith(location: null));

    expect(find.byKey(const Key('trip-header-rows')), findsNothing);
  });

  testWidgets('locked, blank header values draw no rows', (tester) async {
    await pumpTripPage(
      tester,
      trip: liveaboard.copyWith(location: '  ', resortName: ''),
    );

    expect(find.byKey(const Key('trip-header-rows')), findsNothing);
  });

  // The trip-wide details sit with the rest of the trip summary, not above
  // the tab row on every tab (issue #4927).
  group('where the details sit', () {
    final resort = redSea.copyWith(
      resortName: 'Oasis',
      tripType: TripType.resort,
    );
    final line = find.byKey(const Key('trip-header-rows'));

    testWidgets('before departure, on the prepare page under the hero', (
      tester,
    ) async {
      await pumpTripPage(tester, trip: resort);

      expect(
        find.descendant(of: find.byType(TripPrepareOverview), matching: line),
        findsOneWidget,
      );
      expect(
        tester.getRect(line).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(TripStoryHero)).bottom),
      );
      expect(
        tester.getRect(line).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(TabBar)).bottom),
      );
    });

    testWidgets("from the first day, on the story's Trip page", (tester) async {
      await pumpTripPage(
        tester,
        trip: resort.copyWith(
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 8),
        ),
      );

      expect(
        find.descendant(of: find.byType(TripStoryTripPage), matching: line),
        findsOneWidget,
      );
      expect(
        tester.getRect(line).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(TabBar)).bottom),
      );
    });

    testWidgets('on one compact line, each value read with its label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpTripPage(tester, trip: resort);

      expect(
        tester.getCenter(find.text('Hurghada')).dy,
        tester.getCenter(find.text('Oasis')).dy,
      );
      expect(
        tester.getCenter(find.text(l.trips_type_resort)).dy,
        tester.getCenter(find.text('Oasis')).dy,
      );
      expect(
        find.bySemanticsLabel('${l.trips_edit_label_location}: Hurghada'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('${l.trips_edit_label_resortName}: Oasis'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('not on the other tabs', (tester) async {
      await pumpTripPage(tester, trip: resort);

      await tester.tap(find.widgetWithText(Tab, l.trips_detail_tab_gear));
      await tester.pumpAndSettle();

      expect(find.text('Hurghada'), findsNothing);
      expect(line, findsNothing);
    });
  });

  testWidgets('the sharing field appears when its read lands after the '
      'header opened', (tester) async {
    final shares = _SlowShares();
    await pumpTripPage(
      tester,
      divers: twoDivers,
      activeDiverId: 'd1',
      shares: shares,
    );
    await openHeader(tester);
    expect(find.byType(ItemSharingField), findsNothing);

    shares.answer();
    await tester.pumpAndSettle();

    expect(find.byType(ItemSharingField), findsOneWidget);
  });

  testWidgets("the prepare page's hero shows the name the sitting holds", (
    tester,
  ) async {
    await pumpTripPage(tester);
    await openHeader(tester);
    await tester.enterText(find.byKey(const Key('trip-edit-name')), 'Egypt');
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(TripStoryHero),
        matching: find.text('Egypt'),
      ),
      findsOneWidget,
    );
  });
}

/// Who items are shared with, answered only when the test says.
class _SlowShares extends FakeItemShares {
  final _gate = Completer<void>();

  void answer() => _gate.complete();

  @override
  Future<ItemSharing> sharingOf(SharedItemKind kind, String id) async {
    await _gate.future;
    return ItemSharing.none;
  }
}

/// Who items are shared with cannot be read.
class _UnreadableShares extends FakeItemShares {
  @override
  Future<ItemSharing> sharingOf(SharedItemKind kind, String id) async =>
      throw StateError('the read failed');
}
