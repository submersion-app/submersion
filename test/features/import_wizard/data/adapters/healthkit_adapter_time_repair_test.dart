import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/import_wizard/data/adapters/healthkit_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/pre_dive/data/services/checklist_dive_linker.dart';

import 'healthkit_adapter_test.mocks.dart';

// Every time below is built from explicit UTC fields, never from the device
// zone, so the tests fail without the fix west of UTC, east of it and in UTC
// CI alike. The workout started at 09:30 on the diver's watch at UTC-5, the
// instant 14:30Z.
final _instant = DateTime.utc(2026, 3, 15, 14, 30);
final _wallClock = DateTime.utc(2026, 3, 15, 9, 30);
const _workoutId = 'healthkit-workout-1';
const _duration = Duration(minutes: 42);

ImportedDive _incoming({
  String sourceId = _workoutId,
  DateTime? startTime,
  DateTime? startInstant,
}) {
  final start = startTime ?? _wallClock;
  return ImportedDive(
    sourceId: sourceId,
    source: ImportSource.appleWatch,
    startTime: start,
    startInstant: startInstant ?? _instant,
    endTime: start.add(_duration),
    maxDepth: 18.5,
    profile: const [],
  );
}

/// An Apple Watch dive as the import saved it: before #2811 its start was
/// the real instant, after it the wall clock.
Dive _saved({
  String id = 'dive-1',
  required DateTime start,
  String? importSource = 'appleWatch',
  String? importId = _workoutId,
}) {
  return Dive(
    id: id,
    diverId: 'diver-1',
    dateTime: start,
    entryTime: start,
    exitTime: start.add(_duration),
    runtime: _duration,
    maxDepth: 18.5,
    importSource: importSource,
    importId: importId,
    notes: '',
    diveTypeIds: const [''],
    tanks: const [],
    profile: const [],
    gear: looseGear(const []),
    photoIds: const [],
    sightings: const [],
  );
}

/// Records the dives the adapter asks to relink, and links nothing.
class _RecordingLinker implements ChecklistDiveLinker {
  final calls = <({String diveId, String? diverId, DateTime diveStart})>[];

