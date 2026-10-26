import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide DiveComputer, EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
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
  /// downloaded dive, with its bundle built and every dive selected. With
  /// [matching], the download is flagged as a duplicate of that dive.
  Future<ImportWizardNotifier> wizardWith(
    GpsTrackMatchService gpsTrackMatchService, {
    String? matching,
    DiveEquipmentDefaulter? equipmentDefaulter,
  }) async {
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
    final built = await adapter.buildBundle();
    final bundle = matching == null
        ? built
        : ImportBundle(
            source: built.source,
            groups: {
              ImportEntityType.dives: EntityGroup(
                items: built.groups[ImportEntityType.dives]!.items,
                duplicateIndices: {0},
                matchResults: {
                  0: DiveMatchResult(
                    diveId: matching,
                    score: 0.9,
                    timeDifferenceMs: 0,
                  ),
                },
              ),
            },
          );
    return ImportWizardNotifier(
      adapter,
      gpsTrackMatchService: gpsTrackMatchService,
      equipmentDefaulter: equipmentDefaulter,
    )..setBundle(bundle);
  }

  Future<Dive> onlyDive() async => (await db.select(db.dives).get()).single;

  GpsTrackMatchService realSweep() => GpsTrackMatchService(
    trackRepository: trackRepository,
    diveRepository: diveRepository,
  );

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

  // A dive already in the log with no position: logged by hand after the
  // track was stopped, so the Stop logging sweep never saw it.
  for (final action in [
    DuplicateAction.consolidate,
    DuplicateAction.replaceSource,
  ]) {
    test('a hand-logged dive a download is merged into (${action.name}) '
        'gets its GPS from the track', () async {
      await seedTrack();
      await diveRepository.createDive(
        domain.Dive(
          id: 'hand-logged',
          dateTime: diveStart,
          entryTime: diveStart,
          runtime: const Duration(hours: 1),
          maxDepth: 18,
          diverId: diverId,
        ),
      );
      final wizard = await wizardWith(realSweep(), matching: 'hand-logged');
      wizard.setDuplicateAction(ImportEntityType.dives, 0, action);

      await wizard.performImport();

      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('hand-logged'))).getSingle();
      expect(dive.entryLatitude, closeTo(10 + 1 / 3, 1e-6));
      expect(dive.entryLongitude, closeTo(20 + 1 / 3, 1e-6));
    });
  }

  for (final hasDefault in [true, false]) {
    test(
      'a downloaded dive positioned inside a geofence ends up with the '
      'geofenced set (${hasDefault ? 'replacing the default' : 'no default set'})',
      () async {
        final now = DateTime.now();
        for (final id in ['warm-suit', 'drysuit']) {
          await db
              .into(db.equipment)
              .insert(
                EquipmentCompanion.insert(
                  id: id,
                  name: id,
                  type: 'wetsuit',
                  createdAt: now.millisecondsSinceEpoch,
                  updatedAt: now.millisecondsSinceEpoch,
                ),
              );
        }
        final sets = EquipmentSetRepository();
        if (hasDefault) {
          await sets.createSet(
            EquipmentSet(
              id: 'warm',
              diverId: diverId,
              name: 'Warm',
              equipmentIds: const ['warm-suit'],
              isDefault: true,
              createdAt: now,
              updatedAt: now,
            ),
          );
          await sets.setAsDefault('warm', diverId: diverId);
        }
        await sets.createSet(
          EquipmentSet(
            id: 'cold',
            diverId: diverId,
            name: 'Cold',
            equipmentIds: const ['drysuit'],
            createdAt: now,
            updatedAt: now,
          ),
        );
        // Around the dive's entry, a third of the way along the track.
        await sets.addGeofence(
          EquipmentSetGeofence(
            id: 'fence',
            setId: 'cold',
            latitude: 10 + 1 / 3,
            longitude: 20 + 1 / 3,
            radiusMeters: 5000,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await seedTrack();
        final wizard = await wizardWith(
          realSweep(),
          equipmentDefaulter: DiveEquipmentDefaulter(),
        );

        await wizard.performImport();

        final dive = await onlyDive();
        expect(dive.entryLatitude, isNotNull);
        final gear = await (db.select(
          db.diveEquipment,
        )..where((t) => t.diveId.equals(dive.id))).get();
        final bySet = {for (final r in gear) r.equipmentId: r.viaSetId};
        expect(bySet['drysuit'], 'cold');
        expect(bySet, isNot(contains('warm-suit')));
        // The computer's own equipment entry came with the download, not a set.
        expect(bySet.values.where((v) => v != null), ['cold']);
      },
    );
  }
}
