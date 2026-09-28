import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

import '../../../helpers/test_database.dart';

const _ms = 1700000000000;

/// Two profiles, and entities owned by each, by nobody, and shared across.
Future<void> _seed(db.AppDatabase d) async {
  await d.batch((b) {
    for (final id in ['me', 'other']) {
      b.insert(
        d.divers,
        db.DiversCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(_ms),
          updatedAt: const Value(_ms),
        ),
      );
    }
    for (final (id, owner) in [
      ('mine', 'me'),
      ('theirs', 'other'),
      ('nobodys', null),
    ]) {
      b.insert(
        d.buddies,
        db.BuddiesCompanion(
          id: Value(id),
          name: Value('Buddy $id'),
          diverId: Value(owner),
          createdAt: const Value(_ms),
          updatedAt: const Value(_ms),
        ),
      );
    }
    for (final id in ['shared', 'private']) {
      b.insert(
        d.equipment,
        db.EquipmentCompanion(
          id: Value(id),
          name: Value('Gear $id'),
          type: const Value('regulator'),
          diverId: const Value('other'),
          createdAt: const Value(_ms),
          updatedAt: const Value(_ms),
        ),
      );
    }
    b.insert(
      d.equipmentShares,
      const db.EquipmentSharesCompanion(
        id: Value('s1'),
        equipmentId: Value('shared'),
        diverId: Value('me'),
        createdAt: Value(_ms),
      ),
    );
    b.insert(
      d.species,
      const db.SpeciesCompanion(
        id: Value('sp1'),
        commonName: Value('Frogfish'),
        category: Value('fish'),
      ),
    );
  });
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  late ConnectionsReader reader;
  setUp(() async {
    final d = DatabaseService.instance.database;
    await _seed(d);
    reader = ConnectionsReader(d);
  });

  Future<String> label(NodeRef ref, {String? diverId = 'me'}) async =>
      (await reader.labelOnly(ref, diverId: diverId)).label;

  test('the focus label reads what the diver can see', () async {
    expect(
      await label(const NodeRef(ConnectionKind.buddy, 'mine')),
      'Buddy mine',
    );
    expect(
      await label(const NodeRef(ConnectionKind.buddy, 'nobodys')),
      'Buddy nobodys',
    );
    expect(
      await label(const NodeRef(ConnectionKind.equipment, 'shared')),
      'Gear shared',
      reason: 'gear shared with the diver is theirs to explore',
    );
    expect(
      await label(const NodeRef(ConnectionKind.species, 'sp1')),
      'Frogfish',
      reason: 'species are a shared catalogue',
    );
  });

  test("another diver's entity is not found, not labelled", () async {
    expect(
      () => label(const NodeRef(ConnectionKind.buddy, 'theirs')),
      throwsA(isA<FocusNotFoundException>()),
    );
    expect(
      () => label(const NodeRef(ConnectionKind.equipment, 'private')),
      throwsA(isA<FocusNotFoundException>()),
    );
  });

  test(
    'with no active diver every entity is visible, as before profiles',
    () async {
      expect(
        await label(
          const NodeRef(ConnectionKind.buddy, 'theirs'),
          diverId: null,
        ),
        'Buddy theirs',
      );
    },
  );
}
