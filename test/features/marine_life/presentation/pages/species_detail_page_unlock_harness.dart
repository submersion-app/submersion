import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/theme/app_theme_registry.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/entities/species_insights.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/marine_life/data/services/species_edit_save_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_header_card_editor.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_detail_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_candidate_group.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_photos_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/species_photo_import_helper.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_enqueue_provider.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../media/presentation/support/media_widget_harness.dart';
import '../../../../helpers/test_app.dart';

/// The species the page shows, as stored.
const manta = Species(
  id: 'manta',
  commonName: 'Manta',
  scientificName: 'Mobula birostris',
  category: SpeciesCategory.ray,
  description: 'Big',
);

/// Records each save the page asks for, stores its result where the page
/// reads the species from, and can fail.
class FakeSpeciesSave implements SpeciesEditSaveService {
  FakeSpeciesSave(this.stored);

  /// The species as stored, which the page reads through [speciesProvider].
  final StateController<Species?> stored;

  final calls = <({Species after, Set<String> cards})>[];
  bool fail = false;

  /// Whether to run the held writes a save is given, as the real one does
  /// inside its transaction.
  bool runHeld = true;

  /// Holds the write until completed, so a test can leave the page while it
  /// runs.
  Completer<void>? gate;

  @override
  Future<({Species before, Species after})?> save({
    required String speciesId,
    required Species Function(Species stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    if (fail) throw StateError('the save failed');
    await gate?.future;
    final before = stored.state!;
    final after = apply(before);
    calls.add((after: after, cards: changedCardIds.toSet()));
    if (runHeld) await alsoWrite?.call();
    stored.state = after;
    return (before: before, after: after);
  }

  /// Each new species the page asked to create, failed ones included.
  final creates = <({Species species, Set<String> cards})>[];

  @override
  Future<Species> create({
    required Species species,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) async {
    creates.add((species: species, cards: changedCardIds.toSet()));
    if (fail) throw StateError('the create failed');
    await alsoWrite?.call();
    return species;
  }
}

/// Records each photo tagged instead of touching a database.
class RecordingTagging extends SpeciesTaggingService {
  RecordingTagging()
    : super(
        tags: MediaSpeciesRepository(),
        media: MediaRepository(),
        species: SpeciesRepository(),
      );

  final tagged = <String>[];

  @override
  Future<MediaSpeciesTag> tagPhoto({
    required String mediaId,
    required String speciesId,
  }) async {
    tagged.add(mediaId);
    return MediaSpeciesTag(
      id: 't-$mediaId',
      mediaId: mediaId,
      speciesId: speciesId,
      createdAt: DateTime(2024),
    );
  }
}

/// Answers whether a species is in use, and records deletes, instead of
/// touching a database.
class FakeSpeciesRepository extends SpeciesRepository {
  bool inUse = false;
  Object? deleteFails;
  final deleted = <String>[];

  @override
  Future<bool> isSpeciesInUse(String id) async => inUse;

  @override
  Future<void> deleteSpecies(String id) async {
    if (deleteFails case final error?) throw error;
    deleted.add(id);
  }
}

/// What a test pumped: the fake save, the stored species to change
/// underneath, the photos tagged, and the species repository.
class SpeciesPageHarness {
  SpeciesPageHarness(
    this.save,
    this.stored,
    this.tagging,
    this.written,
    this.species,
    this.showPage,
  );

  final FakeSpeciesRepository species;

  final FakeSpeciesSave save;
  final StateController<Species?> stored;
  final RecordingTagging tagging;

  /// The media rows the held import wrote, by id.
  final List<String> written;

  /// The media handed to the store's upload queue.
  final List<String> enqueued = [];

  /// Set false to take the page away while the app (its providers) stays.
  final ValueNotifier<bool> showPage;
}

final _storedProvider = StateProvider<Species?>((ref) => manta);

/// Pumps the species page, its calculated sections empty, at phone width.
Future<SpeciesPageHarness> pumpSpeciesPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Species species = manta,
  bool openUnlocked = false,
  Locale locale = const Locale('en'),
  SpeciesLookupOutcome? lookupAnswer,
}) async {
  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  late SpeciesPageHarness harness;
  final tagging = RecordingTagging();
  final written = <String>[];
  final repository = FakeSpeciesRepository();
  final pageShown = ValueNotifier(true);
  await tester.pumpWidget(
    testApp(
      locale: locale,
      overrides: [
        ...overrides,
        _storedProvider.overrideWith((ref) => species),
        speciesProvider(
          species.id,
        ).overrideWith((ref) async => ref.watch(_storedProvider)),
        speciesInsightsProvider(
          species.id,
        ).overrideWith((ref) async => SpeciesInsights.empty),
        speciesSightingsProvider(
          species.id,
        ).overrideWith((ref) async => const []),
        mediaForSpeciesProvider(species.id).overrideWith((ref) async => []),
        mediaEntriesForSpeciesProvider(
          species.id,
        ).overrideWith((ref) async => []),
        speciesMapSpeciesPinsProvider(
          species.id,
        ).overrideWith((ref) async => []),
        speciesEditSaveServiceProvider.overrideWith((ref) {
          final save = FakeSpeciesSave(ref.watch(_storedProvider.notifier));
          harness = SpeciesPageHarness(
            save,
            ref.watch(_storedProvider.notifier),
            tagging,
            written,
            repository,
            pageShown,
          );
          return save;
        }),
        speciesTaggingServiceProvider.overrideWithValue(tagging),
        speciesRepositoryProvider.overrideWithValue(repository),
        // Add photos: one photo prepared for dive d1, as the review would.
        speciesPhotoPrepareLauncherProvider.overrideWithValue(
          (context, ref, speciesId) async => [
            (item: testMediaItem(id: 'new1', diveId: 'd1'), enrichment: null),
          ],
        ),
        speciesImportWriterProvider.overrideWithValue((prepared) async {
          written.addAll([for (final p in prepared) p.item.id]);
          return [for (final p in prepared) p.item];
        }),
        mediaStoreEnqueueProvider.overrideWithValue(
          (mediaId) => harness.enqueued.add(mediaId),
        ),
        speciesTagCandidatesProvider(species.id).overrideWith(
          (ref) async => [
            SpeciesTagCandidateGroup(
              diveId: 'd1',
              diveNumber: 1,
              diveDateTime: DateTime(2024, 1, 10),
              siteName: 'Blue Hole',
              sightingId: 'sg1',
              items: [testMediaItem(id: 'p1', diveId: 'd1')],
            ),
          ],
        ),
        speciesLookupLauncherProvider.overrideWithValue(
          (context, query) async => lookupAnswer,
        ),
      ],
      child: ValueListenableBuilder<bool>(
        valueListenable: pageShown,
        builder: (context, shown, _) => shown
            ? Theme(
                // The app's own theme, light or dark.
                data: AppThemeRegistry.resolveTheme(
                  AppThemeRegistry.presets.first,
                  brightness,
                ),
                child: SpeciesDetailPage(
                  speciesId: species.id,
                  openUnlocked: openUnlocked,
                ),
              )
            : const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The fake is made on the first read; read it now so tests can see it.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SpeciesDetailPage)),
  );
  container.read(speciesEditSaveServiceProvider);
  return harness;
}

/// What a test of a new species' page pumped: the fake save, and how the
/// page ended.
class NewSpeciesHarness {
  late FakeSpeciesSave save;
  Object? popped;
  bool poppedAtAll = false;
}

/// Pumps a new species' page (issue #4527, phase 3, plan 11), pushed over
/// a launcher, with the online lookup answering [lookupAnswer].
Future<NewSpeciesHarness> pumpNewSpeciesPage(
  WidgetTester tester, {
  SpeciesLookupOutcome? lookupAnswer,
}) async {
  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final harness = NewSpeciesHarness();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...overrides,
        speciesEditSaveServiceProvider.overrideWith(
          (ref) => harness.save = FakeSpeciesSave(
            ref.watch(_storedProvider.notifier),
          ),
        ),
        speciesRepositoryProvider.overrideWithValue(FakeSpeciesRepository()),
        speciesLookupLauncherProvider.overrideWithValue(
          (context, query) async => lookupAnswer,
        ),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute<Object?>(
                  builder: (_) => const SpeciesDetailPage.newSpecies(),
                ),
              );
              harness
                ..poppedAtAll = true
                ..popped = result;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  ProviderScope.containerOf(
    tester.element(find.byType(SpeciesDetailPage)),
  ).read(speciesEditSaveServiceProvider);
  return harness;
}
