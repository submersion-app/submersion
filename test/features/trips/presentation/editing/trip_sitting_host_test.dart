import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_cards.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/editing/trip_itinerary_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_sitting_host.dart';
import 'package:submersion/features/trips/presentation/editing/trip_vessel_sitting.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';

import '../pages/trip_detail_page_unlock_harness.dart';

/// A page with nothing of its own but a sitting on trip `t1`, as the
/// cylinder board is.
class _BareTripPage extends ConsumerStatefulWidget {
  const _BareTripPage();

  @override
  ConsumerState<_BareTripPage> createState() => _BareTripPageState();
}

class _BareTripPageState extends ConsumerState<_BareTripPage>
    with RecordEditHost<_BareTripPage, Trip>, TripSittingHost<_BareTripPage> {
  @override
  String get hostRecordId => 't1';

  @override
  Iterable<EditCard<Trip>> get hostEditCards => tripEditCards.values;

  @override
  List<AddStripEntry> addStripEntries(Trip working) => const [];

  @override
  Widget build(BuildContext context) {
    followStored(tripByIdProvider('t1'));
    final stored = ref.watch(tripByIdProvider('t1')).value;
    if (stored == null) return const SizedBox.shrink();
    final shown = shownRecord(stored);
    return editScaffold(
      record: stored,
      shown: shown,
      lockedBar: AppBar(actions: [lockButton(shown)]),
      content: Text(shown.name),
    );
  }
}

/// What a sitting on a trip loads and how it saves, shared by every page
/// that holds one (issue #4527, phase 3).
void main() {
  final l = AppLocalizationsEn();

  _BareTripPageState hostOf(WidgetTester tester) =>
      tester.state<_BareTripPageState>(find.byType(_BareTripPage));

  Future<TripPageHarness> pumpBare(
    WidgetTester tester, {
    List<ItineraryDay> days = const [],
    List<DiveCandidate> candidates = const [],
  }) => pumpTripPage(
    tester,
    trip: liveaboard,
    vessel: mvBlue,
    days: days,
    candidates: candidates,
    activeDiverId: 'd1',
    wrap: (_) => const _BareTripPage(),
  );

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  testWidgets('unlock loads every held list the trip page loads', (
    tester,
  ) async {
    final june1 = ItineraryDay(
      id: 'i1',
      tripId: 't1',
      dayNumber: 1,
      date: DateTime(2030, 6, 1),
      dayType: DayType.diveDay,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await pumpBare(tester, days: [june1]);
    await unlock(tester);

    final session = hostOf(tester).editController.session!;
    expect(tripItineraryDays().current(session), [june1]);
    expect(tripVesselDetails().current(session), [mvBlue]);
  });

  testWidgets('Save writes one entry with the cards the sitting changed', (
    tester,
  ) async {
    final harness = await pumpBare(tester);
    await unlock(tester);
    hostOf(tester).editController.session!.set(tripLocationField, 'Safaga');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(harness.save.calls, hasLength(1));
    expect(harness.save.calls.single.cards, {'header'});
    expect(harness.save.calls.single.after.location, 'Safaga');
  });

  testWidgets('a changed date asks the dives question once, and its dives '
      'are assigned in the same save', (tester) async {
    final harness = await pumpBare(
      tester,
      candidates: [
        DiveCandidate(
          dive: Dive(id: 'v1', dateTime: DateTime(2030, 5, 31, 9)),
        ),
      ],
    );
    await unlock(tester);
    hostOf(tester).editController.session!.set(tripDatesField, (
      start: DateTime(2030, 5, 30),
      end: DateTime(2030, 6, 8),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.trips_diveScan_addButton(1)));
    await tester.pumpAndSettle();

    expect(harness.tripDives.asked, hasLength(1));
    expect(harness.tripDives.assigned, [
      ['v1'],
    ]);
    expect(harness.save.calls, hasLength(1));
  });
}
