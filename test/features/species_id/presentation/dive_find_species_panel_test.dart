import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_section.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/services/dive_species_run.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/dive_species_run_state.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/presentation/providers/dive_species_run_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_review_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_review_banner.dart';

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
        applyAll: (_) async => 0,
        databaseGeneration: () => 0,
      ) {
    state = initial;
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
  }) async {
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
          mediaForDiveProvider('d1').overrideWith(
            (ref) async => [testMediaItem(id: 'p1', diveId: 'd1')],
          ),
          diveSpeciesCheckedProvider('d1').overrideWith((ref) async => checked),
          diveSpeciesRunProvider.overrideWith((ref) => _FixedRun(runs)),
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: DiveSightingsSection(dive: dive, topGap: 0),
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

  testWidgets('no card at all with no model and nothing to review', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.byKey(const ValueKey('dive_species_find')), findsNothing);
    expect(find.text('Marine life'), findsNothing);
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
    await pumpCard(tester, installed: pack, toReview: 2, checked: true);
    expect(find.text('Find species in photos'), findsOneWidget);
  });

  testWidgets('all checked and nothing to review', (tester) async {
    await pumpCard(tester, installed: pack, checked: true);
    expect(find.text('All photos checked'), findsOneWidget);
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
}
