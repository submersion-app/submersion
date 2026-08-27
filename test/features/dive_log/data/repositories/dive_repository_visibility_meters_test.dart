import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
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

  domain.Dive makeDive({
    double? visibilityMeters,
    Visibility? visibility,
    String id = '',
  }) => domain.Dive(
    id: id,
    dateTime: DateTime.utc(2026, 7, 1, 10, 0),
    visibilityMeters: visibilityMeters,
    visibility: visibility,
  );

  Future<({String? bucket, double? meters})> rawVisibility(String id) async {
    final row = await db
        .customSelect(
          'SELECT visibility, visibility_meters FROM dives WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return (
      bucket: row.read<String?>('visibility'),
      meters: row.read<double?>('visibility_meters'),
    );
  }

  group('measured visibility persistence', () {
    test('round-trips a measured distance', () async {
      final created = await repository.createDive(
        makeDive(visibilityMeters: 6.0),
      );
      final loaded = await repository.getDiveById(created.id);
      expect(loaded!.visibilityMeters, 6.0);
    });

    test('round-trips a fractional distance without rounding', () async {
      final created = await repository.createDive(
        makeDive(visibilityMeters: 6.4),
      );
      final loaded = await repository.getDiveById(created.id);
      expect(loaded!.visibilityMeters, closeTo(6.4, 0.0001));
    });

    test('is null when never set', () async {
      final created = await repository.createDive(makeDive());
      final loaded = await repository.getDiveById(created.id);
      expect(loaded!.visibilityMeters, isNull);
    });

    test('updateDive can clear a measured distance', () async {
      final created = await repository.createDive(
        makeDive(visibilityMeters: 6.0),
      );
      // Built by construction rather than copyWith: Dive.copyWith uses the
      // `?? this.field` idiom project-wide, so it cannot clear a nullable
      // field. The edit form saves the same way, constructing the dive it
      // wants rather than patching the loaded one.
      await repository.updateDive(makeDive(id: created.id));
      final loaded = await repository.getDiveById(created.id);
      expect(loaded!.visibilityMeters, isNull);
    });
  });

  group('legacy bucket precedence', () {
    test('writing a number clears the legacy bucket', () async {
      // Regression guard for Value.absent() vs Value(null): absent() preserves
      // the existing column on a companion write, which would leave a dive
      // carrying both a measurement and a contradicting bucket.
      final created = await repository.createDive(
        makeDive(visibility: Visibility.moderate),
      );
      expect((await rawVisibility(created.id)).bucket, 'moderate');

      await repository.updateDive(created.copyWith(visibilityMeters: 6.0));

      final raw = await rawVisibility(created.id);
      expect(raw.meters, 6.0);
      expect(
        raw.bucket,
        isNull,
        reason: 'a measured distance supersedes the legacy bucket',
      );
    });

    test(
      'a legacy dive keeps its bucket when an unrelated field changes',
      () async {
        final created = await repository.createDive(
          makeDive(visibility: Visibility.moderate),
        );

        await repository.updateDive(created.copyWith(notes: 'kelp everywhere'));

        final raw = await rawVisibility(created.id);
        expect(raw.bucket, 'moderate');
        expect(raw.meters, isNull);
      },
    );

    test('creating with both keeps only the measurement', () async {
      final created = await repository.createDive(
        makeDive(visibility: Visibility.moderate, visibilityMeters: 6.0),
      );
      final raw = await rawVisibility(created.id);
      expect(raw.meters, 6.0);
      expect(raw.bucket, isNull);
    });

    test('a legacy dive still reads back its bucket entity-side', () async {
      final created = await repository.createDive(
        makeDive(visibility: Visibility.good),
      );
      final loaded = await repository.getDiveById(created.id);
      expect(loaded!.visibility, Visibility.good);
      expect(loaded.visibilityMeters, isNull);
    });
  });
}
