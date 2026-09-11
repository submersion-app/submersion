import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Every child row [DiveRepository.createDive] writes has to be marked
/// pending, or gear, tanks, weights and custom fields entered at creation
/// time only ever reach peers on a full base export. The three loops inside
/// the child batch used to mint their ids inside the synchronous batch
/// closure, where no pending mark could reach them.
void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });

  tearDown(tearDownTestDatabase);

  /// Record ids marked pending for [entityType].
  Future<Set<String>> pending(String entityType) async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.entityType == entityType) r.recordId,
  };

  /// Ids actually written to the child tables, so the assertions compare the
  /// pending marks against the rows rather than against ids the test minted.
  Future<Set<String>> tankIds() async => {
    for (final r in await db.select(db.diveTanks).get()) r.id,
  };
  Future<Set<String>> weightIds() async => {
    for (final r in await db.select(db.diveWeights).get()) r.id,
  };
  Future<Set<String>> fieldIds() async => {
    for (final r in await db.select(db.diveCustomFields).get()) r.id,
  };

  // One id for the dive and for the diveId its weights carry, so the two
  // cannot drift apart if this helper ever builds a second dive.
  const diveId = 'dv';

  domain.Dive diveWithChildren() => domain.Dive(
    id: diveId,
    dateTime: DateTime.utc(2026, 1, 1, 10),
    tanks: const [
      domain.DiveTank(
        id: 'tank-given',
        gasMix: domain.GasMix(o2: 32, he: 0),
        order: 0,
      ),
      // Empty id: createDive mints one, so the pending mark has to carry
      // the minted value rather than anything the caller supplied.
      domain.DiveTank(id: '', gasMix: domain.GasMix(o2: 21, he: 0), order: 1),
    ],
    weights: const [
      domain.DiveWeight(
        id: 'weight-given',
        diveId: diveId,
        weightType: WeightType.integrated,
        amountKg: 4,
      ),
      domain.DiveWeight(
        id: '',
        diveId: diveId,
        weightType: WeightType.belt,
        amountKg: 2,
      ),
    ],
    customFields: const [
      domain.DiveCustomField(
        id: 'field-given',
        key: 'shop',
        value: 'Blue Water',
      ),
      domain.DiveCustomField(id: '', key: 'boat', value: 'Nautilus'),
    ],
  );

  test('createDive marks every tank it writes pending', () async {
    await repo.createDive(diveWithChildren());

    final written = await tankIds();
    expect(written, hasLength(2));
    expect(await pending('diveTanks'), written);
  });

  test('createDive marks every weight it writes pending', () async {
    await repo.createDive(diveWithChildren());

    final written = await weightIds();
    expect(written, hasLength(2));
    expect(await pending('diveWeights'), written);
  });

  test('createDive marks every custom field it writes pending', () async {
    await repo.createDive(diveWithChildren());

    final written = await fieldIds();
    expect(written, hasLength(2));
    expect(await pending('diveCustomFields'), written);
  });
}
