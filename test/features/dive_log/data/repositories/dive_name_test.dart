import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  // ignore: unused_local_variable
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.Dive makeDive({String? name, String id = ''}) => domain.Dive(
    id: id,
    dateTime: DateTime.utc(2026, 7, 1, 10, 0),
    name: name,
  );

  group('dive name persistence', () {
    test('createDive and getDiveById round-trip a name', () async {
      final created = await repository.createDive(
        makeDive(name: 'Wreck penetration dive'),
      );
      final loaded = await repository.getDiveById(created.id);
      expect(loaded!.name, 'Wreck penetration dive');
    });

    test('name is null when never set', () async {
      final created = await repository.createDive(makeDive());
      final loaded = await repository.getDiveById(created.id);
      expect(loaded!.name, isNull);
    });

    test('updateDive can set and clear the name', () async {
      final created = await repository.createDive(makeDive());
      await repository.updateDive(created.copyWith(name: 'Training dive 1'));
      var loaded = await repository.getDiveById(created.id);
      expect(loaded!.name, 'Training dive 1');

      // Clearing: copyWith cannot null a field (plain ?? pattern), so build
      // the cleared dive the way the edit form does — a fresh entity.
      await repository.updateDive(makeDive(id: created.id));
      loaded = await repository.getDiveById(created.id);
      expect(loaded!.name, isNull);
    });

    test('getDiveSummaries carries the name', () async {
      await repository.createDive(makeDive(name: 'Night dive'));
      final summaries = await repository.getDiveSummaries(limit: 10);
      expect(summaries, hasLength(1));
      expect(summaries.first.name, 'Night dive');
    });

    test('copyWith preserves name and props includes it', () {
      final a = makeDive(name: 'A');
      final b = makeDive(name: 'B');
      expect(a.copyWith(rating: 5).name, 'A');
      expect(a == b, isFalse); // props must include name
      expect(a == makeDive(name: 'A'), isTrue);
    });
  });
}
