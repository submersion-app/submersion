import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_profiles.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

/// Records the id list of every batched profile read, then reads for real.
///
/// Delegates rather than extends: [DiveRepository] has only a factory
/// constructor. Any other member is a read this loader must not make.
class _RecordingDiveRepository implements DiveRepository {
  final _real = DiveRepository();
  final reads = <List<String>>[];

  @override
  Future<Map<String, List<DiveProfilePoint>>> getMergedProfilesForDives(
    List<String> diveIds,
  ) {
    reads.add(List.of(diveIds));
    return _real.getMergedProfilesForDives(diveIds);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('unexpected read: ${invocation.memberName}');
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.utc(2026, 3, 1);
    await DiverRepository().createDiver(
      Diver(
        id: 'me',
        name: 'Me',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    Future<void> dive(String id, int number, List<DiveProfilePoint> profile) =>
        DiveRepository().createDive(
          Dive(
            id: id,
            diverId: 'me',
            diveNumber: number,
            dateTime: DateTime.utc(2026, 3, number, 9),
            profile: profile,
          ),
        );
    await dive('dive-1', 1, const [
      DiveProfilePoint(timestamp: 0, depth: 1.0),
      DiveProfilePoint(timestamp: 30, depth: 3.0),
    ]);
    await dive('dive-2', 2, const []);
    await dive('dive-3', 3, const [
      DiveProfilePoint(timestamp: 0, depth: 2.0),
      DiveProfilePoint(timestamp: 60, depth: 9.0),
    ]);
  });

  tearDown(tearDownTestDatabase);

  /// The list the full export starts from: no dive carries its profile.
  Future<List<Dive>> listView() async {
    final dives = await DiveRepository().getAllDives(diverId: 'me');
    dives.sort((a, b) => a.diveNumber!.compareTo(b.diveNumber!));
    expect(dives.map((d) => d.profile), everyElement(isEmpty));
    return dives;
  }

  test('attaches each dive its own recorded samples, in order', () async {
    final result = await attachMergedProfiles(
      DiveRepository(),
      await listView(),
      chunkSize: 2,
    );

    expect(result.map((d) => d.id), ['dive-1', 'dive-2', 'dive-3']);
    expect(result[0].profile.map((p) => (p.timestamp, p.depth)), [
      (0, 1.0),
      (30, 3.0),
    ]);
    expect(result[1].profile, isEmpty);
    // The last chunk holds only this dive, so a dropped tail loses it.
    expect(result[2].profile.map((p) => (p.timestamp, p.depth)), [
      (0, 2.0),
      (60, 9.0),
    ]);
  });

  test('reads no more than chunkSize dives at a time', () async {
    final repository = _RecordingDiveRepository();

    await attachMergedProfiles(repository, await listView(), chunkSize: 2);

    expect(repository.reads, [
      ['dive-1', 'dive-2'],
      ['dive-3'],
    ]);
  });

  test('an empty dive list reads nothing', () async {
    final repository = _RecordingDiveRepository();

    expect(await attachMergedProfiles(repository, const []), isEmpty);
    expect(repository.reads, isEmpty);
  });
}
