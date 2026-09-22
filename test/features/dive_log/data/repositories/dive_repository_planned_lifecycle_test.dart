import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('summaries carry isPlanned', () async {
    await repository.createPlannedDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9)),
    );
    await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 5, 1, 9), diveNumber: 1),
    );
    final page = await repository.getDiveSummaries(limit: 10);
    expect(page.map((s) => s.isPlanned), [true, false]);
  });

  test(
    'convertPlanToActualDive clears the flag, numbers and keeps the date',
    () async {
      await repository.createDive(
        Dive(id: '', dateTime: DateTime(2026, 5, 1, 9), diveNumber: 7),
      );
      final planned = await repository.createPlannedDive(
        Dive(id: '', dateTime: DateTime(2026, 6, 1, 9)),
      );
      expect(planned.diveNumber, isNull);
      await repository.convertPlanToActualDive(planned.id);
      final promoted = await repository.getDiveById(planned.id);
      expect(promoted?.isPlanned, isFalse);
      expect(promoted?.diveNumber, 8);
      // Dive times read back UTC-flagged; compare the instant, not the zone.
      expect(
        promoted?.dateTime.millisecondsSinceEpoch,
        DateTime(2026, 6, 1, 9).millisecondsSinceEpoch,
      );
    },
  );

  test('renumberAllDives leaves planned dives unnumbered', () async {
    final a = await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 5, 1, 9)),
    );
    final planned = await repository.createPlannedDive(
      Dive(id: '', dateTime: DateTime(2026, 5, 2, 9)),
    );
    final b = await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 5, 3, 9)),
    );
    await repository.assignMissingDiveNumbers();
    expect((await repository.getDiveById(a.id))?.diveNumber, 1);
    expect((await repository.getDiveById(planned.id))?.diveNumber, isNull);
    expect((await repository.getDiveById(b.id))?.diveNumber, 2);
  });
}
