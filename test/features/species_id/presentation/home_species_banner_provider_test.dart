import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../domain/manifest_fixture.dart';

/// A media library of [count] photos and videos, and the change stream the
/// provider listens to, with how many listen to it.
class _FakeMedia extends Fake implements MediaRepository {
  _FakeMedia(this.count);
  int count;
  var listeners = 0;
  late final changes = StreamController<void>.broadcast(
    onListen: () => listeners++,
    onCancel: () => listeners--,
  );

  @override
  Future<int> countPhotosAndVideos() async => count;

  @override
  Stream<void> watchMediaChanges() => changes.stream;
}

/// The real library check behind the Home banner (issue #4881).
void main() {
  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
  });

  ProviderContainer containerFor(_FakeMedia media) {
    final container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(media),
        speciesDownloadPromptProvider.overrideWithValue(true),
        demoModeActiveProvider.overrideWithValue(false),
        installedSpeciesPackProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(media.changes.close);
    return container;
  }

  test('the library check answers from the photo and video count', () async {
    final media = _FakeMedia(0);
    final container = containerFor(media);
    container.listen(libraryHasPhotosOrVideosProvider, (_, _) {});
    expect(
      await container.read(libraryHasPhotosOrVideosProvider.future),
      isFalse,
    );
    media.count = 3;
    media.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(
      await container.read(libraryHasPhotosOrVideosProvider.future),
      isTrue,
    );
  });

  test('the banner shows once a photo arrives', () async {
    final media = _FakeMedia(0);
    final container = containerFor(media);
    container.listen(homeSpeciesBannerProvider, (_, _) {});
    await container.read(libraryHasPhotosOrVideosProvider.future);
    expect(container.read(homeSpeciesBannerProvider), isFalse);
    media.count = 1;
    media.changes.add(null);
    await container.read(libraryHasPhotosOrVideosProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(homeSpeciesBannerProvider), isTrue);
  });

  // Cheap checks first: a library with nothing for the model to look at
  // never asks the vision engine (which loads ONNX Runtime on Android,
  // Windows and Linux) or the pack store.
  test('an empty library never asks the vision engine', () async {
    final media = _FakeMedia(0);
    var engineAsked = 0;
    final container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(media),
        demoModeActiveProvider.overrideWithValue(false),
        visionAvailabilityProvider.overrideWith((ref) async {
          engineAsked++;
          return VisionAvailability.available;
        }),
        installedSpeciesPackProvider.overrideWith((ref) async => null),
        speciesDownloadPromptDismissedNotifierProvider.overrideWith(
          (ref) => SpeciesDownloadPromptDismissedNotifier.unstored(false),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(media.changes.close);
    container.listen(homeSpeciesBannerProvider, (_, _) {});
    await container.read(libraryHasPhotosOrVideosProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(homeSpeciesBannerProvider), isFalse);
    expect(engineAsked, 0);
  });

  // Installing the model dismisses nothing, so the banner itself must stop
  // watching the library once a model is there: it can never show again.
  test('with a model installed, Home stops watching the library', () async {
    final media = _FakeMedia(1);
    final container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(media),
        demoModeActiveProvider.overrideWithValue(false),
        installedSpeciesPackProvider.overrideWith(
          (ref) async => InstalledPack(
            manifest: SpeciesPackManifest.parse(manifestJson()),
            directory: '/pack',
            detectorPaths: const ['/pack/detector.mlpackage'],
            classifierPath: '/pack/classifier.mlpackage',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(media.changes.close);
    container.listen(homeSpeciesBannerProvider, (_, _) {});
    await container.read(installedSpeciesPackProvider.future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(homeSpeciesBannerProvider), isFalse);
    expect(media.listeners, 0);
  });

  // Home gone, nothing keeps the media watch alive.
  test('leaving Home stops watching the library', () async {
    final media = _FakeMedia(1);
    final container = containerFor(media);
    final sub = container.listen(homeSpeciesBannerProvider, (_, _) {});
    await container.read(libraryHasPhotosOrVideosProvider.future);
    expect(media.listeners, 1);
    sub.close();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(media.listeners, 0);
  });
}
