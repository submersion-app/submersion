import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';
import 'package:submersion/features/species_id/presentation/widgets/home_species_banner.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../domain/manifest_fixture.dart';

/// A controller held at [_fixed], so no test reaches the network.
class _FixedPackController extends SpeciesPackController {
  _FixedPackController(this._fixed);
  final SpeciesPackState _fixed;

  @override
  SpeciesPackState build() => _fixed;
}

/// The species model offer at the top of Home (issue #4881): shown where
/// the model can run and none is installed, once the library has a photo or
/// video, never in demo mode.
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

  List<Override> bannerOverrides({
    InstalledPack? installed,
    bool dismissed = false,
    bool demo = false,
    Future<bool>? hasMedia,
  }) => [
    visionAvailabilityProvider.overrideWith(
      (ref) => Future.value(VisionAvailability.available),
    ),
    installedSpeciesPackProvider.overrideWith((ref) => Future.value(installed)),
    speciesDownloadPromptDismissedNotifierProvider.overrideWith(
      (ref) => SpeciesDownloadPromptDismissedNotifier.unstored(dismissed),
    ),
    speciesPackControllerProvider.overrideWith(
      () => _FixedPackController(const PackChecking()),
    ),
    libraryHasPhotosOrVideosProvider.overrideWith(
      (ref) => hasMedia ?? Future.value(true),
    ),
    demoModeActiveProvider.overrideWithValue(demo),
  ];

  Future<ProviderContainer> pumpBanner(
    WidgetTester tester,
    List<Override> overrides,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HomeSpeciesBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(HomeSpeciesBanner)),
    );
  }

  final prompt = find.byKey(const ValueKey('species_download_prompt'));

  testWidgets(
    'shows the banner when the offer applies and the library has a photo '
    'or video',
    (tester) async {
      await pumpBanner(tester, bannerOverrides());
      expect(prompt, findsOneWidget);
    },
  );

  testWidgets('hides it when the library has no photos or videos', (
    tester,
  ) async {
    await pumpBanner(tester, bannerOverrides(hasMedia: Future.value(false)));
    expect(prompt, findsNothing);
  });

  testWidgets('hides it while the media count is loading', (tester) async {
    await pumpBanner(
      tester,
      bannerOverrides(hasMedia: Completer<bool>().future),
    );
    expect(prompt, findsNothing);
  });

  // The sample logbook has photos, and a dismissal there would carry into
  // the diver's own setup: demo mode shares the device's preferences.
  testWidgets('hides it in demo mode', (tester) async {
    await pumpBanner(tester, bannerOverrides(demo: true));
    expect(prompt, findsNothing);
  });

  testWidgets('hides it when the offer was dismissed', (tester) async {
    await pumpBanner(tester, bannerOverrides(dismissed: true));
    expect(prompt, findsNothing);
  });

  testWidgets('hides it when a pack is installed', (tester) async {
    await pumpBanner(tester, bannerOverrides(installed: pack));
    expect(prompt, findsNothing);
  });

  testWidgets('the close button dismisses it', (tester) async {
    final container = await pumpBanner(tester, bannerOverrides());
    await tester.tap(
      find.byKey(const ValueKey('species_download_prompt_dismiss')),
    );
    await tester.pump();
    expect(prompt, findsNothing);
    expect(
      container.read(speciesDownloadPromptDismissedNotifierProvider),
      isTrue,
    );
  });
}
