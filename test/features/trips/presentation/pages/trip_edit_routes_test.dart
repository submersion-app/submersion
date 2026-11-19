import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/editing/trip_overview_card_editors.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
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
    test('the edit address redirects with the switch on, not off', () {
      expect(tripEditLocation('t1'), isNull);
      expect(
        tripEditLocation('t1', unlockEditing: true),
        '/trips/t1?mode=edit',
      );
    });

    test('the redirect keeps the section and the day', () {
      expect(
        tripEditLocation(
          't1',
          section: TripEditSection.planning,
          unlockEditing: true,
        ),
        '/trips/t1?mode=edit&section=planning',
      );
      expect(
        tripEditLocation(
          't1',
          noteDay: TripNoteDay(date: DateTime(2030, 6, 2), dayNumber: 2),
          unlockEditing: true,
        ),
        '/trips/t1?mode=edit&section=notes&noteDate=2030-06-02&noteDay=2',
      );
    });
  });

  testWidgets('opened with mode=edit, the page is unlocked', (tester) async {
    await pumpTripPage(tester, openUnlocked: true);

    expect(find.byType(RecordEditBar), findsOneWidget);
  });

  testWidgets('opened at section=planning, the Plan card is open and in '
      'view', (tester) async {
    await pumpTripPage(
      tester,
      openUnlocked: true,
      openSection: TripEditSection.planning,
    );

    expect(find.byType(TripPlanCardEditor), findsOneWidget);
    expect(tester.getRect(find.byType(TripPlanCardEditor)).top, lessThan(1600));
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
          builder: (context) => tripEditPane(
            context,
            't1',
            (_) {},
            () => cancelled++,
            unlockEditing: true,
          ),
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
          builder: (context) =>
              tripEditPane(context, 't1', (_) {}, () {}, unlockEditing: true),
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

  testWidgets('with the switch off the pane opens the form', (tester) async {
    late Widget pane;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          pane = tripEditPane(
            context,
            't1',
            (_) {},
            () {},
            unlockEditing: false,
          );
          return const SizedBox();
        },
      ),
    );

    expect(pane, isA<TripEditPage>());
    expect((pane as TripEditPage).tripId, 't1');
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
