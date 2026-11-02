import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// `dive_data_sources.entry_time` and `exit_time` are Drift `dateTime()`
/// columns, written from a computer's wall clock flagged UTC. Drift reads them
/// back flagged local, so a mapper that passes them on unchanged shows them
/// shifted by the device's offset. Meaningful only away from UTC, which is
/// what CI's Sydney zone gives.
void main() {
  late AppDatabase db;
  late DiveRepository repository;
  final entry = DateTime.utc(2024, 5, 1, 10);
  final exit = DateTime.utc(2024, 5, 1, 10, 45);

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: entry.millisecondsSinceEpoch,
            entryTime: Value(entry.millisecondsSinceEpoch),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 's1',
            diveId: 'd1',
            isPrimary: const Value(true),
            entryTime: Value(entry),
            exitTime: Value(exit),
            importedAt: DateTime.utc(2024),
            createdAt: DateTime.utc(2024),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  test('a source reads back the wall clock it was written with', () async {
    final source = (await repository.getDataSources('d1')).single;

    expect(source.entryTime, entry);
    expect(source.exitTime, exit);
  });

  test('a source shows the same clock as its dive', () async {
    const units = UnitFormatter(
      AppSettings(timeFormat: TimeFormat.twentyFourHour),
    );
    final source = (await repository.getDataSources('d1')).single;
    final dive = await repository.getDiveById('d1');

    expect(units.formatTime(source.entryTime), '10:00');
    expect(
      units.formatTime(source.entryTime),
      units.formatTime(dive!.entryTime),
    );
  });

  test('an exported source carries the same wall clock', () async {
    final source = (await repository.getSourcesForExport(['d1'])).single;

    expect(source.entryTime, entry);
    expect(source.exitTime, exit);
  });
}
