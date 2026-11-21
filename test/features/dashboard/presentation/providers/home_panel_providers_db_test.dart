import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The diver's documents with an expiry, as the repository would give them.
class _Documents extends DocumentRepository {
  final List<Document> docs;

  _Documents(this.docs)
    : super(cancelReminders: (_) async {}, clearancesDeleted: (_) {});

  @override
  Future<List<Document>> getRemindingForDiver(String diverId) async => docs;
}

/// Every Home panel provider read against a seeded test database, so the
/// queries behind each panel run as they do in the app (the widget tests
/// override them).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime.now();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await setUpTestDatabase();
    // Five dives over the last few months, the newest with a profile, each
    // breathing nitrox from one cylinder; a turtle on two of them.
    for (var i = 0; i < 5; i++) {
      final when = now.subtract(Duration(days: 10 + i * 20));
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value('d$i'),
              diveNumber: Value(100 + i),
              diveDateTime: Value(
                DateTime.utc(
                  when.year,
                  when.month,
                  when.day,
                  10,
                ).millisecondsSinceEpoch,
              ),
              maxDepth: Value(18.0 + i),
              avgDepth: const Value(10),
              runtime: const Value(3000),
              bottomTime: const Value(3000),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value('t$i'),
              diveId: Value('d$i'),
              startPressure: const Value(200),
              endPressure: const Value(60),
              volume: const Value(12),
              tankRole: const Value('backGas'),
              o2Percent: const Value(32.0),
              hePercent: const Value(0.0),
              tankOrder: const Value(0),
            ),
          );
    }
    await db
        .into(db.species)
        .insert(
          const SpeciesCompanion(
            id: Value('turtle'),
            commonName: Value('Green turtle'),
            category: Value('reptile'),
          ),
        );
    for (final d in ['d0', 'd1']) {
      await db
          .into(db.sightings)
          .insert(
            SightingsCompanion.insert(
              id: 's$d',
              diveId: d,
              speciesId: 'turtle',
            ),
          );
    }
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        homeSacLaneProvider.overrideWithValue(GasConsumptionLane.rmv),
        activeEquipmentClocksProvider.overrideWith((ref) async => const []),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('activity days count each dive on its day', () async {
    final days = await container.read(homeActivityDaysProvider.future);
    expect(days.values.fold(0, (a, b) => a + b), 5);
  });

  test('dives per month gives twelve months holding all five', () async {
    final months = await container.read(homeMonthlyDivesProvider.future);
    expect(months, hasLength(12));
    expect(months.fold(0, (a, m) => a + m.count), 5);
  });

  test('the SAC series has a point per dive, oldest first', () async {
    final series = await container.read(homeSacSeriesProvider.future);
    expect(series, hasLength(5));
    expect(series.first.date.isBefore(series.last.date), isTrue);
  });

  test('gas mix and dive types read the log', () async {
    final gas = await container.read(homeGasMixProvider.future);
    expect(gas.map((s) => s.label), contains('Nitrox'));
    // The seeded dives carry no dive type, so the shares are empty.
    final types = await container.read(homeDiveTypesProvider.future);
    expect(types, isEmpty);
  });

  test('top buddies is empty with no buddies', () async {
    expect(await container.read(homeTopBuddiesProvider.future), isEmpty);
  });

  test('species seen lately and the species count', () async {
    final recent = await container.read(homeRecentSpeciesProvider.future);
    expect(recent.single.name, 'Green turtle');
    expect(recent.single.diveCount, 2);
    expect(await container.read(homeSpeciesCountProvider.future), 1);
  });

  test(
    'new species this year counts the turtle when first seen this year',
    () async {
      final n = await container.read(homeNewSpeciesThisYearProvider.future);
      // The oldest sighting is 10 or 30 days back: this year unless the test
      // runs in January.
      expect(n, now.month == 1 ? anyOf(0, 1) : 1);
    },
  );

  test('gear service is empty with no gear', () async {
    expect(await container.read(homeGearServiceProvider.future), isEmpty);
  });

  test('the latest profile is the newest dive', () async {
    final latest = await container.read(homeLatestProfileProvider.future);
    expect(latest?.dive.id, 'd0');
  });

  test('coming due lists a document long before its reminder starts', () async {
    Document doc(String id, String title, DocumentType type, int days) =>
        Document(
          id: id,
          diverId: 'diver1',
          owner: const DocumentOwner.personal(),
          type: type,
          title: title,
          expiryDate: now.add(Duration(days: days)),
          reminderLeadDays: 30,
          createdAt: now,
          updatedAt: now,
        );
    final c = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver1'),
        activeEquipmentClocksProvider.overrideWith((ref) async => const []),
        dashboardGaugesProvider.overrideWith(
          (ref) async => const DashboardGauges(
            hasGear: false,
            insurance: null,
            noFlyStatus: null,
            daysSinceLastDive: null,
          ),
        ),
        documentRepositoryProvider.overrideWithValue(
          _Documents([
            // Five months out: well outside a 30-day reminder lead.
            doc('p', 'Dive permit', DocumentType.permit, 150),
            // Insurance comes from the diver's policy, not the documents.
            doc('i', 'Policy scan', DocumentType.insurance, 100),
            // Past the one-year horizon.
            doc('m', 'Map licence', DocumentType.map, 500),
          ]),
        ),
      ],
    );
    addTearDown(c.dispose);
    final items = await c.read(homeComingDueProvider.future);
    expect(items.map((i) => i.name), ['Dive permit']);
    expect(items.single.kind, ComingDueKind.document);
  });

  test('averages cover the window', () async {
    final avg = await container.read(homeAveragesProvider.future);
    expect(avg.averages.diveCount, 5);
    expect(avg.sac, isNotNull);
  });
}
