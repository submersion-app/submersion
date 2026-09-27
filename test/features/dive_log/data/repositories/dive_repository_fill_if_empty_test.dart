import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart' show WeightType;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// The writes a cloud import uses to bring in what the diver entered in the
/// source app (issue #2410) without overwriting what they have already
/// written in Submersion.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seed(String id, {String notes = ''}) => repository.createDive(
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: notes),
  );

  Future<Dive> row(String id) =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  Future<List<DiveWeight>> weights(String id) =>
      (db.select(db.diveWeights)..where((t) => t.diveId.equals(id))).get();

  group('fillNotesIfEmpty', () {
    test('writes notes onto a dive that has none', () async {
      await seed('d1');

      final written = await repository.fillNotesIfEmpty('d1', 'Saw a manta');

      expect(written, isTrue);
      expect((await row('d1')).notes, 'Saw a manta');
    });

    test('treats whitespace-only notes as empty', () async {
      await seed('d1', notes: '  \n ');

      final written = await repository.fillNotesIfEmpty('d1', 'Saw a manta');

      expect(written, isTrue);
      expect((await row('d1')).notes, 'Saw a manta');
    });

    test('leaves notes the diver already wrote untouched', () async {
      await seed('d1', notes: 'My own notes');
      final before = await row('d1');

      final written = await repository.fillNotesIfEmpty('d1', 'Saw a manta');

      final after = await row('d1');
      expect(written, isFalse);
      expect(after.notes, 'My own notes');
      // Not even touched: a no-op must not look like an edit to sync.
      expect(after.updatedAt, before.updatedAt);
    });

    test('ignores blank incoming notes', () async {
      await seed('d1');

      final written = await repository.fillNotesIfEmpty('d1', '   ');

      expect(written, isFalse);
      expect((await row('d1')).notes, '');
    });

    test('only touches the named dive', () async {
      await seed('d1');
      await seed('d2');

      await repository.fillNotesIfEmpty('d1', 'Saw a manta');

      expect((await row('d2')).notes, '');
    });
  });

  group('addWeightIfNone', () {
    const belt = domain.DiveWeight(
      id: '',
      diveId: '',
      weightType: WeightType.belt,
      amountKg: 4,
    );

    test('adds the weight to a dive that has none', () async {
      await seed('d1');

      final written = await repository.addWeightIfNone('d1', belt);

      expect(written, isTrue);
      final rows = await weights('d1');
      expect(rows, hasLength(1));
      expect(rows.single.amountKg, 4);
      expect(rows.single.weightType, WeightType.belt.name);
      expect(rows.single.id, isNotEmpty);
    });

    test('leaves a dive that already records weight untouched', () async {
      await seed('d1');
      await repository.bulkAddWeights(
        ['d1'],
        [belt.copyWith(weightType: WeightType.integrated, amountKg: 6)],
      );

      final written = await repository.addWeightIfNone('d1', belt);

      expect(written, isFalse);
      final rows = await weights('d1');
      expect(rows, hasLength(1));
      expect(rows.single.amountKg, 6);
    });
  });
}
