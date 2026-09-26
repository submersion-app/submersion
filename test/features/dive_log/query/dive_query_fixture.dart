import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';

/// Six dives that between them answer every request in #2365:
///
/// | id | weight | gear | temp | buddy | site | notes |
/// | d1 | table row 2 kg | wetsuit | 24 | Ana (linked) | Salt Pier (Bonaire) | manta |
/// | d2 | legacy scalar 3 kg | drysuit | null | legacy text "Bob" | Salt Pier | '' |
/// | d3 | none | bcd only | 18 | none | Hilma Hooker (Bonaire) | 100% night |
/// | d4 | none | none | null | none | null | '' |
/// | d5 | table row 1 kg | wetsuit + drysuit | 30 | Ana + Cid | Cenote (Mexico) | '' |
/// | d6 | none | none | 12 | none | Cenote | '' (other diver) |
class QueryFixtureIds {
  static const dives = ['d1', 'd2', 'd3', 'd4', 'd5', 'd6'];
  static const mine = ['d1', 'd2', 'd3', 'd4', 'd5'];
}

Future<void> seedQueryFixture(AppDatabase db) async {
  final now = DateTime(2025, 6, 1).millisecondsSinceEpoch;
  int day(int y, int m, int d) =>
      DateTime.utc(y, m, d, 10).millisecondsSinceEpoch;

  for (final id in ['me', 'other']) {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: id,
            name: id,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> site(String id, String name, String country) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: id,
          name: name,
          country: Value(country),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await site('s1', 'Salt Pier', 'Bonaire');
  await site('s2', 'Hilma Hooker', 'Bonaire');
  await site('s3', 'Cenote', 'Mexico');

  Future<void> buddy(String id, String name) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: name,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await buddy('b1', 'Ana');
  await buddy('b2', 'Cid');
  await db
      .into(db.certifications)
      .insert(
        CertificationsCompanion.insert(
          id: 'c1',
          buddyId: const Value('b1'),
          name: 'Rescue Diver',
          agency: 'PADI',
          level: const Value('rescue'),
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<void> gear(String id, String type) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: type,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await gear('g_wet', 'wetsuit');
  await gear('g_dry', 'drysuit');
  await gear('g_bcd', 'bcd');

  Future<void> dive(
    String id, {
    String diver = 'me',
    double? temp,
    String? siteId,
    String notes = '',
    String? legacyBuddy,
    double? legacyWeight,
    int? date,
    double? depth,
    int? bottom,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(diver),
          diveDateTime: date ?? day(2025, 3, 14),
          waterTemp: Value(temp),
          siteId: Value(siteId),
          notes: Value(notes),
          buddy: Value(legacyBuddy),
          weightAmount: Value(legacyWeight),
          maxDepth: Value(depth),
          bottomTime: Value(bottom),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await dive(
    'd1',
    temp: 24,
    siteId: 's1',
    notes: 'manta ray',
    depth: 18,
    bottom: 50 * 60 + 30,
    date: day(2025, 1, 5),
  );
  await dive(
    'd2',
    siteId: 's1',
    legacyBuddy: 'Bob',
    legacyWeight: 3,
    depth: 30,
    bottom: 45 * 60,
    date: day(2025, 2, 9),
  );
  await dive(
    'd3',
    temp: 18,
    siteId: 's2',
    notes: '100% night dive',
    depth: 25,
    date: day(2025, 3, 14),
  );
  await dive('d4', bottom: 10 * 60, date: day(2024, 12, 31));
  await dive(
    'd5',
    temp: 30,
    siteId: 's3',
    depth: 40,
    bottom: 10 * 60 + 59,
    date: day(2025, 3, 15),
  );
  await dive(
    'd6',
    diver: 'other',
    temp: 12,
    siteId: 's3',
    depth: 12,
    bottom: 20 * 60,
  );

  Future<void> weight(String id, String diveId, double kg) => db
      .into(db.diveWeights)
      .insert(
        DiveWeightsCompanion.insert(
          id: id,
          diveId: diveId,
          weightType: 'belt',
          amountKg: kg,
          createdAt: now,
        ),
      );
  await weight('w1', 'd1', 2);
  await weight('w5', 'd5', 1);

  Future<void> link(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: equipmentId),
      );
  await link('d1', 'g_wet');
  await link('d2', 'g_dry');
  await link('d3', 'g_bcd');
  await link('d5', 'g_wet');
  await link('d5', 'g_dry');

  Future<void> buddyLink(String id, String diveId, String buddyId) => db
      .into(db.diveBuddies)
      .insert(
        DiveBuddiesCompanion.insert(
          id: id,
          diveId: diveId,
          buddyId: buddyId,
          createdAt: now,
        ),
      );
  await buddyLink('db1', 'd1', 'b1');
  await buddyLink('db5a', 'd5', 'b1');
  await buddyLink('db5b', 'd5', 'b2');
}
