import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive, DiveComputer;
import 'package:submersion/features/dive_import/data/services/apple_watch_computer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

/// A download that lands on a dive the watch recorded (issue #637) defaults
/// to consolidating, because the watch dive now names its own computer: the
/// download's review reads it through getComputerIdForDive as
/// matchedComputerId, and a match from another computer at a score of 0.85
/// or more defaults to consolidate (pinned in import_wizard_notifier_test).
/// The target keeps its readings as the main profile and the download joins
/// demoted (pinned in dive_consolidation_service_series_test).
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late DiveComputerRepository computers;
  final created = DateTime.utc(2026, 7, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    computers = DiveComputerRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'a',
            name: 'a',
            createdAt: created,
            updatedAt: created,
          ),
        );
  });

  tearDown(() => tearDownTestDatabase());

  Future<Dive> watchDive() => dives.createDive(
    Dive(
      id: '',
      diverId: 'a',
      dateTime: DateTime.utc(2026, 7, 17, 10),
      entryTime: DateTime.utc(2026, 7, 17, 10),
      exitTime: DateTime.utc(2026, 7, 17, 10, 50),
      maxDepth: 18,
    ),
  );

  test('a dive imported from the watch reports the watch as its computer, '
      'so a download onto it offers to consolidate', () async {
    final watch = await appleWatchComputerFor(computers, 'a');
    final dive = await watchDive();
    await computers.attributeDiveToComputer(
      diveId: dive.id,
      computerId: watch.id,
    );

    expect(await dives.getComputerIdForDive(dive.id), watch.id);
  });

  test('a watch dive from before this change names no computer, so its row '
      'waits for the diver', () async {
    final dive = await watchDive();

    expect(await dives.getComputerIdForDive(dive.id), isNull);
  });
}
