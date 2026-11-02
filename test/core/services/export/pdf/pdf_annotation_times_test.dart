import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/export/pdf/pdf_annotation_times.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

/// Counts the reads, or fails them, to show what an export pays for.
class _SpyRepository extends DiveComputerRepository {
  _SpyRepository({this.fail = false});

  final bool fail;
  final asked = <List<String>>[];

  @override
  Future<Map<String, List<DiveProfileEvent>>> getEventsForDives(
    List<String> diveIds,
  ) async {
    asked.add(diveIds);
    if (fail) throw StateError('unreadable');
    return super.getEventsForDives(diveIds);
  }
}

Dive _dive(String id, String notes) =>
    Dive(id: id, dateTime: DateTime.utc(2026, 5, 3, 10), notes: notes);

void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  Future<void> seedEvent(String id, String diveId, int timestamp) =>
      db.customStatement(
        'INSERT INTO dive_profile_events '
        '(id, dive_id, timestamp, event_type, source, description, created_at) '
        "VALUES (?, ?, ?, 'annotation', 'user', 'w', 1)",
        [id, diveId, timestamp],
      );

  test('gives each dive its linked annotations\' times', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await seedEvent('a1', 'd1', 125);
    await seedEvent('orphan', 'd1', 300);

    final times = await annotationTimesForPdf([
      _dive('d1', '[w](annotation:a1)'),
    ]);

    expect(times, {
      'd1': {'a1': '2:05'},
    });
  });

  test('reads nothing for a logbook with no annotation links', () async {
    final spy = _SpyRepository();

    final times = await annotationTimesForPdf([
      _dive('d1', 'plain words'),
      _dive('d2', ''),
    ], repository: spy);

    expect(times, isEmpty);
    expect(spy.asked, isEmpty);
  });

  test('reads only the dives whose Notes link one', () async {
    final spy = _SpyRepository();

    await annotationTimesForPdf([
      _dive('d1', 'plain words'),
      _dive('d2', '[w](annotation:a1)'),
    ], repository: spy);

    expect(spy.asked, [
      ['d2'],
    ]);
  });

  test('a failed read leaves the words to print alone', () async {
    final times = await annotationTimesForPdf([
      _dive('d1', '[w](annotation:a1)'),
    ], repository: _SpyRepository(fail: true));

    expect(times, isEmpty);
  });
}
