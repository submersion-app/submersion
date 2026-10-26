import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/data/services/import_track_stamp.dart';
import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';

/// Records each sweep's ids instead of touching a database.
class _RecordingGpsTrackMatchService extends GpsTrackMatchService {
  _RecordingGpsTrackMatchService({this.fails = false})
    : super(
        trackRepository: GpsTrackRepository(),
        diveRepository: DiveRepository(),
      );

  final bool fails;
  final sweeps = <List<String>?>[];

  @override
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    sweeps.add(limitToIds);
    if (fails) throw StateError('sweep failed');
    return const [];
  }
}

UnifiedImportResult _result({
  List<String> importedDiveIds = const [],
  List<String> updatedExistingDiveIds = const [],
  List<DiverImportOutcome> diverOutcomes = const [],
}) => UnifiedImportResult(
  importedCounts: const {},
  consolidatedCount: 0,
  skippedCount: 0,
  importedDiveIds: importedDiveIds,
  updatedExistingDiveIds: updatedExistingDiveIds,
  diverOutcomes: diverOutcomes,
);

DiverImportOutcome _outcome(String diverId, List<String> diveIds) =>
    DiverImportOutcome(
      diverId: diverId,
      name: diverId,
      isNew: false,
      isActive: false,
      diveIds: diveIds,
    );

void main() {
  test('sweeps only the dives the import wrote', () async {
    final service = _RecordingGpsTrackMatchService();

    await stampImportedDivesFromTracks(
      service,
      _result(importedDiveIds: ['a', 'b']),
    );

    expect(service.sweeps, [
      ['a', 'b'],
    ]);
  });

  test('sweeps every profile\'s dives when the import wrote to several, '
      'as a download sent to another profile reports them', () async {
    final service = _RecordingGpsTrackMatchService();

    await stampImportedDivesFromTracks(
      service,
      _result(
        diverOutcomes: [
          _outcome('me', ['a']),
          _outcome('buddy', ['b', 'c']),
        ],
      ),
    );

    expect(service.sweeps.single, unorderedEquals(['a', 'b', 'c']));
  });

  test('sweeps the existing dives a download was merged into', () async {
    final service = _RecordingGpsTrackMatchService();

    await stampImportedDivesFromTracks(
      service,
      _result(importedDiveIds: ['new'], updatedExistingDiveIds: ['merged']),
    );

    expect(service.sweeps.single, unorderedEquals(['new', 'merged']));
  });

  test('an import that wrote no dives sweeps nothing', () async {
    // An unscoped sweep (null ids) would position every GPS-less dive in
    // the log, which is the Tracks page's job, not an import's.
    final service = _RecordingGpsTrackMatchService();

    await stampImportedDivesFromTracks(service, _result());

    expect(service.sweeps, isEmpty);
  });

  test('a failing sweep does not throw', () async {
    final service = _RecordingGpsTrackMatchService(fails: true);

    await expectLater(
      stampImportedDivesFromTracks(service, _result(importedDiveIds: ['a'])),
      completes,
    );
    expect(service.sweeps, hasLength(1));
  });
}
