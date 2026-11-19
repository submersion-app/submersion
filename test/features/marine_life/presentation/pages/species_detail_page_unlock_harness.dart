import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';

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

  @override
  Future<({Species before, Species after})?> save({
    required String speciesId,
    required Species Function(Species stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    if (fail) throw StateError('the save failed');
    final before = stored.state!;
    final after = apply(before);
    calls.add((after: after, cards: changedCardIds.toSet()));
    if (runHeld) await alsoWrite?.call();
    stored.state = after;
    return (before: before, after: after);
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

/// What a test pumped: the fake save, the stored species to change
/// underneath, and the photos tagged.
class SpeciesPageHarness {
  SpeciesPageHarness(this.save, this.stored, this.tagging);

  final FakeSpeciesSave save;
  final StateController<Species?> stored;
  final RecordingTagging tagging;
}

final _storedProvider = StateProvider<Species?>((ref) => manta);

/// Pumps the species page with the phase 3 switch on (unless
/// [unlockEditing] is false), its calculated sections empty, at phone width.
Future<SpeciesPageHarness> pumpSpeciesPage(
  WidgetTester tester, {
  Species species = manta,
  bool unlockEditing = true,
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
        speciesMapSpeciesPinsProvider(
          species.id,
        ).overrideWith((ref) async => []),
        speciesEditSaveServiceProvider.overrideWith((ref) {
          final save = FakeSpeciesSave(ref.watch(_storedProvider.notifier));
          harness = SpeciesPageHarness(
            save,
            ref.watch(_storedProvider.notifier),
            tagging,
          );
          return save;
        }),
        speciesTaggingServiceProvider.overrideWithValue(tagging),
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
      child: SpeciesDetailPage(
        speciesId: species.id,
        unlockEditing: unlockEditing,
        openUnlocked: openUnlocked,
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
