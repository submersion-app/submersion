import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_header_card_editor.dart';
import 'package:submersion/features/trips/presentation/editing/trip_new_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// A new trip's sitting (issue #4527, phase 3, plan 11): its seed, its
/// sharing, and a draft from selected dives.
void main() {
  ProviderContainer container({bool shared = false}) {
    final c = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        shareByDefaultProvider.overrideWith((ref) async => shared),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a seed is shore, eight calendar days, shared by default, with no '
      'dot', () async {
    final now = DateTime(2026, 3, 10, 9, 30);
    final seed = await withClock(
      Clock.fixed(now),
      () => newTripSeed(container(shared: true).read, id: 'n1'),
    );

    expect(seed.id, 'n1');
    expect(seed.diverId, 'me');
    expect(seed.tripType, TripType.shore);
    expect(seed.startDate, now);
    expect(seed.endDate, DateTime(2026, 3, 17, 9, 30));
    expect(seed.durationDays, 8);
    expect(seed.isShared, isTrue);
    // No plan yet: the planning numbers are none, one diver per cylinder.
    expect(seed.expectedDives, isNull);
    expect(seed.expectedRuntimeMinutes, isNull);
    expect(seed.divesPerDayTarget, isNull);
    expect(seed.diversSharingCylinders, 1);
    expect(EditSession(seed, isNew: true).isDirty, isFalse);
  });

  // A week holding a change of clock (New York falls back on 1 November
  // 2026), opened just after midnight: seven calendar days on, not seven
  // days of elapsed time, which would end the evening before. CI runs this
  // file under America/New_York in its Timezone Tests job.
  test('a seed opened just after midnight in a week the clocks change is '
      'eight calendar days', () async {
    final now = DateTime(2026, 10, 26, 0, 30);
    final seed = await withClock(
      Clock.fixed(now),
      () => newTripSeed(container(shared: true).read, id: 'n1'),
    );

    expect(seed.endDate, DateTime(2026, 11, 2, 0, 30));
    expect(seed.durationDays, 8);
  });

  // Sharing is decided by the owner, so a new trip's page cannot open, and
  // its sharing cannot be offered, before the active profile is known
  // (issue #2151).
  test('a seed waits for the active profile, and is that profile\'s', () async {
    final profile = Completer<String?>();
    final c = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) => profile.future),
        shareByDefaultProvider.overrideWith((ref) async => false),
      ],
    );
    addTearDown(c.dispose);
    var made = false;
    final seed = newTripSeed(c.read, id: 'n1')..then((_) => made = true);

    await Future<void>.delayed(Duration.zero);
    expect(made, isFalse);
    profile.complete('d1');

    expect((await seed).diverId, 'd1');
  });

  test('sharing by default arrives before the sitting opens', () async {
    final c = container(shared: true);
    final session = EditSession(
      await newTripSeed(c.read, id: 'n1'),
      isNew: true,
    );
    addTearDown(session.dispose);

    await loadTripSharing(session, c.read);

    expect(tripSharing.unread(session), isFalse);
    expect(tripSharing.loaded(session), ItemSharing.all);
    expect(session.isDirty, isFalse);
  });

  test('a new trip lays out its header and notes, and a liveaboard its '
      'vessel', () {
    final shore = Trip(
      id: 'n1',
      name: '',
      startDate: DateTime(2026),
      endDate: DateTime(2026),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    expect(newTripLaidOut(shore), [
      TripCardId.header.name,
      TripCardId.notes.name,
    ]);
    expect(
      newTripLaidOut(shore.copyWith(tripType: TripType.liveaboard)),
      contains(TripCardId.vessel.name),
    );
  });

  test("a draft's values are changes of the header block", () async {
    final session = EditSession(
      await newTripSeed(container().read, id: 'n1'),
      isNew: true,
    );
    addTearDown(session.dispose);
    final draft = TripDraft(
      trip: Trip(
        id: '',
        name: 'Bonaire 2026',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 4),
        location: 'Bonaire',
        resortName: 'Buddy Dive',
        parentTripId: 'p1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      diveIds: const ['a', 'b'],
    );

    applyNewTripPrefill(session, draft);

    final working = session.working;
    expect(working.name, 'Bonaire 2026');
    expect(working.startDate, DateTime(2026, 9, 1));
    expect(working.endDate, DateTime(2026, 9, 4));
    expect(working.location, 'Bonaire');
    expect(working.resortName, 'Buddy Dive');
    expect(working.parentTripId, 'p1');
    expect(session.changedCardIds, {TripCardId.header.name});
  });

  test('no draft changes nothing', () async {
    final session = EditSession(
      await newTripSeed(container().read, id: 'n1'),
      isNew: true,
    );
    addTearDown(session.dispose);

    applyNewTripPrefill(session, null);

    expect(session.isDirty, isFalse);
  });
}
