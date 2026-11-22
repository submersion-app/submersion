import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';

import '../domain/manifest_fixture.dart';

/// A controller whose state the test moves, so no test reaches the network.
class _MovablePackController extends SpeciesPackController {
  @override
  SpeciesPackState build() => const PackChecking();

  void move(SpeciesPackState next) => state = next;
}

/// Whether the setup wizard offers the species model (issue #4881): the
/// facts the #4773 offers use, read once.
void main() {
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

  List<Override> offerOverrides({
    VisionAvailability availability = VisionAvailability.available,
    InstalledPack? installed,
    bool dismissed = false,
  }) => [
    visionAvailabilityProvider.overrideWith(
      (ref) => Future.value(availability),
    ),
    installedSpeciesPackProvider.overrideWith((ref) => Future.value(installed)),
    speciesDownloadPromptDismissedNotifierProvider.overrideWith(
      (ref) => SpeciesDownloadPromptDismissedNotifier.unstored(dismissed),
    ),
    speciesPackControllerProvider.overrideWith(_MovablePackController.new),
  ];

  Future<(ProviderContainer, bool)> offer(List<Override> overrides) async {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    container.listen(speciesModelOfferProvider, (_, _) {});
    return (container, await container.read(speciesModelOfferProvider.future));
  }

  // The installed pack can be invalidated while the offer waits for it, as
  // when a download started in Settings finishes just as the assistant
  // opens. The offer listens to it, so the reload answers instead of the
  // first read hanging (issue #3807).
  test('still answers when the installed pack reloads mid-read', () async {
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        visionAvailabilityProvider.overrideWith(
          (ref) => Future.value(VisionAvailability.available),
        ),
        // The first read never answers on its own; the reload does.
        installedSpeciesPackProvider.overrideWith((ref) async {
          if (++reads == 1) return Completer<InstalledPack?>().future;
          return null;
        }),
        speciesDownloadPromptDismissedNotifierProvider.overrideWith(
          (ref) => SpeciesDownloadPromptDismissedNotifier.unstored(false),
        ),
        speciesPackControllerProvider.overrideWith(_MovablePackController.new),
      ],
    );
    addTearDown(container.dispose);
    final answer = container.awaitFuture(speciesModelOfferProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(reads, 1);
    container.invalidate(installedSpeciesPackProvider);
    expect(await answer.timeout(const Duration(seconds: 2)), isTrue);
  });

  test('is offered where the model can run, none is installed and the '
      'offer was not dismissed', () async {
    expect((await offer(offerOverrides())).$2, isTrue);
  });

  test('is not offered while the feature is off', () async {
    marineLifeIdEnabled = false;
    expect((await offer(offerOverrides())).$2, isFalse);
  });

  test('is not offered on a device the model cannot run on', () async {
    for (final availability in [
      VisionAvailability.unsupportedPlatform,
      VisionAvailability.deviceNotEligible,
    ]) {
      expect(
        (await offer(offerOverrides(availability: availability))).$2,
        isFalse,
        reason: availability.name,
      );
    }
  });

  test('is not offered once a model is installed', () async {
    expect((await offer(offerOverrides(installed: pack))).$2, isFalse);
  });

  // Removing the model sets the dismissed flag (issue #4773), so a run from
  // Settings after a removal leaves the step out too.
  test('is not offered once dismissed, or after a removal', () async {
    expect((await offer(offerOverrides(dismissed: true))).$2, isFalse);
  });

  // The wizard keeps the step while a download it started runs: the answer
  // never follows the controller.
  test('stays offered once the controller starts downloading', () async {
    final (container, first) = await offer(offerOverrides());
    expect(first, isTrue);
    (container.read(speciesPackControllerProvider.notifier)
            as _MovablePackController)
        .move(const PackDownloading(received: 1, total: 2));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(speciesDownloadPromptProvider), isFalse);
    expect(await container.read(speciesModelOfferProvider.future), isTrue);
  });
}
