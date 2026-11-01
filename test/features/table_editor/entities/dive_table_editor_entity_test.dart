import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart' show WeightType;
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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
    return DiveTableEditorEntity(
      diveRepo: diveRepo,
      bulk: bulk,
      sites: const [ChoiceOption('s1', 'Site s1')],
      centers: const [],
      trips: const [],
      defaultWeightType:
          await diveRepo.latestWeightType(null) ?? WeightType.belt,
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

  test('surface pressure is typed in the diver\'s barometric unit', () async {
    await seed('d1');
    await seed('d2');
    final e = await entity();
    final column = e.columnFor(DiveField.surfacePressure)!;
    const metric = UnitFormatter(AppSettings());
    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));
    final dive = (await rows())['d1']!.copyWith(surfacePressure: 1.013);

    expect(column.editText(dive, metric), '1013');
    expect(column.unitSymbol(metric), 'mbar');
    expect(
      (column.parse('1013', metric, AppLocalizationsEn()) as CellParsed).value,
      closeTo(1.013, 1e-9),
    );
    expect(column.unitSymbol(imperial), 'inHg');
    expect(
      (column.parse('29.92', imperial, AppLocalizationsEn()) as CellParsed)
          .value,
      closeTo(1.0132, 1e-3),
    );
  });

  test('the latest weight type comes from the diver\'s log, newest dive '
      'first', () async {
    Future<void> dive(String id, int day, String diver) => diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: diver,
        dateTime: DateTime(2026, 1, day),
        notes: '',
      ),
    );
    await dive('old', 1, 'me');
    await dive('new', 2, 'me');
    await dive('other', 3, 'someone else');
    await dive('bare', 4, 'me');
    expect(await diveRepo.latestWeightType('me'), isNull);

    await diveRepo.bulkAddWeights(['old'], [weight(2)]);
    await diveRepo.bulkAddWeights(
      ['new'],
      [weight(2, type: WeightType.integrated)],
    );
    await diveRepo.bulkAddWeights(
      ['other'],
      [weight(2, type: WeightType.ankleWeights)],
    );

    expect(await diveRepo.latestWeightType('me'), WeightType.integrated);
  });

  test('a scrubber duration waits for a type', () async {
    final e = await entity();
    final bare = domain.Dive(id: 'd1', dateTime: DateTime(2026), notes: '');
    final duration = draft('d1', DiveField.scrubberDuration, null, 180);
    final type = draft('d1', DiveField.scrubberType, null, 'Sofnolime');

    expect(
      e.reconcile(bare, [duration]).single.flag,
      TableDraftFlag.needsScrubberType,
    );
    expect(
      e
          .reconcile(bare, [
            duration.copyWith(flag: TableDraftFlag.needsScrubberType),
            type,
          ])
          .map((d) => d.flag),
      everyElement(isNull),
    );

    final typed = bare.copyWith(
      scrubber: const domain.ScrubberInfo(type: 'Sofnolime'),
    );
    expect(e.reconcile(typed, [duration]).single.flag, isNull);
    expect(
      e
          .reconcile(typed, [
            duration,
            draft('d1', DiveField.scrubberType, 'Sofnolime', null),
          ])
          .first
          .flag,
      TableDraftFlag.needsScrubberType,
    );
  });

  test('computer model is picked from the diver\'s computers', () {
    final e = DiveTableEditorEntity(
      diveRepo: diveRepo,
      bulk: bulk,
      sites: const [],
      centers: const [],
      trips: const [],
      computers: const [ChoiceOption('Perdix', 'Perdix')],
    );
    final column = e.columnFor(DiveField.diveComputerModel)!;
    const units = UnitFormatter(AppSettings());
    final l10n = AppLocalizationsEn();

    expect(column.kind, CellEditorKind.reference);
    expect((column.parse('perdix', units, l10n) as CellParsed).value, 'Perdix');
    expect(column.parse('Nope', units, l10n), isA<CellRejected>());
  });

  test(
    'a converted number opens rounded, without its conversion tail',
    () async {
      await seed('d1', visibilityMeters: 15);
      await seed('d2');
      final e = await entity();
      final r = await rows();
      const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

      expect(
        e.columnFor(DiveField.visibility)!.editText(r['d1']!, imperial),
        '49.21',
      );
    },
  );
}
