import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_link_repository.dart';
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../helpers/test_database.dart';

const _ms = 1700000000000;

/// One dive with a trip, a dive center, a gear item and a species sighting,
/// so each kind's node carries its subtitle.
Future<void> _seed(db.AppDatabase d) async {
  await d.batch((b) {
    b.insert(
      d.divers,
      const db.DiversCompanion(
        id: Value('me'),
        name: Value('me'),
        createdAt: Value(_ms),
        updatedAt: Value(_ms),
      ),
    );
    b.insert(
      d.trips,
      db.TripsCompanion(
        id: const Value('t1'),
        name: const Value('Bonaire'),
        // Trip dates are local instants, as the trip editor's date picker
        // saves them (TripRepository reads them back as local too).
        startDate: Value(DateTime(2024, 3, 1).millisecondsSinceEpoch),
        endDate: Value(DateTime(2024, 3, 8).millisecondsSinceEpoch),
        createdAt: const Value(_ms),
        updatedAt: const Value(_ms),
      ),
    );
    b.insert(
      d.diveCenters,
      const db.DiveCentersCompanion(
        id: Value('c1'),
        name: Value('Buddy Dive'),
        country: Value('Bonaire'),
        createdAt: Value(_ms),
        updatedAt: Value(_ms),
      ),
    );
    b.insert(
      d.equipment,
      const db.EquipmentCompanion(
        id: Value('e1'),
        name: Value('Apeks XTX50'),
        type: Value('regulator'),
        createdAt: Value(_ms),
        updatedAt: Value(_ms),
      ),
    );
    b.insert(
      d.species,
      const db.SpeciesCompanion(
        id: Value('sp1'),
        commonName: Value('Frogfish'),
        scientificName: Value('Antennarius multiocellatus'),
        category: Value('fish'),
      ),
    );
    b.insert(
      d.dives,
      const db.DivesCompanion(
        id: Value('d1'),
        diverId: Value('me'),
        tripId: Value('t1'),
        diveCenterId: Value('c1'),
        diveDateTime: Value(_ms),
        createdAt: Value(_ms),
        updatedAt: Value(_ms),
      ),
    );
    b.insert(
      d.diveEquipment,
      const db.DiveEquipmentCompanion(
        diveId: Value('d1'),
        equipmentId: Value('e1'),
      ),
    );
    b.insert(
      d.sightings,
      const db.SightingsCompanion(
        id: Value('s1'),
        diveId: Value('d1'),
        speciesId: Value('sp1'),
      ),
    );
  });
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<ConnectionNode> single(ConnectionKind kind) async {
    final reader = ConnectionsReader(DatabaseService.instance.database);
    final nodes = await reader.nodes(
      kind,
      diverId: 'me',
      filter: const DiveFilterState(),
    );
    return nodes.single;
  }

  test('each kind reads its subtitle', () async {
    await _seed(DatabaseService.instance.database);
    final trip = await single(ConnectionKind.trip);
    expect(trip.label, 'Bonaire');
    expect(
      trip.subtitle,
      // Local, like the stored value: a UTC decode put the range a day early
      // for divers east of UTC (issue #2808). DateTime equality compares the
      // UTC flag, so this fails on a UTC decode in any time zone.
      DateRangeSubtitle(DateTime(2024, 3, 1), DateTime(2024, 3, 8)),
    );
    expect(
      (await single(ConnectionKind.diveCenter)).subtitle,
      const TextSubtitle('Bonaire'),
    );
    expect(
      (await single(ConnectionKind.equipment)).subtitle,
      const TextSubtitle('regulator'),
    );
    expect(
      (await single(ConnectionKind.species)).subtitle,
      const TextSubtitle('Antennarius multiocellatus'),
    );
  });

  test('a data source with no linked computer makes no dive computer '
      'edge', () async {
    final d = DatabaseService.instance.database;
    await _seed(d);
    // An imported file whose computer was never identified: computer_id is
    // nullable, and the edge query must not return a row for the NULL.
    await d
        .into(d.diveDataSources)
        .insert(
          db.DiveDataSourcesCompanion.insert(
            id: 'src1',
            diveId: 'd1',
            importedAt: DateTime.utc(2024, 3, 2),
            createdAt: DateTime.utc(2024, 3, 2),
          ),
        );
    final edges = await ConnectionsReader(d).edges(
      ConnectionKind.trip,
      ConnectionKind.diveComputer,
      diverId: 'me',
      filter: const DiveFilterState(),
      restrictA: const ['t1'],
    );
    expect(edges, isEmpty);
  });

  test('a missing focus names itself in the error', () {
    const e = FocusNotFoundException(NodeRef(ConnectionKind.buddy, 'ghost'));
    expect(e.toString(), 'FocusNotFoundException(buddy:ghost)');
  });

  test(
    'a buddy subtitle names the one role held on every dive (#1221)',
    () async {
      final d = DatabaseService.instance.database;
      await d.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('me', 'me', $_ms, $_ms)",
      );
      await d.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
        "updated_at) VALUES ('d1', 'me', $_ms, $_ms, $_ms), "
        "('d2', 'me', $_ms, $_ms, $_ms)",
      );
      await d.customStatement(
        'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
        "VALUES ('ana', 'me', 'Ana', $_ms, $_ms), "
        "('ben', 'me', 'Ben', $_ms, $_ms), ('cy', 'me', 'Cy', $_ms, $_ms)",
      );
      for (final dive in ['d1', 'd2']) {
        for (final buddy in ['ana', 'ben', 'cy']) {
          await d.customStatement(
            'INSERT INTO dive_buddies (id, dive_id, buddy_id, role, '
            "created_at) VALUES ('$dive-$buddy', '$dive', '$buddy', 'buddy', "
            '$_ms)',
          );
        }
      }
      final roles = DiveRoleLinkRepository();
      await roles.writeBuddyRoles('d1', 'ana', ['diveGuide', 'diveMaster']);
      await roles.writeBuddyRoles('d2', 'ana', ['diveMaster']);
      await roles.writeBuddyRoles('d1', 'ben', ['diveGuide', 'diveMaster']);
      await roles.writeBuddyRoles('d2', 'ben', ['diveGuide', 'diveMaster']);
      await roles.writeBuddyRoles('d1', 'cy', ['instructor']);
      await roles.writeBuddyRoles('d2', 'cy', ['student']);

      final nodes = await ConnectionsReader(d).nodes(
        ConnectionKind.buddy,
        diverId: 'me',
        filter: const DiveFilterState(),
      );
      final byId = {for (final n in nodes) n.ref.id: n.subtitle};
      expect(byId['ana'], const RoleSubtitle('diveMaster'));
      expect(byId['ben'], isNot(isA<RoleSubtitle>()));
      expect(byId['cy'], isNot(isA<RoleSubtitle>()));
    },
  );
}
