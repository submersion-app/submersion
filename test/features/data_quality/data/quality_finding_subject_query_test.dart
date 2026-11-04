import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/data/services/quality_finding_subject_query.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding_subjects.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late QualityFindingSubjectQuery query;
  final entry = DateTime.utc(2026, 7, 1, 10);

  setUp(() async {
    db = await setUpTestDatabase();
    query = QualityFindingSubjectQuery(db);
  });
  tearDown(tearDownTestDatabase);

  Future<void> seedComputer(
    String id, {
    String name = '',
    String? manufacturer,
    String? model,
  }) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value(name),
          manufacturer: Value(manufacturer),
          model: Value(model),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> seedSource(
    String id, {
    String? computerId,
    String? computerModel,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: const Value('d1'),
          computerId: Value(computerId),
          computerModel: Value(computerModel),
          importedAt: Value(entry),
          createdAt: Value(entry),
        ),
      );

  group('watchSourceLabels', () {
    setUp(() async {
      await DiveRepository().createDive(
        domain.Dive(id: 'd1', dateTime: entry, entryTime: entry),
      );
    });

    test('prefers the saved computer, then its make and model, then the '
        'recorded model', () async {
      await seedComputer('named', name: 'My Perdix');
      await seedComputer('unnamed', manufacturer: 'Suunto', model: 'EON Core');
      await seedSource('a', computerId: 'named', computerModel: 'Perdix 2');
      await seedSource('b', computerId: 'unnamed', computerModel: 'EON');
      await seedSource('c', computerModel: 'Perdix 2');
      await seedSource('d');
      await seedComputer('maker', manufacturer: 'Shearwater');
      await seedSource('e', computerId: 'maker', computerModel: 'Perdix 2');

      final labels = await query.watchSourceLabels([
        'a',
        'b',
        'c',
        'd',
        'e',
        'missing',
      ]).first;

      expect(labels, {
        'a': 'My Perdix',
        'b': 'Suunto EON Core',
        'c': 'Perdix 2',
        // As DiveComputer.displayName names a computer with a maker alone.
        'e': 'Shearwater',
      });
    });

    test('an empty id list reads nothing', () async {
      expect(await query.watchSourceLabels(const []).first, isEmpty);
    });

    test('a renamed computer relabels the source', () async {
      await seedComputer('c1', name: 'Old');
      await seedSource('a', computerId: 'c1');
      final labels = query.watchSourceLabels(['a']);
      final seen = <Map<String, String>>[];
      final sub = labels.listen(seen.add);
      await pumpEventQueue();
      await (db.update(db.diveComputers)..where((t) => t.id.equals('c1')))
          .write(const DiveComputersCompanion(name: Value('New')));
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.first, {'a': 'Old'});
      expect(seen.last, {'a': 'New'});
    });
  });

  group('watchTanks', () {
    test('numbers tanks by their order within their own dive', () async {
      await DiveRepository().createDive(
        domain.Dive(
          id: 'd1',
          dateTime: entry,
          entryTime: entry,
          tanks: const [
            domain.DiveTank(id: 'back', order: 0),
            domain.DiveTank(id: 'stage', order: 1, name: 'Stage'),
            domain.DiveTank(id: 'deco', order: 2),
          ],
        ),
      );
      await DiveRepository().createDive(
        domain.Dive(
          id: 'd2',
          dateTime: entry.add(const Duration(hours: 3)),
          entryTime: entry.add(const Duration(hours: 3)),
          tanks: const [domain.DiveTank(id: 'other', order: 0)],
        ),
      );

      final tanks = await query.watchTanks([
        'deco',
        'stage',
        'other',
        'missing',
      ]).first;

      expect(tanks, {
        'stage': const QualityTankRef(number: 2, name: 'Stage'),
        'deco': const QualityTankRef(number: 3),
        'other': const QualityTankRef(number: 1),
      });
    });

    // The dive's screens sort by tank order alone, leaving equal orders in
    // table order; an id tie-break would number them differently.
    test('equal tank orders keep the order the tanks were stored in', () async {
      await DiveRepository().createDive(
        domain.Dive(
          id: 'd1',
          dateTime: entry,
          entryTime: entry,
          tanks: const [
            domain.DiveTank(id: 'zz-first', order: 0),
            domain.DiveTank(id: 'aa-second', order: 0),
          ],
        ),
      );

      final tanks = await query.watchTanks(['aa-second', 'zz-first']).first;

      expect(tanks['zz-first']!.number, 1);
      expect(tanks['aa-second']!.number, 2);
    });

    test('an empty id list reads nothing', () async {
      expect(await query.watchTanks(const []).first, isEmpty);
    });
  });
}
