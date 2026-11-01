import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart' show WeightType;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/features/table_editor/entities/dive_table_editor_entity.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../helpers/test_database.dart';

/// The dive tab's descriptor (#3422): which columns edit, how a cell's text
/// becomes a stored value, and how a dive's drafts reach the bulk service.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late BulkDiveEditService bulk;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    bulk = BulkDiveEditService(
      diveRepo,
      BuddyRepository(),
      SpeciesRepository(),
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> seed(String id, {double? visibilityMeters}) =>
      diveRepo.createDive(
        domain.Dive(
          id: id,
          dateTime: DateTime(2026, 1, 1),
          notes: '',
          visibilityMeters: visibilityMeters,
        ),
      );

  domain.DiveWeight weight(double kg, {WeightType type = WeightType.belt}) =>
      domain.DiveWeight(id: '', diveId: '', weightType: type, amountKg: kg);

  Future<void> insertSite(String id, {String? waterType}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value(id),
            name: Value('Site $id'),
            waterType: Value(waterType),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<DiveTableEditorEntity> entity() async {
    final dives = await diveRepo.getDivesByIdsWithoutSamples(['d1', 'd2']);
    return DiveTableEditorEntity(
      diveRepo: diveRepo,
      bulk: bulk,
      sites: const [ChoiceOption('s1', 'Site s1')],
      centers: const [],
      trips: const [],
      defaultWeightType: DiveTableEditorEntity.latestWeightType(dives),
    );
  }

  TableDraft draft(
    String id,
    DiveField field,
    Object? original,
    Object? value,
  ) => TableDraft(
    entityId: id,
    fieldName: field.name,
    original: original,
    value: value,
  );

  Future<Map<String, domain.Dive>> rows() async => {
    for (final d in await diveRepo.getDivesByIdsWithoutSamples(['d1', 'd2']))
      d.id: d,
  };

  test('weight column is read-only on a dive with two rows', () async {
    await seed('d1');
    await seed('d2');
    await diveRepo.bulkAddWeights(['d1'], [weight(3), weight(4)]);
    final e = await entity();
    final r = await rows();
    final column = e.columnFor(DiveField.totalWeight)!;

    expect(column.isEditable(r['d1']!), isFalse);
    expect(column.readOnlyReason(r['d1']!, AppLocalizationsEn()), isNotNull);
    expect(column.isEditable(r['d2']!), isTrue);
  });

  test('save writes one dive\'s visibility and weight and leaves the other '
      'dive alone', () async {
    await seed('d1', visibilityMeters: 10);
    await seed('d2', visibilityMeters: 20);
    final e = await entity();
    final r = await rows();

    await e.save({
      'd1': [
        draft('d1', DiveField.visibility, 10.0, 15.0),
        draft('d1', DiveField.totalWeight, null, 6.0),
      ],
    }, r);

    final after = await rows();
    expect(after['d1']!.visibilityMeters, 15);
    expect(after['d1']!.weights.single.amountKg, 6);
    expect(after['d2']!.visibilityMeters, 20);
    expect(after['d2']!.weights, isEmpty);
  });

  test('save sets a site through SiteOp so the water type snaps', () async {
    await seed('d1');
    await seed('d2');
    await insertSite('s1', waterType: 'salt');
    final e = await entity();
    final r = await rows();

    await e.save({
      'd1': [draft('d1', DiveField.siteName, null, 's1')],
    }, r);

    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('d1'))).getSingle();
    expect(row.siteId, 's1');
    expect(row.waterType, 'salt');
  });

  test('new weight row takes the latest logged type, belt when none', () async {
    await seed('d1');
    await seed('d2');
    await diveRepo.bulkAddWeights(
      ['d2'],
      [weight(2, type: WeightType.integrated)],
    );
    final e = await entity();
    final r = await rows();

    await e.save({
      'd1': [draft('d1', DiveField.totalWeight, null, 5.0)],
    }, r);

    final after = await rows();
    expect(after['d1']!.weights.single.weightType, WeightType.integrated);
  });

  test('reload returns fresh rows with weights filled', () async {
    await seed('d1');
    await seed('d2');
    await diveRepo.bulkAddWeights(['d1'], [weight(3)]);
    final e = await entity();

    final fresh = await e.reload(['d1', 'd2']);

    expect(fresh.map((d) => d.id), containsAll(['d1', 'd2']));
    expect(fresh.firstWhere((d) => d.id == 'd1').weights.single.amountKg, 3);
  });

  test('columns edit visibility in the diver\'s depth unit', () async {
    await seed('d1', visibilityMeters: 15);
    await seed('d2');
    final e = await entity();
    final r = await rows();
    final column = e.columnFor(DiveField.visibility)!;

    expect(column.valueOf(r['d1']!), 15.0);
    expect(column.kind, CellEditorKind.number);
    expect(e.columnFor(DiveField.maxDepth), isNull);
    expect(e.numberOf(r['d1']!), r['d1']!.diveNumber);
    expect(e.nameOf(r['d1']!), isNull);
  });
}
