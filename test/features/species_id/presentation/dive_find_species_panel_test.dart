import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_section.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/services/dive_species_run.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/dive_species_run_state.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/presentation/providers/dive_species_run_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_review_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_review_banner.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../media/presentation/support/media_widget_harness.dart';
import '../domain/manifest_fixture.dart';

/// A run whose state a test sets.
class _FixedRun extends DiveSpeciesRun {
  _FixedRun([Map<String, DiveSpeciesRunState> initial = const {}])
    : super(
        mediaForDive: (_) async => const [],
        diveLocation: (_) async => (exists: true, site: null, entry: null),
        request: (_, _) async => RunItemOutcome.done,
        cancel: (_) {},
        applyAll: (_, _) async => 0,
        databaseGeneration: () => 0,
      ) {
    state = initial;
  }
}

/// Records the dives a run was started for, running nothing.
class _RecordingRun extends _FixedRun {
  final started = <String>[];

  /// Whether each started run was a fresh one (issue #4825).
  final fresh = <bool>[];

  @override
  Future<void> start(String diveId, {bool fresh = false}) async {
    started.add(diveId);
    this.fresh.add(fresh);
  }
}

/// Find species on a dive, and the ways to Species to review (issue #4727).
void main() {
  final dive = Dive(id: 'd1', dateTime: DateTime.utc(2026, 3, 9));
  final pack = InstalledPack(
    manifest: SpeciesPackManifest.parse(manifestJson()),
    directory: '/pack',
    detectorPaths: const ['/pack/detector.mlpackage'],
    classifierPath: '/pack/classifier.mlpackage',
  );

  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    int toReview = 0,
    InstalledPack? installed,
    Map<String, DiveSpeciesRunState> runs = const {},
    bool checked = false,
    bool unlocked = false,
    DiveSpeciesRun? run,
    List<MediaItem>? media,
    Set<String> upToDate = const {},
    bool autoApply = false,
    Future<bool> Function(MediaItem item)? libraryOriginalHere,
    bool promptWanted = false,
  }) async {
    final controller = RecordEditController<Dive>(onSave: (_) async {});
    addTearDown(controller.dispose);
    if (unlocked) controller.unlock(dive);
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          diveSightingsProvider('d1').overrideWith((ref) async => const []),
          diveSpeciesPhotoCountsProvider(
            'd1',
          ).overrideWith((ref) async => const {}),
          speciesReviewCountProvider(
            const DiveReviewScope('d1'),
          ).overrideWith((ref) async => toReview),
          installedSpeciesPackProvider.overrideWith((ref) async => installed),
          autoApplyProvider.overrideWith(
            (ref) => AutoApplyNotifier.unstored(autoApply),
          ),
          mediaForDiveProvider('d1').overrideWith(
            (ref) async => media ?? [testMediaItem(id: 'p1', diveId: 'd1')],
          ),
          diveMediaUpToDateProvider('d1').overrideWith((ref) async => upToDate),
          libraryOriginalHereProvider.overrideWithValue(
            libraryOriginalHere ?? (_) async => true,
          ),
          diveSpeciesCheckedProvider('d1').overrideWith((ref) async => checked),
          diveSpeciesRunProvider.overrideWith((ref) => run ?? _FixedRun(runs)),
          speciesDownloadPromptProvider.overrideWithValue(promptWanted),
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecordEditScope<Dive>(
              controller: controller,
              child: DiveSightingsSection(dive: dive, topGap: 0),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a dive with no sightings shows Find species when a model is '
      'installed', (tester) async {
    await pumpCard(tester, installed: pack);
    expect(find.byKey(const ValueKey('dive_species_find')), findsOneWidget);
    expect(find.text('Find species in photos'), findsOneWidget);
  });

  testWidgets('no panel while the dive is unlocked', (tester) async {
    await pumpCard(tester, installed: pack, toReview: 3, unlocked: true);
    expect(find.byKey(const ValueKey('dive_species_find')), findsNothing);
    expect(find.text('3 species to review'), findsNothing);
  });

  testWidgets('no card at all with no model and nothing to review', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.byKey(const ValueKey('dive_species_find')), findsNothing);
    expect(find.text('Marine life'), findsNothing);
  });

  group('with no model (#4773)', () {
    final prompt = find.byKey(const ValueKey('species_download_prompt'));

    testWidgets('a dive with photos offers the download', (tester) async {
      await pumpCard(tester, promptWanted: true);
      expect(prompt, findsOneWidget);
      expect(find.text('Species'), findsOneWidget);
    });

    testWidgets('a dive with no photos or videos offers nothing', (
      tester,
    ) async {
      await pumpCard(tester, promptWanted: true, media: const []);
      expect(prompt, findsNothing);
      expect(find.text('Species'), findsNothing);
    });

    testWidgets('no offer while the dive is unlocked', (tester) async {
      await pumpCard(tester, promptWanted: true, unlocked: true);
      expect(prompt, findsNothing);
    });
  });

  testWidgets('with the feature off, the app\'s tags still lead to the '
      'review', (tester) async {
    marineLifeIdEnabled = false;
    await pumpCard(tester, toReview: 2, installed: pack);
    expect(find.byKey(const ValueKey('dive_species_find')), findsNothing);
    expect(find.text('2 species to review'), findsOneWidget);
  });

  testWidgets('a run in progress', (tester) async {
    await pumpCard(
      tester,
      installed: pack,
      runs: {
        'd1': const DiveSpeciesRunState(
          diveId: 'd1',
          phase: DiveRunPhase.running,
          total: 49,
          done: 12,
        ),
      },
    );
    expect(find.text('Finding species: 12 of 49'), findsOneWidget);
  });

  testWidgets('too warm, with Resume', (tester) async {
    await pumpCard(
      tester,
      installed: pack,
      runs: {
        'd1': const DiveSpeciesRunState(
          diveId: 'd1',
          phase: DiveRunPhase.paused,
          pauseReason: DiveRunPause.tooHot,
        ),
      },
    );
    expect(find.text('Paused: device too warm'), findsOneWidget);
    expect(find.byKey(const ValueKey('dive_species_resume')), findsOneWidget);
  });

  testWidgets('a finished run says what it did, in the right plurals', (
    tester,
  ) async {
    await pumpCard(
      tester,
      installed: pack,
      toReview: 0,
      runs: {
        'd1': const DiveSpeciesRunState(
          diveId: 'd1',
          phase: DiveRunPhase.finished,
          total: 1,
          done: 1,
          summary: DiveRunSummary(photos: 1, speciesTagged: 1),
        ),
      },
    );
    expect(
      find.text('Checked 1 photo and 0 videos. Tagged 1 species; 0 to review.'),
      findsOneWidget,
    );
  });

  testWidgets('all checked, but something to review: a run can still apply '
      'it', (tester) async {
    await pumpCard(
      tester,
      installed: pack,
      toReview: 2,
      checked: true,
      autoApply: true,
    );
    expect(find.text('Find species in photos'), findsOneWidget);
  });

  testWidgets('all checked with something to review, but auto-apply off: '
      'a run would do nothing, so the dive can only be checked again', (
    tester,
  ) async {
    await pumpCard(tester, installed: pack, toReview: 2, checked: true);
    expect(find.text('Check again'), findsOneWidget);
    expect(find.text('Find species in photos'), findsNothing);
  });

  testWidgets('all checked with something to review, but the pack is never '
      'confident: a run would do nothing', (tester) async {
    final never = InstalledPack(
      manifest: SpeciesPackManifest.parse(
        manifestJson((m) {
          final naming = m['naming']! as Map;
          naming['confidentScore'] = 1.01;
          naming['confidentScoreNoLocation'] = 1.01;
        }),
      ),
      directory: '/pack',
      detectorPaths: const ['/pack/detector.mlpackage'],
      classifierPath: '/pack/classifier.mlpackage',
    );
    await pumpCard(
      tester,
      installed: never,
      toReview: 2,
      checked: true,
      autoApply: true,
    );
    expect(find.text('Check again'), findsOneWidget);
  });

  group('an up to date dive (issue #4825)', () {
    final again = find.byKey(const ValueKey('dive_species_check_again'));
    final confirm = find.byKey(
      const ValueKey('dive_species_check_again_confirm'),
    );
    // In the photo library, with its original on this device.
    final here = testMediaItem(
      id: 'p1',
      diveId: 'd1',
    ).copyWith(platformAssetId: 'asset-1');

    testWidgets('offers Check again, enabled', (tester) async {
      await pumpCard(tester, installed: pack, checked: true);
      expect(find.text('Check again'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(again).onPressed, isNotNull);
      expect(find.byKey(const ValueKey('dive_species_find')), findsNothing);
    });

    testWidgets('asks first, saying dismissed suggestions come back', (
      tester,
    ) async {
      final run = _RecordingRun();
      await pumpCard(tester, installed: pack, checked: true, run: run);
      await tester.tap(again);
      await tester.pumpAndSettle();
      expect(find.text('Check this dive again?'), findsOneWidget);
      expect(
        find.textContaining('Suggestions you dismissed come back.'),
        findsOneWidget,
      );
      expect(run.started, isEmpty);
    });

    testWidgets('confirmed, it starts a fresh run', (tester) async {
      final run = _RecordingRun();
      await pumpCard(
        tester,
        installed: pack,
        checked: true,
        run: run,
        media: [here],
      );
      await tester.tap(again);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(run.started, ['d1']);
      expect(run.fresh, [true]);
    });

    testWidgets('cancelled, it starts nothing', (tester) async {
      final run = _RecordingRun();
      await pumpCard(tester, installed: pack, checked: true, run: run);
      await tester.tap(again);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(run.started, isEmpty);
    });

    testWidgets('counts every item away from this device, checked or not, '
        'before it starts', (tester) async {
      final run = _RecordingRun();
      // A path no test machine has: the photo is not on this device.
      final away = testMediaItem(
        id: 'p1',
        diveId: 'd1',
        originalFilename: 'check-again-not-on-this-device-4825.jpg',
      );
      await pumpCard(
        tester,
        installed: pack,
        checked: true,
        run: run,
        media: [away],
        upToDate: {'p1'},
      );
      await tester.tap(again);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dive_species_download')),
        findsOneWidget,
      );
      expect(run.started, isEmpty);
      await tester.tap(find.byKey(const ValueKey('dive_species_download')));
      await tester.pumpAndSettle();
      expect(run.fresh, [true]);
    });
  });

  testWidgets('a dive not yet checked still offers Find species, and an '
      'ordinary run', (tester) async {
    final run = _RecordingRun();
    await pumpCard(
      tester,
      installed: pack,
      run: run,
      media: [
        testMediaItem(
          id: 'p1',
          diveId: 'd1',
        ).copyWith(platformAssetId: 'asset-1'),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('dive_species_find')));
    await tester.pumpAndSettle();
    expect(run.fresh, [false]);
  });

  testWidgets('paused in the background offers Resume too', (tester) async {
    await pumpCard(
      tester,
      installed: pack,
      runs: {
        'd1': const DiveSpeciesRunState(
          diveId: 'd1',
          phase: DiveRunPhase.paused,
          pauseReason: DiveRunPause.background,
          total: 3,
          done: 1,
        ),
      },
    );
    expect(find.byKey(const ValueKey('dive_species_resume')), findsOneWidget);
  });

  group('the Species page banner', () {
    Future<void> pumpBanner(WidgetTester tester, int count) async {
      await tester.pumpWidget(
        await mediaTestApp(
          overrides: [
            speciesReviewCountProvider(
              const LogReviewScope(),
            ).overrideWith((ref) async => count),
          ],
          home: const Scaffold(body: SpeciesReviewBanner()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('hidden with nothing to review', (tester) async {
      await pumpBanner(tester, 0);
      expect(find.byKey(const ValueKey('species_review_banner')), findsNothing);
    });

    testWidgets('says how many', (tester) async {
      await pumpBanner(tester, 12);
      expect(find.text('12 species to review'), findsOneWidget);
    });
  });

  group('Find species asks before downloading', () {
    // A path no test machine has: the photo is not on this device.
    final away = testMediaItem(
      id: 'p1',
      diveId: 'd1',
      originalFilename: 'find-species-not-on-this-device-4727.jpg',
    );

    testWidgets('Cancel starts nothing; Download and find starts the run', (
      tester,
    ) async {
      final run = _RecordingRun();
      await pumpCard(tester, installed: pack, run: run, media: [away]);

      await tester.tap(find.byKey(const ValueKey('dive_species_find')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "1 photo or video isn't on this device. Finding species will "
          'download it.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(run.started, isEmpty);

      await tester.tap(find.byKey(const ValueKey('dive_species_find')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dive_species_download')));
      await tester.pumpAndSettle();
      expect(run.started, ['d1']);
    });

    testWidgets('a library photo held only in iCloud is counted too', (
      tester,
    ) async {
      final run = _RecordingRun();
      final library = MediaItem(
        id: 'p1',
        diveId: 'd1',
        mediaType: MediaType.photo,
        platformAssetId: 'PH-1',
        takenAt: DateTime.utc(2026, 3, 9),
        createdAt: DateTime.utc(2026, 3, 9),
        updatedAt: DateTime.utc(2026, 3, 9),
      );
      await pumpCard(
        tester,
        installed: pack,
        run: run,
        media: [library],
        libraryOriginalHere: (_) async => false,
      );

      await tester.tap(find.byKey(const ValueKey('dive_species_find')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "1 photo or video isn't on this device. Finding species will "
          'download it.',
        ),
        findsOneWidget,
      );
      expect(run.started, isEmpty);
    });

    testWidgets('a second tap while it counts opens no second prompt', (
      tester,
    ) async {
      final answer = Completer<bool>();
      final library = MediaItem(
        id: 'p1',
        diveId: 'd1',
        mediaType: MediaType.photo,
        platformAssetId: 'PH-1',
        takenAt: DateTime.utc(2026, 3, 9),
        createdAt: DateTime.utc(2026, 3, 9),
        updatedAt: DateTime.utc(2026, 3, 9),
      );
      await pumpCard(
        tester,
        installed: pack,
        run: _RecordingRun(),
        media: [library],
        libraryOriginalHere: (_) => answer.future,
      );

      await tester.tap(find.byKey(const ValueKey('dive_species_find')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dive_species_find')));
      await tester.pump();
      answer.complete(false);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('media already checked is not counted: the run starts at '
        'once', (tester) async {
      final run = _RecordingRun();
      await pumpCard(
        tester,
        installed: pack,
        run: run,
        media: [away],
        upToDate: {'p1'},
      );

      await tester.tap(find.byKey(const ValueKey('dive_species_find')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(run.started, ['d1']);
    });
  });
}
