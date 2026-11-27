import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/editing/trip_overview_card_editors.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_routes.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_pane_header.dart';

import 'trip_detail_page_unlock_harness.dart';

/// The trip's edit addresses and its list pane's edit open the trip page
/// unlocked behind the phase 3 switch (issue #4527).
void main() {
  final l = AppLocalizationsEn();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  group('addresses', () {
    test('the edit address opens the page unlocked', () {
      expect(tripEditLocation('t1'), '/trips/t1?mode=edit');
    });

    test('moving into the pane keeps an edit address asking for edit', () {
      expect(tripPaneLocation('t1', openUnlocked: false), '/trips?selected=t1');
      expect(
        tripPaneLocation('t1', openUnlocked: true),
        '/trips?selected=t1&mode=edit',
      );
      expect(
        tripPaneLocation(
          't1',
          openUnlocked: true,
          section: TripEditSection.planning,
        ),
        '/trips?selected=t1&mode=edit&section=planning',
      );
      expect(
        tripPaneLocation(
          't1',
          openUnlocked: true,
          noteDay: TripNoteDay(date: DateTime(2030, 6, 2), dayNumber: 2),
        ),
        '/trips?selected=t1&mode=edit&section=notes&noteDate=2030-06-02'
        '&noteDay=2',
      );
    });

    test('the redirect keeps the section and the day', () {
      expect(
        tripEditLocation('t1', section: TripEditSection.planning),
        '/trips/t1?mode=edit&section=planning',
      );
      expect(
        tripEditLocation(
          't1',
          noteDay: TripNoteDay(date: DateTime(2030, 6, 2), dayNumber: 2),
        ),
        '/trips/t1?mode=edit&section=notes&noteDate=2030-06-02&noteDay=2',
      );
    });
  });

  // Review Focus 2 (issue #4527, plan 12): an old address's section and
  // day survive the redirect; a malformed day is dropped, so the trip opens
  // unlocked at no card.
  for (final (from, to) in [
    ('/trips/t1/edit', '/trips/t1?mode=edit'),
    ('/trips/t1/edit?section=planning', '/trips/t1?mode=edit&section=planning'),
    (
      '/trips/t1/edit?section=notes&noteDate=2030-06-02&noteDay=2',
      '/trips/t1?mode=edit&section=notes&noteDate=2030-06-02&noteDay=2',
    ),
    ('/trips/t1/edit?noteDate=2030-02-31&noteDay=2', '/trips/t1?mode=edit'),
  ]) {
    testWidgets('the old address $from lands on $to', (tester) async {
      final router = GoRouter(
        initialLocation: from,
        routes: [
          GoRoute(
            path: '/trips/:tripId',
            builder: (_, state) => Text('TRIP ${state.uri}'),
            routes: [GoRoute(path: 'edit', redirect: tripEditRedirect)],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('TRIP $to'), findsOneWidget);
    });
  }

  testWidgets('opened with mode=edit, the page is unlocked', (tester) async {
    await pumpTripPage(tester, openUnlocked: true);

    expect(find.byType(RecordEditBar), findsOneWidget);
    // At the top, with no card opened for it.
    expect(find.byType(TripPlanCardEditor), findsNothing);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      0,
    );
  });

  testWidgets('opened at section=planning, the Plan card is open and in '
      'view', (tester) async {
    // A phone's height, where the Plan card starts below the fold.
    const phone = Size(400, 700);
    await pumpTripPage(
      tester,
      openUnlocked: true,
      openSection: TripEditSection.planning,
      size: phone,
    );

    expect(find.byType(TripPlanCardEditor), findsOneWidget);
    final top = tester.getRect(find.byType(TripPlanCardEditor)).top;
    expect(top, greaterThanOrEqualTo(0));
    expect(top, lessThan(phone.height));
  });

  testWidgets('opened at a note day, that day is shown with its Day plan '
      'open', (tester) async {
    await pumpTripPage(
      tester,
      trip: redSea.copyWith(
        startDate: today.subtract(const Duration(days: 2)),
        endDate: today.add(const Duration(days: 1)),
      ),
      openUnlocked: true,
      openNoteDay: TripNoteDay(
        date: today.subtract(const Duration(days: 2)),
        dayNumber: 1,
      ),
    );

    final editor = tester.widget<TripDayPlanCardEditor>(
      find.byType(TripDayPlanCardEditor),
    );
    expect(editor.day.dayNumber, 1);
  });

  testWidgets("the pane's edit opens the page unlocked, and Cancel returns "
      'to view', (tester) async {
    var cancelled = 0;
    await pumpTripPage(
      tester,
      embedded: true,
      wrap: (_) => Scaffold(
        body: Builder(
          builder: (context) =>
              tripEditPane(context, 't1', (_) {}, () => cancelled++),
        ),
      ),
    );

    expect(find.byType(RecordEditPaneHeader), findsOneWidget);
    await tester.tap(find.text(l.common_action_cancel).first);
    await tester.pumpAndSettle();

    expect(cancelled, 1);
  });

  testWidgets("the pane's Save updates the trip and creates none", (
    tester,
  ) async {
    final harness = await pumpTripPage(
      tester,
      embedded: true,
      wrap: (_) => Scaffold(
        body: Builder(
          builder: (context) => tripEditPane(context, 't1', (_) {}, () {}),
        ),
      ),
    );
    await tester.tap(
      find.byTooltip(
        l.recordEdit_editCardTooltip(l.trips_detail_sectionTitle_notes),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('trip-edit-notes')), 'Windy');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(harness.save.calls.single.after.id, 't1');
    expect(harness.save.calls.single.after.notes, 'Windy');
  });

  testWidgets('opened at section=planning on a trip under way, the story '
      'shows the Trip page with the Plan card open', (tester) async {
    await pumpTripPage(
      tester,
      trip: redSea.copyWith(
        startDate: today.subtract(const Duration(days: 1)),
        endDate: today.add(const Duration(days: 1)),
      ),
      openUnlocked: true,
      openSection: TripEditSection.planning,
    );

    expect(find.byType(TripPlanCardEditor), findsOneWidget);
  });
}
