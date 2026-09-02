import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

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

  domain.Dive makeDive({int? rating, String id = ''}) => domain.Dive(
    id: id,
    dateTime: DateTime.utc(2026, 7, 1, 10, 0),
    rating: rating,
  );

  Future<int?> rawRating(String id) async {
    final row = await db
        .customSelect(
          'SELECT rating FROM dives WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return row.read<int?>('rating');
  }

  group('rating persistence', () {
    test('round-trips a rating', () async {
      final created = await repository.createDive(makeDive(rating: 4));
      final loaded = await repository.getDiveById(created.id);
      expect(loaded!.rating, 4);
    });

    test('updateDive clears a rating the diver removed', () async {
      // The edit form maps zero stars to a null rating, so clearing has to
      // survive the companion write. Value.absent() would preserve the old
      // number and leave the diver unable to un-rate a dive at all.
      // Built by construction rather than copyWith: Dive.copyWith uses the
      // `?? this.field` idiom project-wide, so it cannot clear a nullable
      // field, and neither can it stand in for what the form saves.
      final created = await repository.createDive(makeDive(rating: 4));
      expect(await rawRating(created.id), 4);

      await repository.updateDive(makeDive(id: created.id));

      expect(await rawRating(created.id), isNull);
      final loaded = await repository.getDiveById(created.id);
      expect(loaded!.rating, isNull);
    });
  });
}
