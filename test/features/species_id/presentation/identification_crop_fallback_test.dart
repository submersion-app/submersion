import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../../../helpers/temp_dir.dart';
import '../../../helpers/test_database.dart';
import '../data/identification_fixtures.dart';
import 'species_id_fakes.dart';

/// A crop the video cap dropped shows its group's largest kept crop
/// instead of nothing (issue #5032).
void main() {
  late Directory support;
  late IdentificationCropStore store;
  final small = Uint8List.fromList([1]);
  final large = Uint8List.fromList([2]);

  setUp(() async {
    await setUpTestDatabase();
    support = await Directory.systemTemp.createTemp('crop_fallback');
    store = IdentificationCropStore(
      supportPath: () async => support.path,
      table: IdentificationCropRepository(),
    );
  });
  tearDown(() async {
    await store.dispose();
    await deleteTempDir(support);
    await tearDownTestDatabase();
  });

  ProviderContainer containerFor(List<MediaIdentification> rows) {
    final container = ProviderContainer(
      overrides: [
        identificationCropStoreProvider.overrideWithValue(store),
        mediaIdentificationRepositoryProvider.overrideWithValue(
          FixedIdentifications(rows),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<IdentificationCropImage?> cropOf(
    ProviderContainer container,
    String mediaId,
    String id,
  ) {
    // Held open, as the crop widget holds it while it shows.
    final provider = identificationCropProvider((mediaId, id));
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    return container.read(provider.future);
  }

  Future<List<int>?> bytesOf(IdentificationCropImage? crop) async =>
      switch (crop) {
        CropFile(:final file) => await file.readAsBytes(),
        CropBytes(:final bytes) => bytes,
        null => null,
      };

  test('a dropped track shows its group\'s largest kept crop', () async {
    final rows = [
      track('dropped').copyWith(boxPixelWidth: 900),
      track('kept-small').copyWith(boxPixelWidth: 100),
      track('kept-large').copyWith(boxPixelWidth: 500),
    ];
    await store.write('v1', 'kept-small', small);
    await store.write('v1', 'kept-large', large);
    final container = containerFor(rows);
    expect(await bytesOf(await cropOf(container, 'v1', 'dropped')), large);
    final present = presentCropIdsProvider('v1');
    final sub = container.listen(present, (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(present.future), {'kept-small', 'kept-large'});
  });

  test('a track accepted as another species falls back within that '
      'species (its tag says so)', () async {
    final rows = [
      track(
        'dropped',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_grunt',
      ).copyWith(boxPixelWidth: 900),
      track(
        'grunt',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_grunt',
      ).copyWith(boxPixelWidth: 100),
      track(
        'parrot',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_queen_parrotfish',
      ).copyWith(boxPixelWidth: 500),
    ];
    await store.write('v1', 'grunt', small);
    await store.write('v1', 'parrot', large);
    final container = ProviderContainer(
      overrides: [
        identificationCropStoreProvider.overrideWithValue(store),
        mediaIdentificationRepositoryProvider.overrideWithValue(
          _Tagged(rows, const [
            TaggedSpecies(
              speciesId: 'sp_grunt',
              scientificName: 'Haemulon flavolineatum',
            ),
            TaggedSpecies(speciesId: 'sp_queen_parrotfish'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(await bytesOf(await cropOf(container, 'v1', 'dropped')), small);
  });

  test('reads the rows without their track paths', () async {
    final rows = [track('dropped'), track('kept')];
    await store.write('v1', 'kept', large);
    final repository = _PathSpy(rows);
    final container = ProviderContainer(
      overrides: [
        identificationCropStoreProvider.overrideWithValue(store),
        mediaIdentificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    expect(await bytesOf(await cropOf(container, 'v1', 'dropped')), large);
    expect(repository.withPaths, everyElement(isFalse));
    expect(repository.withPaths, isNotEmpty);
  });

  test('a photo\'s missing crop stays missing', () async {
    final rows = [identification('a'), identification('b')];
    await store.write('m1', 'b', large);
    expect(await cropOf(containerFor(rows), 'm1', 'a'), isNull);
  });

  test('a track with no kept crop in its group stays missing', () async {
    expect(await cropOf(containerFor([track('a')]), 'v1', 'a'), isNull);
  });
}

/// Identifications with the species tags of their media.
class _Tagged extends FixedIdentifications {
  _Tagged(super.rows, this.tags);

  final List<TaggedSpecies> tags;

  @override
  Future<List<TaggedSpecies>> taggedSpecies(String mediaId) async => tags;
}

/// Records how rows are read, and fails a read of whole rows.
class _PathSpy extends FixedIdentifications {
  _PathSpy(super.rows);

  final withPaths = <bool>[];

  @override
  Future<List<MediaIdentification>> forMedia(String mediaId) =>
      throw StateError('read whole rows');

  @override
  Future<
    (
      Map<String, MediaIdentificationRun>,
      Map<String, List<MediaIdentification>>,
    )
  >
  forMediaIdsWithRuns(List<String> mediaIds, {bool withPaths = true}) {
    this.withPaths.add(withPaths);
    return super.forMediaIdsWithRuns(mediaIds, withPaths: withPaths);
  }
}
