import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide DiveComputer;
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';

import '../../../../helpers/test_database.dart';

/// A sweep that always fails, to prove the download survives it.
class _ThrowingGpsTrackMatchService extends GpsTrackMatchService {
  _ThrowingGpsTrackMatchService()
    : super(
        trackRepository: GpsTrackRepository(),
        diveRepository: DiveRepository(),
      );

  @override
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    throw StateError('sweep failed');
  }
}

/// Issue #3704: a dive computer download through the import wizard stamps
/// entry and exit GPS from a recorded surface track covering the dive, before
/// the summary step, and a failed sweep never fails the download.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepository;
  late DiveComputerRepository computerRepository;
  late GpsTrackRepository trackRepository;

  const diverId = 'diver-1';
  // Wall-clock-as-UTC, the frame both dives and tracks are stored in.
  final trackStart = DateTime.utc(2026, 7, 1, 8);
  final diveStart = DateTime.utc(2026, 7, 1, 9);
  final trackEnd = DateTime.utc(2026, 7, 1, 11);

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepository = DiveRepository();
    computerRepository = DiveComputerRepository();
    trackRepository = GpsTrackRepository();

    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value(diverId),
            name: const Value('Test Diver'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  /// A finished boat-day track: lat 10 -> 11 and lon 20 -> 21 over three
  /// hours, so the dive's entry (one hour in) sits a third of the way along.
  /// A point every 15 minutes: the matcher refuses to interpolate across a
  /// gap of over an hour, which it reads as an interrupted recording.
  Future<void> seedTrack() async {
    final id = await trackRepository.startTrack(
      startTimeMs: trackStart.millisecondsSinceEpoch,
      tzOffsetMinutes: 0,
    );
    const steps = 12;
    final startSeconds = trackStart.millisecondsSinceEpoch ~/ 1000;
    final spanSeconds = trackEnd.difference(trackStart).inSeconds;
    for (var i = 0; i <= steps; i++) {
      await trackRepository.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: startSeconds + spanSeconds * i ~/ steps,
          latitude: 10 + i / steps,
          longitude: 20 + i / steps,
        ),
      );
    }
    await trackRepository.finalizeTrack(
      id,
      endTimeMs: trackEnd.millisecondsSinceEpoch,
    );
  }

  /// The wizard's notifier over a real dive computer adapter holding one
  /// downloaded dive, with its bundle built and every dive selected.
  Future<ImportWizardNotifier> wizardWith(
    GpsTrackMatchService gpsTrackMatchService,
  ) async {
    final computer = await computerRepository.createComputer(
      DiveComputer.create(id: 'computer-1', name: 'Computer', diverId: diverId),
    );
    final importService = DiveImportService(
      repository: computerRepository,
      diveRepository: diveRepository,
    );
    final adapter = DiveComputerAdapter(
      importService: importService,
      computerRepository: computerRepository,
      diveRepository: diveRepository,
      consolidationService: DiveConsolidationService(diveRepository),
      diverId: diverId,
      knownComputer: computer,
    );
    adapter.setDownloadedDives([
      DownloadedDive(
        startTime: diveStart,
        // One hour, so the exit lands two thirds of the way along the track.
        durationSeconds: 3600,
        maxDepth: 18,
        profile: const [
          ProfileSample(timeSeconds: 0, depth: 0),
          ProfileSample(timeSeconds: 600, depth: 18),
          ProfileSample(timeSeconds: 3600, depth: 0),
        ],
      ),
    ]);
    final bundle = await adapter.buildBundle();
    return ImportWizardNotifier(
      adapter,
      gpsTrackMatchService: gpsTrackMatchService,
    )..setBundle(bundle);
  }

  Future<Dive> onlyDive() async => (await db.select(db.dives).get()).single;

  test('a downloaded dive inside a recorded track has its entry and exit '
      'GPS when the wizard reaches the summary', () async {
    await seedTrack();
    final wizard = await wizardWith(
      GpsTrackMatchService(
        trackRepository: trackRepository,
        diveRepository: diveRepository,
      ),
    );

    await wizard.performImport();

    expect(wizard.state.importResult?.errorMessage, isNull);
    expect(
      wizard.state.importResult?.importedCounts[ImportEntityType.dives],
      1,
    );
    final dive = await onlyDive();
    expect(dive.entryLatitude, closeTo(10 + 1 / 3, 1e-6));
    expect(dive.entryLongitude, closeTo(20 + 1 / 3, 1e-6));
    expect(dive.exitLatitude, closeTo(10 + 2 / 3, 1e-6));
    expect(dive.exitLongitude, closeTo(20 + 2 / 3, 1e-6));
  });

  test('a failing GPS sweep never fails the download', () async {
    await seedTrack();
    final wizard = await wizardWith(_ThrowingGpsTrackMatchService());

    await wizard.performImport();

    expect(wizard.state.error, isNull);
    expect(wizard.state.importResult?.errorMessage, isNull);
    expect(
      wizard.state.importResult?.importedCounts[ImportEntityType.dives],
      1,
    );
    expect((await onlyDive()).entryLatitude, isNull);
  });
}