  @override
  Future<bool> autoLinkForDive({
    required String diveId,
    required String? diverId,
    required DateTime diveStart,
  }) async {
    calls.add((diveId: diveId, diverId: diverId, diveStart: diveStart));
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockDiveRepository repo;
  late _RecordingLinker linker;
  late MockDiveMatcher matcher;
  late HealthKitAdapter adapter;

  setUp(() {
    repo = MockDiveRepository();
    matcher = MockDiveMatcher();
    linker = _RecordingLinker();
    adapter = HealthKitAdapter(
      healthService: MockHealthImportService(),
      diveMatcher: matcher,
      converter: MockImportedDiveConverter(),
      diveRepository: repo,
      diverId: 'diver-1',
      checklistLinker: linker,
    );
    // Five hours apart, the time-based matcher sees no likeness at all.
    when(
      matcher.calculateMatchScore(
        wearableStartTime: anyNamed('wearableStartTime'),
        wearableMaxDepth: anyNamed('wearableMaxDepth'),
        wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
        existingStartTime: anyNamed('existingStartTime'),
        existingMaxDepth: anyNamed('existingMaxDepth'),
        existingDurationSeconds: anyNamed('existingDurationSeconds'),
      ),
    ).thenReturn(0.0);
  });

  Future<ImportBundle> reviewed(List<ImportedDive> incoming, List<Dive> saved) {
    when(repo.getAllDives(diverId: 'diver-1')).thenAnswer((_) async => saved);
    adapter.setParsedDives(incoming);
    return adapter.buildBundle().then(adapter.checkDuplicates);
  }

  group('re-importing an Apple Watch dive saved before #2811 (#2812)', () {
    test(
      'is a duplicate of its saved copy even five hours off, by workout id',
      () async {
        final bundle = await reviewed([_incoming()], [_saved(start: _instant)]);

        final dives = bundle.groups[ImportEntityType.dives]!;
        expect(dives.duplicateIndices, {0});
        expect(dives.matchResults![0]!.diveId, 'dive-1');
        expect(dives.matchResults![0]!.score, 1.0);
        // Measured against the corrected start, which is what the dive will
        // show once the import has run.
        expect(dives.matchResults![0]!.timeDifferenceMs, 0);
        // A re-read of a saved workout, which the wizard defaults to skip.
        expect(dives.matchResults![0]!.matchedExistingSource, isTrue);
      },
    );

    test(
      'keeps the saved dive away from another workout at its old time',
      () async {
        // Workout B really started at 14:30, the time workout A's dive was
        // saved at before #2811. A's dive is A's, whatever the score says.
        when(
          matcher.calculateMatchScore(
            wearableStartTime: anyNamed('wearableStartTime'),
            wearableMaxDepth: anyNamed('wearableMaxDepth'),
            wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
            existingStartTime: anyNamed('existingStartTime'),
            existingMaxDepth: anyNamed('existingMaxDepth'),
            existingDurationSeconds: anyNamed('existingDurationSeconds'),
          ),
        ).thenReturn(0.9);
        final bundle = await reviewed(
          [
            _incoming(),
            _incoming(
              sourceId: 'healthkit-workout-2',
              startTime: _instant,
              startInstant: DateTime.utc(2026, 3, 15, 19, 30),
            ),
          ],
          [_saved(start: _instant)],
        );

        final dives = bundle.groups[ImportEntityType.dives]!;
        expect(dives.duplicateIndices, {0});
        expect(dives.matchResults![1], isNull);
      },
    );

    test('corrects every saved copy of the workout', () async {
      final bundle = await reviewed(
        [_incoming()],
        [_saved(start: _instant), _saved(id: 'dive-2', start: _instant)],
      );

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {},
      }, {});

      verify(
        repo.shiftDiveTimes(['dive-1', 'dive-2'], const Duration(hours: -5)),
      );
      expect(result.timesCorrectedCount, 2);
      // A corrected time can move a dive into a recorded GPS track.
      expect(result.updatedExistingDiveIds, ['dive-1', 'dive-2']);
    });

    test('moves the saved dive to the wall clock and counts it', () async {
      final bundle = await reviewed([_incoming()], [_saved(start: _instant)]);

      final result = await adapter.performImport(
        bundle,
        {ImportEntityType.dives: <int>{}},
        {
          ImportEntityType.dives: {0: DuplicateAction.skip},
        },
      );

      verify(repo.shiftDiveTimes(['dive-1'], const Duration(hours: -5)));
      verifyNever(repo.createDive(any));
      expect(result.timesCorrectedCount, 1);
      expect(result.skippedCount, 1);
    });

    test('relinks checklist runs against the corrected start', () async {
      final bundle = await reviewed([_incoming()], [_saved(start: _instant)]);

      await adapter.performImport(bundle, {ImportEntityType.dives: {}}, {});

      expect(linker.calls, [
        (diveId: 'dive-1', diverId: 'diver-1', diveStart: _wallClock),
      ]);
    });

    test('corrects the saved dive only once per review', () async {
      final bundle = await reviewed([_incoming()], [_saved(start: _instant)]);

      await adapter.performImport(bundle, {ImportEntityType.dives: {}}, {});
      final again = await adapter.performImport(bundle, {
        ImportEntityType.dives: {},
      }, {});

      verify(repo.shiftDiveTimes(any, any)).called(1);
      expect(again.timesCorrectedCount, 0);
    });

    test('shifts each dive by its own offset across a DST change', () async {
      // 06:30 at UTC-4 in summer, the instant 10:30Z.
      final summerInstant = DateTime.utc(2026, 7, 4, 10, 30);
      final summerWall = DateTime.utc(2026, 7, 4, 6, 30);
      final bundle = await reviewed(
        [
          _incoming(),
          _incoming(
            sourceId: 'healthkit-workout-2',
            startTime: summerWall,
            startInstant: summerInstant,
          ),
        ],
        [
          _saved(start: _instant),
          _saved(
            id: 'dive-2',
            start: summerInstant,
            importId: 'healthkit-workout-2',
          ),
        ],
      );

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {},
      }, {});

      verify(repo.shiftDiveTimes(['dive-1'], const Duration(hours: -5)));
      verify(repo.shiftDiveTimes(['dive-2'], const Duration(hours: -4)));
      expect(result.timesCorrectedCount, 2);
    });
  });

  group('leaves a saved Apple Watch dive alone', () {
    Future<void> expectUntouched(
      List<ImportedDive> incoming,
      List<Dive> saved,
    ) async {
      final bundle = await reviewed(incoming, saved);
      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {},
      }, {});
      verifyNever(repo.shiftDiveTimes(any, any));
      expect(result.timesCorrectedCount, 0);
      expect(linker.calls, isEmpty);
    }

    test('already at the wall clock (saved after #2811)', () async {
      await expectUntouched([_incoming()], [_saved(start: _wallClock)]);
    });

    test('whose time the diver has since changed by hand', () async {
      await expectUntouched(
        [_incoming()],
        [_saved(start: _instant.add(const Duration(minutes: 3)))],
      );
    });

    test('imported in UTC, where instant and wall clock agree', () async {
      await expectUntouched(
        [_incoming(startTime: _instant, startInstant: _instant)],
        [_saved(start: _instant)],
      );
    });

    test('from another workout at the same instant', () async {
      await expectUntouched(
        [_incoming()],
        [_saved(start: _instant, importId: 'healthkit-workout-9')],
      );
    });

    test('carrying the id but not from Apple Watch', () async {
      await expectUntouched(
        [_incoming()],
        [_saved(start: _instant, importSource: 'garmin')],
      );
    });

    test('when the source reports no instant', () async {
      final bundle = await reviewed(
        [
          ImportedDive(
            sourceId: _workoutId,
            source: ImportSource.appleWatch,
            startTime: _wallClock,
            endTime: _wallClock.add(_duration),
            maxDepth: 18.5,
            profile: const [],
          ),
        ],
        [_saved(start: _instant)],
      );
      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {},
      }, {});
      verifyNever(repo.shiftDiveTimes(any, any));
      expect(result.timesCorrectedCount, 0);
    });
  });
}
