import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/cylinder_proposal_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    for (final d in ['a', 'b']) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: d,
              diverId: const Value('me'),
              diveDateTime: 0,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 't-$d',
              diveId: d,
              volume: const Value(11.1),
              tankMaterial: const Value('aluminum'),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  Future<List<int>> diveCounts(List<EquipmentItem> owned) async {
    final container = ProviderContainer(
      overrides: [activeEquipmentProvider.overrideWith((ref) async => owned)],
    );
    addTearDown(container.dispose);
    final proposals = await container.read(
      importCylinderProposalsProvider(const ImportedDiveIds(['a', 'b'])).future,
    );
    return [for (final p in proposals) p.diveCount];
  }

  test('unmatched tanks of the imported dives make one proposal', () async {
    expect(await diveCounts(const []), [2]);
  });

  test('an owned cylinder of that size leaves nothing to propose', () async {
    final al80 = EquipmentItem(
      id: 'al80',
      name: 'AL80',
      type: EquipmentType.tank,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'al80',
          key: EquipmentAttrKeys.volumeL,
          valueNum: 11.1,
        ),
      ],
    );
    expect(await diveCounts([al80]), isEmpty);
  });

  test('a lost cylinder does not count as owned', () async {
    const lost = EquipmentItem(
      id: 'lost',
      name: 'Lost',
      type: EquipmentType.tank,
      status: EquipmentStatus.lost,
      attributes: [
        EquipmentAttribute(
          id: 'x',
          equipmentId: 'lost',
          key: EquipmentAttrKeys.volumeL,
          valueNum: 11.1,
        ),
      ],
    );
    expect(await diveCounts([lost]), [2]);
  });

  test('no imported dives proposes nothing', () async {
    final container = ProviderContainer(
      overrides: [activeEquipmentProvider.overrideWith((ref) async => [])],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(
        importCylinderProposalsProvider(const ImportedDiveIds([])).future,
      ),
      isEmpty,
    );
  });
}
