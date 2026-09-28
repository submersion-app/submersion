import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
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
        startDate: Value(DateTime.utc(2024, 3, 1).millisecondsSinceEpoch),
        endDate: Value(DateTime.utc(2024, 3, 8).millisecondsSinceEpoch),
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
      DateRangeSubtitle(DateTime.utc(2024, 3, 1), DateTime.utc(2024, 3, 8)),
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

  test('a missing focus names itself in the error', () {
    const e = FocusNotFoundException(NodeRef(ConnectionKind.buddy, 'ghost'));
    expect(e.toString(), 'FocusNotFoundException(buddy:ghost)');
  });
}
