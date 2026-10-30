import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_journal.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_buddy_writer.dart';

import '../../../../helpers/test_database.dart';

SuuntoParsedDive _parsed(List<String> buddies) => SuuntoParsedDive(
  dive: DownloadedDive(
    startTime: DateTime.utc(2026, 10, 7, 17, 39, 17),
    durationSeconds: 2340,
    maxDepth: 7.3,
    profile: const [],
  ),
  deviceName: 'Suunto Nautic',
  serialNumber: 'NS-1',
  journal: SuuntoJournal(buddies: buddies),
);

/// Issue #3266: the people logged on a Suunto workout become the dive's
/// buddies, matched by name or created, without disturbing anyone already
/// on the dive.
void main() {
  late AppDatabase db;
  late BuddyRepository repo;
  late SuuntoBuddyWriter writer;

  const diverId = 'diver-1';

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('$diverId', 'Me', 1000, 1000), "
      "('diver-2', 'Someone else', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
      "updated_at) VALUES ('d1', '$diverId', 1000, 1000, 1000)",
    );
    repo = BuddyRepository();
    writer = SuuntoBuddyWriter(repository: repo);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<List<BuddyWithRole>> onDive() => repo.getBuddiesForDive('d1');

  test('creates each named person for the diver as a Buddy', () async {
    await writer.attach('d1', _parsed(['Buddy 1', 'Buddy 2']), diverId);

    final linked = await onDive();
    expect(
      linked.map((b) => b.buddy.name),
      unorderedEquals(['Buddy 1', 'Buddy 2']),
    );
    expect(linked.every((b) => b.buddy.diverId == diverId), isTrue);
    expect(linked.every((b) => b.roleIds.single == DiveRole.buddyId), isTrue);
  });

  test('reuses the diver\'s person with that name, ignoring case', () async {
    final existing = await repo.createBuddy(
      Buddy(
        id: 'b-ann',
        diverId: diverId,
        name: 'Ann Diver',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    await writer.attach('d1', _parsed(['ann diver']), diverId);

    expect((await onDive()).single.buddy.id, existing.id);
    expect(await repo.getAllBuddies(diverId: diverId), hasLength(1));
  });

  test('never links another diver\'s namesake', () async {
    await repo.createBuddy(
      Buddy(
        id: 'b-other',
        diverId: 'diver-2',
        name: 'Buddy 1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    await writer.attach('d1', _parsed(['Buddy 1']), diverId);

    final linked = (await onDive()).single.buddy;
    expect(linked.id, isNot('b-other'));
    expect(linked.diverId, diverId);
  });

  test('keeps the role of someone already on the dive', () async {
    final guide = await repo.createBuddy(
      Buddy(
        id: 'b-guide',
        diverId: diverId,
        name: 'Buddy 1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await repo.addBuddyToDive('d1', guide.id, DiveRole.diveGuideId);

    await writer.attach('d1', _parsed(['Buddy 1', 'Buddy 2']), diverId);

    final linked = await onDive();
    expect(linked, hasLength(2));
    final kept = linked.firstWhere((b) => b.buddy.id == guide.id);
    expect(kept.roleIds, [DiveRole.diveGuideId]);
  });

  test('leaves a name already on the dive alone, whoever it is', () async {
    // findOrCreateByName would pick or create a different person (another
    // profile's namesake here), so an id-only check would list the name
    // twice on the dive.
    final namesake = await repo.createBuddy(
      Buddy(
        id: 'b-other',
        diverId: 'diver-2',
        name: 'Buddy 1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await repo.addBuddyToDive('d1', namesake.id, DiveRole.buddyId);

    await writer.attach('d1', _parsed(['buddy 1', 'Buddy 2']), diverId);

    final linked = await onDive();
    expect(
      linked.map((b) => b.buddy.name),
      unorderedEquals(['Buddy 1', 'Buddy 2']),
    );
    expect(
      linked.firstWhere((b) => b.buddy.name == 'Buddy 1').buddy.id,
      namesake.id,
    );
  });

  test('importing the same dive again adds nobody twice', () async {
    await writer.attach('d1', _parsed(['Buddy 1']), diverId);
    await writer.attach('d1', _parsed(['Buddy 1']), diverId);

    expect(await onDive(), hasLength(1));
    expect(await repo.getAllBuddies(diverId: diverId), hasLength(1));
  });

  test('does nothing for a workout with no buddies', () async {
    await writer.attach('d1', _parsed(const []), diverId);

    expect(await onDive(), isEmpty);
    expect(await repo.getAllBuddies(diverId: diverId), isEmpty);
  });

  test('logs rather than throws when the dive cannot be read', () async {
    // The dive is already saved by now, so losing its buddies must not fail
    // the import or stop the dives after this one.
    final failing = SuuntoBuddyWriter(repository: _UnreadableDiveRepository());

    await expectLater(
      failing.attach('d1', _parsed(['Buddy 1']), diverId),
      completes,
    );
  });

  test('one person failing to save still links the others', () async {
    final failing = SuuntoBuddyWriter(
      repository: _FailingNameRepository('Buddy 1'),
    );

    await failing.attach('d1', _parsed(['Buddy 1', 'Buddy 2']), diverId);

    expect((await onDive()).single.buddy.name, 'Buddy 2');
  });
}

class _UnreadableDiveRepository extends BuddyRepository {
  @override
  Future<Map<String, List<BuddyWithRole>>> getBuddiesForDives(
    List<String> diveIds,
  ) async => throw StateError('database closed');
}

class _FailingNameRepository extends BuddyRepository {
  _FailingNameRepository(this.failingName);

  final String failingName;

  @override
  Future<Buddy> findOrCreateByName(
    String name, {
    String? notes,
    String? diverId,
  }) async {
    if (name == failingName) throw StateError('disk full');
    return super.findOrCreateByName(name, notes: notes, diverId: diverId);
  }
}
