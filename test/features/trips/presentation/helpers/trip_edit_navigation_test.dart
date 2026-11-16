import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';

/// Pumps a button that opens trip t1's edit form, taps it, and returns where
/// the router ends up and whether it stacked a page to get there.
Future<({String location, bool pushed})> _pump(
  WidgetTester tester, {
  required bool embedded,
  TripEditSection? section,
  TripNoteDay? noteDay,
}) async {
  final router = GoRouter(
    initialLocation: '/trips?selected=t1',
    routes: [
      GoRoute(
        path: '/trips',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => openTripEdit(
              context,
              't1',
              embedded: embedded,
              section: section,
              noteDay: noteDay,
            ),
            child: const Text('Edit'),
          ),
        ),
        routes: [
          GoRoute(
            path: ':id/edit',
            builder: (context, state) => const Scaffold(),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
  return (location: router.state.uri.toString(), pushed: router.canPop());
}

void main() {
  group('openTripEdit (#2880)', () {
    testWidgets('in the pane, switches the pane to edit mode', (tester) async {
      final r = await _pump(tester, embedded: true);
      expect(r.location, '/trips?selected=t1&mode=edit');
      expect(r.pushed, isFalse);
    });

    testWidgets('in the pane, carries the section', (tester) async {
      final r = await _pump(
        tester,
        embedded: true,
        section: TripEditSection.planning,
      );
      expect(r.location, '/trips?selected=t1&mode=edit&section=planning');
      expect(r.pushed, isFalse);
    });

    testWidgets('as a page, pushes the edit page', (tester) async {
      final r = await _pump(tester, embedded: false);
      expect(r.location, '/trips/t1/edit');
      expect(r.pushed, isTrue);
    });

    testWidgets('as a page, carries the section', (tester) async {
      final r = await _pump(
        tester,
        embedded: false,
        section: TripEditSection.planning,
      );
      expect(r.location, '/trips/t1/edit?section=planning');
      expect(r.pushed, isTrue);
    });
  });

  group('a day note (#4625)', () {
    final day3 = TripNoteDay(date: DateTime(2026, 11, 5), dayNumber: 3);

    testWidgets('as a page, opens the notes at the day', (tester) async {
      final r = await _pump(tester, embedded: false, noteDay: day3);
      expect(
        r.location,
        '/trips/t1/edit?section=notes&noteDate=2026-11-05&noteDay=3',
      );
    });

    testWidgets('in the pane, opens the notes at the day', (tester) async {
      final r = await _pump(tester, embedded: true, noteDay: day3);
      expect(
        r.location,
        '/trips?selected=t1&mode=edit&section=notes'
        '&noteDate=2026-11-05&noteDay=3',
      );
    });

    test('the query reads back the day it was written from', () {
      expect(tripNoteDayFromQuery(tripNoteDayQuery(day3)), day3);
    });

    test('a missing or malformed day reads as none', () {
      expect(tripNoteDayFromQuery(const {}), isNull);
      expect(tripNoteDayFromQuery(const {'noteDate': '2026-11-05'}), isNull);
      expect(
        tripNoteDayFromQuery(const {'noteDate': 'x', 'noteDay': '3'}),
        isNull,
      );
      expect(
        tripNoteDayFromQuery(const {'noteDate': '2026-11-05', 'noteDay': 'x'}),
        isNull,
      );
    });

    test('an impossible date or a day number below 1 reads as none', () {
      expect(
        tripNoteDayFromQuery(const {'noteDate': '2026-02-31', 'noteDay': '3'}),
        isNull,
      );
      expect(
        tripNoteDayFromQuery(const {'noteDate': '2026-13-01', 'noteDay': '3'}),
        isNull,
      );
      expect(
        tripNoteDayFromQuery(const {'noteDate': '2026-11-05', 'noteDay': '0'}),
        isNull,
      );
    });

    test('reads the notes section by name', () {
      expect(TripEditSection.fromQuery('notes'), TripEditSection.notes);
    });
  });

  group('TripEditSection.fromQuery', () {
    test('reads a section by name', () {
      expect(TripEditSection.fromQuery('planning'), TripEditSection.planning);
    });

    test('is null for a missing or unknown section', () {
      expect(TripEditSection.fromQuery(null), isNull);
      expect(TripEditSection.fromQuery('bogus'), isNull);
    });
  });
}
