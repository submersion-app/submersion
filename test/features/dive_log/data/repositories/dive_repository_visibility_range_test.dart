import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// One visibility shape per dive (issue #3226).
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
    double? meters,
    double? min,
    double? max,
    Visibility? legacy,
  }) => domain.Dive(
    id: '',
    dateTime: DateTime.utc(2026, 7, 1, 10),
    visibilityMeters: meters,
    visibilityMinMeters: min,
    visibilityMaxMeters: max,
    visibility: legacy,
  );

  Future<Map<String, Object?>> raw(String id) async {
    final row = await db
        .customSelect(
          'SELECT visibility, visibility_meters, visibility_min_meters, '
          'visibility_max_meters FROM dives WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return row.data;
  }

  test('a range round-trips, open ends included', () async {
    final closed = await repository.createDive(makeDive(min: 6, max: 12));
    final open = await repository.createDive(makeDive(min: 12));

    expect(
      (await repository.getDiveById(closed.id))!.visibilityRange,
      const VisibilityRange(minM: 6, maxM: 12),
    );
    expect(
      (await repository.getDiveById(open.id))!.visibilityRange,
      const VisibilityRange(minM: 12),
    );
  });

  test('writing a range clears the legacy bucket', () async {
    final created = await repository.createDive(
      makeDive(legacy: Visibility.moderate),
    );
    await repository.updateDive(
      created.copyWith(visibilityMinMeters: 6, visibilityMaxMeters: 12),
    );

    final row = await raw(created.id);
    expect(row['visibility'], isNull);
    expect(row['visibility_min_meters'], 6.0);
    expect(row['visibility_max_meters'], 12.0);
  });

  test('a measured distance wins over a range on the same entity', () async {
    final created = await repository.createDive(
      makeDive(meters: 8, min: 6, max: 12),
    );

    final row = await raw(created.id);
    expect(row['visibility_meters'], 8.0);
    expect(row['visibility_min_meters'], isNull);
    expect(row['visibility_max_meters'], isNull);
  });

  test('writing a measured distance clears a stored range', () async {
    final created = await repository.createDive(makeDive(min: 6, max: 12));
    await repository.updateDive(created.copyWith(visibilityMeters: 9));

    final row = await raw(created.id);
    expect(row['visibility_meters'], 9.0);
    expect(row['visibility_min_meters'], isNull);
    expect(row['visibility_max_meters'], isNull);
  });
}
