import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_downloader.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_download_prompt.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../domain/manifest_fixture.dart';

/// A controller held at [_fixed], so no test reaches the network.
class _FixedPackController extends SpeciesPackController {
  _FixedPackController(this._fixed);
  final SpeciesPackState _fixed;

  @override
  SpeciesPackState build() => _fixed;
}

/// The offer to download the identification model, to a diver who has
/// none (issue #4773).
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

  List<Override> promptOverrides({
    VisionAvailability availability = VisionAvailability.available,
    InstalledPack? installed,
    bool dismissed = false,
    SpeciesPackState packState = const PackChecking(),
    bool availabilityLoading = false,
    bool installedLoading = false,
    bool demo = false,
  }) => [
    demoModeActiveProvider.overrideWithValue(demo),
    visionAvailabilityProvider.overrideWith(
      (ref) => availabilityLoading
          ? Completer<VisionAvailability>().future
          : Future.value(availability),
    ),
    installedSpeciesPackProvider.overrideWith(
      (ref) => installedLoading
          ? Completer<InstalledPack?>().future
          : Future.value(installed),
    ),
    speciesDownloadPromptDismissedNotifierProvider.overrideWith(
      (ref) => SpeciesDownloadPromptDismissedNotifier.unstored(dismissed),
    ),
    speciesPackControllerProvider.overrideWith(
      () => _FixedPackController(packState),
    ),
  ];

  group('speciesDownloadPromptProvider', () {
    Future<bool> wanted(List<Override> overrides) async {
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);
      container.listen(speciesDownloadPromptProvider, (_, _) {});
      await container.read(visionAvailabilityProvider.future);
      await container.read(installedSpeciesPackProvider.future);
      return container.read(speciesDownloadPromptProvider);
    }

    test('is wanted where the model can run and none is installed', () async {
      expect(await wanted(promptOverrides()), isTrue);
    });

    // On a device with the model, the store is still being read: no flash
    // of the offer on every dive and photo meanwhile.
    test(
      'is not wanted while the pack or the device is being checked',
      () async {
        for (final overrides in [
          promptOverrides(installedLoading: true),
          promptOverrides(availabilityLoading: true),
        ]) {
          final container = ProviderContainer(overrides: overrides);
          addTearDown(container.dispose);
          container.listen(speciesDownloadPromptProvider, (_, _) {});
          await Future<void>.delayed(Duration.zero);
          expect(container.read(speciesDownloadPromptProvider), isFalse);
        }
      },
    );

    test('is not wanted once a model is installed', () async {
      expect(await wanted(promptOverrides(installed: pack)), isFalse);
    });

    test('is not wanted once dismissed', () async {
      expect(await wanted(promptOverrides(dismissed: true)), isFalse);
    });

    // Demo mode shares the device's preferences, so a dismissal made on a
    // sample dive would hide the offer in the diver's own logbook too
    // (issue #4891).
    test('is not wanted while the sample logbook is open', () async {
      expect(await wanted(promptOverrides(demo: true)), isFalse);
    });

    test('is not wanted on a device the model cannot run on', () async {
      for (final availability in [
        VisionAvailability.unsupportedPlatform,
        VisionAvailability.deviceNotEligible,
      ]) {
        expect(
          await wanted(promptOverrides(availability: availability)),
          isFalse,
          reason: availability.name,
        );
      }
    });

    test('is not wanted while the feature is off', () async {
      marineLifeIdEnabled = false;
      expect(await wanted(promptOverrides()), isFalse);
    });

    test('is not wanted while a download runs or none can be had', () async {
      for (final state in const <SpeciesPackState>[
        PackDownloading(received: 1, total: 2),
        PackInstalling(),
        PackNotPublished(),
        PackNotForThisDevice(),
        PackNeedsAppUpdate(),
      ]) {
        expect(
          await wanted(promptOverrides(packState: state)),
          isFalse,
          reason: '${state.runtimeType}',
        );
      }
    });

    test('is wanted while the model is known to be downloadable', () async {
      for (final state in const <SpeciesPackState>[
        PackNotInstalled(bytes: 10, resumable: false),
        PackFailed(reason: PackDownloadFailure.network, bytes: 10),
      ]) {
        expect(
          await wanted(promptOverrides(packState: state)),
          isTrue,
          reason: '${state.runtimeType}',
        );
      }
    });
  });

  group('SpeciesDownloadPromptDismissedNotifier', () {
    test('stores a dismissal on this device', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = SpeciesDownloadPromptDismissedNotifier(prefs);
      expect(notifier.state, isFalse);
      await notifier.setEnabled(true);
      expect(
        prefs.getBool(SettingsKeys.speciesIdDownloadPromptDismissed),
        true,
      );
      expect(SpeciesDownloadPromptDismissedNotifier(prefs).state, isTrue);
    });
  });

  group('SpeciesDownloadPrompt', () {
    Future<void> pumpPrompt(
      WidgetTester tester, {
      required List<Override> overrides,
      bool banner = false,
    }) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Column(
                children: [
                  SpeciesDownloadPrompt(banner: banner),
                  const _OverPageButtons(),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/settings/marine-life-identification',
            builder: (_, _) =>
                Scaffold(appBar: AppBar(), body: const Text('identification')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final prompt = find.byKey(const ValueKey('species_download_prompt'));

    testWidgets('offers the download where it is wanted', (tester) async {
      await pumpPrompt(tester, overrides: promptOverrides());
      expect(prompt, findsOneWidget);
      expect(find.text('Identify species in your photos and videos'), findsOne);
    });

    testWidgets('as a banner, draws in the banner colours', (tester) async {
      await pumpPrompt(tester, overrides: promptOverrides(), banner: true);
      final scheme = Theme.of(tester.element(prompt)).colorScheme;
      Color? textColor(String text) => tester
          .renderObject<RenderParagraph>(find.text(text))
          .text
          .style
          ?.color;
      expect(
        textColor('Identify species in your photos and videos'),
        scheme.onSecondaryContainer,
      );
      expect(
        textColor(
          'Download the species identification model to get suggestions',
        ),
        scheme.onSecondaryContainer,
      );
      // The colour each glyph is drawn in, however it reached the icon.
      Color? glyphColor(IconData icon) => tester
          .renderObject<RenderParagraph>(
            find.descendant(
              of: find.descendant(of: prompt, matching: find.byIcon(icon)),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style
          ?.color;
      expect(
        glyphColor(iconForSpeciesCategory(SpeciesCategory.fish)),
        scheme.onSecondaryContainer,
      );
      expect(glyphColor(Icons.close), scheme.onSecondaryContainer);
    });

    testWidgets('draws nothing where it is not wanted', (tester) async {
      await pumpPrompt(tester, overrides: promptOverrides(installed: pack));
      expect(prompt, findsNothing);
    });

    testWidgets('opens Species identification when tapped', (tester) async {
      await pumpPrompt(tester, overrides: promptOverrides());
      await tester.tap(prompt);
      await tester.pumpAndSettle();
      expect(find.text('identification'), findsOneWidget);
    });

    // As the photo viewer and its species sheet are: pushed above the
    // router's page, not by it (#4773).
    testWidgets('from a sheet over a pushed page, closes both first', (
      tester,
    ) async {
      await pumpPrompt(tester, overrides: promptOverrides());
      await tester.tap(find.text('open viewer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      await tester.tap(prompt.last);
      await tester.pumpAndSettle();
      expect(find.text('identification'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('viewer'), findsNothing);
      expect(find.text('sheet'), findsNothing);
      expect(find.text('open viewer'), findsOneWidget);
    });

    testWidgets('a page that will not close keeps the diver on it', (
      tester,
    ) async {
      await pumpPrompt(tester, overrides: promptOverrides());
      await tester.tap(find.text('open guarded viewer'));
      await tester.pumpAndSettle();
      await tester.tap(prompt.last);
      await tester.pumpAndSettle();
      expect(find.text('viewer'), findsOneWidget);
      expect(find.text('identification'), findsNothing);
    });

    // How the diver meets it: the species sheet over a viewer holding
    // tags it has not saved. The sheet closes; the viewer is asked, not
    // popped past, and nothing opens.
    testWidgets('from a sheet over a page that will not close, closes only '
        'the sheet', (tester) async {
      await pumpPrompt(tester, overrides: promptOverrides());
      await tester.tap(find.text('open guarded viewer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      await tester.tap(prompt.last);
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
      expect(find.text('viewer'), findsOneWidget);
      expect(find.text('identification'), findsNothing);
    });

    testWidgets('goes away for good when dismissed', (tester) async {
      await pumpPrompt(tester, overrides: promptOverrides(), banner: true);
      await tester.tap(
        find.byKey(const ValueKey('species_download_prompt_dismiss')),
      );
      await tester.pumpAndSettle();
      expect(prompt, findsNothing);
      expect(find.text('identification'), findsNothing);
    });
  });
}

/// Pushes a page above the router's, as the photo viewer is, and a sheet
/// over it, both holding the prompt.
class _OverPageButtons extends StatelessWidget {
  const _OverPageButtons();

  Widget _viewer(BuildContext context, {required bool guarded}) => PopScope(
    canPop: !guarded,
    child: Scaffold(
      body: Column(
        children: [
          const Text('viewer'),
          const SpeciesDownloadPrompt(),
          TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text('sheet'), SpeciesDownloadPrompt()],
              ),
            ),
            child: const Text('open sheet'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final guarded in [false, true])
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => _viewer(context, guarded: guarded),
            ),
          ),
          child: Text(guarded ? 'open guarded viewer' : 'open viewer'),
        ),
    ],
  );
}
