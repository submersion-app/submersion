import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  /// Seeds the five recorded-signal shapes the deco axis has to tell apart.
  Future<void> seedDives() async {
    await repository.createDive(
      domain.Dive(
        id: 'stop',
        dateTime: DateTime(2026, 1, 1),
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 30, decoType: 0),
          domain.DiveProfilePoint(timestamp: 60, depth: 30, decoType: 2),
        ],
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'noStop',
        dateTime: DateTime(2026, 1, 2),
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 18, decoType: 0),
        ],
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'ceilingOnly',
        dateTime: DateTime(2026, 1, 3),
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 30, ceiling: 3),
        ],
      ),
    );
    // A computer that logs the deco stop as an event without ever writing
    // deco_type or ceiling onto the profile samples.
    await repository.createDive(
      domain.Dive(
        id: 'eventOnly',
        dateTime: DateTime(2026, 1, 4),
        profile: const [domain.DiveProfilePoint(timestamp: 0, depth: 30)],
      ),
    );
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: const Value('e-1'),
            diveId: const Value('eventOnly'),
            timestamp: const Value(0),
            eventType: const Value('decoStopStart'),
            createdAt: Value(DateTime(2026, 1, 4).millisecondsSinceEpoch),
          ),
        );
    await repository.createDive(
      domain.Dive(id: 'unrecorded', dateTime: DateTime(2026, 1, 5)),
    );
  }

  test('getDiveSummaries classifies every recorded deco signal', () async {
    await seedDives();

    final decoResults = await repository.getDiveSummaries(
      filter: const DiveFilterState(decoOnly: true),
    );
    expect(decoResults.map((d) => d.id).toSet(), {
      'stop',
      'ceilingOnly',
      'eventOnly',
    });

    final noDecoResults = await repository.getDiveSummaries(
      filter: const DiveFilterState(decoOnly: false),
    );
    expect(noDecoResults.map((d) => d.id).toSet(), {'noStop'});
  });

  test('getDiveIdsWithDecoSignal agrees with the paginated SQL path', () async {
    await seedDives();

    expect(await repository.getDiveIdsWithDecoSignal(wantDeco: true), {
      'stop',
      'ceilingOnly',
      'eventOnly',
    });
    expect(await repository.getDiveIdsWithDecoSignal(wantDeco: false), {
      'noStop',
    });
  });

  test('getDiveIdsWithDecoSignal honours the diver scope', () async {
    final diverRepo = DiverRepository();
    Future<String> makeDiver(String name) async {
      final diver = await diverRepo.createDiver(
        domain.Diver(
          id: '',
          name: name,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      return diver.id;
    }

    final diverA = await makeDiver('A');
    final diverB = await makeDiver('B');

    await repository.createDive(
      domain.Dive(
        id: 'mine',
        diverId: diverA,
        dateTime: DateTime(2026, 1, 1),
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 30, decoType: 2),
        ],
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'theirs',
        diverId: diverB,
        dateTime: DateTime(2026, 1, 2),
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 30, decoType: 2),
        ],
      ),
    );

    expect(
      await repository.getDiveIdsWithDecoSignal(
        wantDeco: true,
        diverId: diverA,
      ),
      {'mine'},
    );
  });

  test(
    'getAllDives leaves profiles unhydrated, so apply() cannot classify deco',
    () async {
      await seedDives();

      final dives = await repository.getAllDives();

      // The premise the SQL-backed deco axis exists for: list views carry no
      // profile points at all, which is why DiveFilterState.apply deliberately
      // ignores decoOnly instead of matching nothing.
      expect(dives, isNotEmpty);
      expect(dives.every((d) => d.profile.isEmpty), isTrue);
      expect(
        const DiveFilterState(decoOnly: true).apply(dives).map((d) => d.id),
        dives.map((d) => d.id),
      );
    },
  );
}
