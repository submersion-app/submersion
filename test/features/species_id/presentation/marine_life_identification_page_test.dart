import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/media_store/presentation/pages/photos_videos_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_downloader.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_cleanup.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/presentation/pages/marine_life_identification_page.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../domain/manifest_fixture.dart';
import 'species_id_fakes.dart';

class _Controller extends SpeciesPackController {
  _Controller(this.initial);

  final SpeciesPackState initial;
  var refreshes = 0;
  var downloads = 0;
  var cancels = 0;
  var removals = 0;

  /// Whether the download would also fetch a hardware engine.
  var fetchesEngine = false;

  @override
  SpeciesPackState build() => initial;

  @override
  Future<bool> downloadFetchesHardwareEngine() async => fetchesEngine;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<void> download() async => downloads++;

  @override
  void cancel() => cancels++;

  @override
  Future<void> remove() async => removals++;
}

/// Every settle and clear, in order.
final _order = <String>[];

class _SettlingService extends RecordingIdentificationService {
  @override
  Future<void> settleAll() async => _order.add('settle');
}

class _Cleanup extends IdentificationCleanup {
  _Cleanup()
    : super(
        identifications: MediaIdentificationRepository(),
        embeddings: IdentificationEmbeddingRepository(),
        crops: IdentificationCropStore(supportPath: () async => '/none'),
      );

  var cleared = 0;
  Object? failure;

  @override
  Future<void> clearAll() async {
    if (failure != null) throw failure!;
    _order.add('clear');
    cleared++;
  }
}

void main() {
  late _Cleanup cleanup;

  setUp(() {
    marineLifeIdEnabled = true;
    cleanup = _Cleanup();
  });
  tearDown(resetMarineLifeIdEnabled);

  Future<_Controller> pump(
    WidgetTester tester,
    SpeciesPackState state, {
    List<dynamic> extra = const [],
    bool settle = true,
  }) async {
    final controller = _Controller(state);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          speciesPackControllerProvider.overrideWith(() => controller),
          identificationCleanupProvider.overrideWithValue(cleanup),
          mediaIdentificationServiceProvider.overrideWithValue(
            _SettlingService(),
          ),
          identificationCountProvider.overrideWith((ref) async => 214),
          identificationCropBytesProvider.overrideWith((ref) async => 6100000),
          ...extra,
        ],
        child: const MarineLifeIdentificationPage(),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // An indeterminate progress bar never settles.
      await tester.pump();
      await tester.pump();
    }
    return controller;
  }

  testWidgets('on Linux the page speaks of photos only', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pump(
      tester,
      const PackNotInstalled(bytes: 660000000, resumable: false),
    );
    expect(
      find.text(
        'Suggests the species in your photos. Runs on this device. Your '
        'photos never leave it.',
      ),
      findsOneWidget,
    );
    expect(find.text('Identify species when I open a photo'), findsOneWidget);
    expect(find.textContaining('photos and videos'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('opening the page checks the model', (tester) async {
    final controller = await pump(tester, const PackChecking());
    expect(controller.refreshes, 1);
  });

  testWidgets('not downloaded offers the download with its size', (
    tester,
  ) async {
    await pump(
      tester,
      const PackNotInstalled(bytes: 660000000, resumable: false),
    );
    expect(find.text('Not downloaded'), findsOneWidget);
    expect(find.byKey(const ValueKey('species_id_download')), findsOneWidget);
    expect(find.textContaining('Download ('), findsOneWidget);
  });

  testWidgets('a partial download offers to continue', (tester) async {
    await pump(
      tester,
      const PackNotInstalled(bytes: 660000000, resumable: true),
    );
    expect(find.textContaining('Continue download'), findsOneWidget);
  });

  testWidgets('Download asks first, with the size', (tester) async {
    final controller = await pump(
      tester,
      const PackNotInstalled(bytes: 660000000, resumable: false),
    );
    await tester.tap(find.byKey(const ValueKey('species_id_download')));
    await tester.pumpAndSettle();
    expect(find.text('Download the model?'), findsOneWidget);
    expect(controller.downloads, 0);
    await tester.tap(find.byKey(const ValueKey('species_id_download_confirm')));
    await tester.pumpAndSettle();
    expect(controller.downloads, 1);
  });

  testWidgets('where the download also fetches a hardware engine, the '
      'confirmation says Windows may download one', (tester) async {
    final controller = await pump(
      tester,
      const PackNotInstalled(bytes: 660000000, resumable: false),
    );
    controller.fetchesEngine = true;
    await tester.tap(find.byKey(const ValueKey('species_id_download')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Windows may also download an engine for your graphics card or NPU '
        'from Microsoft.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('elsewhere the confirmation does not mention an engine', (
    tester,
  ) async {
    await pump(
      tester,
      const PackNotInstalled(bytes: 660000000, resumable: false),
    );
    await tester.tap(find.byKey(const ValueKey('species_id_download')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('You can remove it at any time.'),
      findsOneWidget,
    );
    expect(find.textContaining('Windows may'), findsNothing);
  });

  testWidgets('downloading shows progress and can be cancelled', (
    tester,
  ) async {
    final controller = await pump(
      tester,
      const PackDownloading(received: 330, total: 660),
    );
    expect(find.text('Downloading 50%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('species_id_cancel')));
    expect(controller.cancels, 1);
  });

  testWidgets('installed offers removal, and an update when there is one', (
    tester,
  ) async {
    final controller = await pump(
      tester,
      const PackInstalled(
        version: '2026.11.1',
        bytes: 660000000,
        updateBytes: 650000000,
      ),
    );
    expect(find.text('Installed (2026.11.1)'), findsOneWidget);
    expect(find.byKey(const ValueKey('species_id_update')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('species_id_remove')));
    await tester.pumpAndSettle();
    expect(find.text('Remove the model?'), findsOneWidget);
    expect(controller.removals, 0);
    await tester.tap(find.byKey(const ValueKey('species_id_remove_confirm')));
    await tester.pumpAndSettle();
    expect(controller.removals, 1);
  });

  // A diver who removed the model chose to: no offer to download it again
  // across the app (#4773).
  testWidgets('removing the model also ends the offer to download it', (
    tester,
  ) async {
    await pump(tester, const PackInstalled(version: '2026.11.1', bytes: 660));
    bool dismissed() => ProviderScope.containerOf(
      tester.element(find.byType(MarineLifeIdentificationPage)),
    ).read(speciesDownloadPromptDismissedNotifierProvider);
    expect(dismissed(), isFalse);

    await tester.tap(find.byKey(const ValueKey('species_id_remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(dismissed(), isFalse);

    await tester.tap(find.byKey(const ValueKey('species_id_remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('species_id_remove_confirm')));
    await tester.pumpAndSettle();
    expect(dismissed(), isTrue);
  });

  // The page can go while its dialog stays up (the pane rebuilt under it):
  // a confirmed removal must still run, and still end the offer.
  testWidgets('a removal confirmed after the page went still runs', (
    tester,
  ) async {
    final controller = _Controller(
      const PackInstalled(version: '2026.11.1', bytes: 660),
    );
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          speciesPackControllerProvider.overrideWith(() => controller),
          identificationCleanupProvider.overrideWithValue(cleanup),
          mediaIdentificationServiceProvider.overrideWithValue(
            _SettlingService(),
          ),
          identificationCountProvider.overrideWith((ref) async => 0),
          identificationCropBytesProvider.overrideWith((ref) async => 0),
        ],
        child: ValueListenableBuilder<bool>(
          key: const ValueKey('page_host'),
          valueListenable: shown,
          builder: (_, on, _) =>
              on ? const MarineLifeIdentificationPage() : const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('page_host'))),
    );

    await tester.tap(find.byKey(const ValueKey('species_id_remove')));
    await tester.pumpAndSettle();
    shown.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(MarineLifeIdentificationPage), findsNothing);
    await tester.tap(find.byKey(const ValueKey('species_id_remove_confirm')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.removals, 1);
    expect(
      container.read(speciesDownloadPromptDismissedNotifierProvider),
      true,
    );
  });

  testWidgets('installing says so and offers nothing to tap', (tester) async {
    await pump(tester, const PackInstalling(), settle: false);
    expect(find.text('Installing the model...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('species_id_cancel')), findsNothing);
    expect(find.byKey(const ValueKey('species_id_remove')), findsNothing);
  });

  testWidgets('a clear that fails says so', (tester) async {
    cleanup.failure = Exception('locked');
    await pump(tester, const PackNotPublished());
    await tester.tap(find.byKey(const ValueKey('species_id_clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('species_id_clear_confirm')));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('a device that cannot run it offers no download', (tester) async {
    await pump(
      tester,
      const PackUnsupported(VisionAvailability.deviceNotEligible),
    );
    expect(
      find.text('This device does not have enough memory to run the model.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('species_id_download')), findsNothing);
  });

  testWidgets('nothing published yet says so', (tester) async {
    await pump(tester, const PackNotPublished());
    expect(find.text('Not available yet'), findsOneWidget);
  });

  testWidgets('a check that failed offers to check again, not to continue', (
    tester,
  ) async {
    final controller = await pump(
      tester,
      const PackFailed(reason: PackDownloadFailure.network, bytes: 0),
    );
    expect(find.byKey(const ValueKey('species_id_download')), findsNothing);
    final before = controller.refreshes;
    await tester.tap(find.byKey(const ValueKey('species_id_retry')));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(controller.refreshes, before + 1);
    expect(controller.downloads, 0);
  });

  testWidgets('a full disk says so', (tester) async {
    await pump(
      tester,
      const PackFailed(reason: PackDownloadFailure.storage, bytes: 660),
    );
    expect(
      find.text('There is not enough free space on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('shows what is kept, and clears it after asking', (tester) async {
    await pump(tester, const PackNotPublished());
    expect(find.textContaining('214'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('species_id_clear')));
    await tester.pumpAndSettle();
    expect(find.text('Clear all suggestions?'), findsOneWidget);
    expect(cleanup.cleared, 0);
    _order.clear();
    await tester.tap(find.byKey(const ValueKey('species_id_clear_confirm')));
    await tester.pumpAndSettle();
    expect(cleanup.cleared, 1);
    // A scan still running would write back what was cleared.
    expect(_order, ['settle', 'clear']);
  });

  testWidgets('the switch writes the device preference', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await pump(
      tester,
      const PackNotPublished(),
      extra: [
        identifyFishOnOpenProvider.overrideWith(
          (ref) => IdentifyFishOnOpenNotifier(prefs),
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('species_id_toggle')));
    await tester.pumpAndSettle();
    expect(prefs.getBool(SettingsKeys.identifyFishOnOpen), isFalse);
  });

  group('naming levels (issue #4721)', () {
    const installed = PackInstalled(
      version: '2026.11.1',
      bytes: 660000000,
      updateBytes: null,
      credits: [],
    );
    InstalledPack withLevels(List<Map<String, Object?>> levels) =>
        InstalledPack(
          manifest: SpeciesPackManifest.parse(
            manifestJson((m) {
              final naming = m['naming']! as Map<String, Object?>;
              naming['provisional'] = false;
              naming['precision'] = 0.897;
              naming['levels'] = levels;
            }),
          ),
          directory: '/pack',
          detectorPaths: const ['/pack/detector'],
          classifierPath: '/pack/classifier',
        );
    const balanced = {
      'id': 'balanced',
      'target': 0.75,
      'suggestScore': 0.4,
      'suggestScoreNoLocation': 0.6,
      'precision': 0.8,
    };
    const eager = {
      'id': 'eager',
      'target': 0.65,
      'suggestScore': 0.3,
      'suggestScoreNoLocation': 0.5,
      'precision': 0.7,
    };
    const surerKey = ValueKey('species_id_level_surer');

    Future<void> pumpLevels(
      WidgetTester tester,
      InstalledPack? pack, {
      NamingLevel chosen = NamingLevel.surer,
      bool picked = true,
    }) => pump(
      tester,
      installed,
      extra: [
        installedSpeciesPackProvider.overrideWith((ref) async => pack),
        namingLevelNotifierProvider.overrideWith(
          (ref) => NamingLevelNotifier.unstored(chosen, picked: picked),
        ),
      ],
    );

    testWidgets('are hidden with no pack, or a pack without levels', (
      tester,
    ) async {
      await pumpLevels(tester, null);
      expect(find.byKey(surerKey), findsNothing);
      await pumpLevels(tester, withLevels(const []));
      expect(find.byKey(surerKey), findsNothing);
    });

    testWidgets('are hidden when the pack cannot be read', (tester) async {
      await pump(tester, installed);
      expect(find.byKey(surerKey), findsNothing);
    });

    testWidgets('show each level with its measured accuracy', (tester) async {
      await pumpLevels(tester, withLevels(const [balanced, eager]));
      expect(find.text('How readily to suggest a species'), findsOneWidget);
      expect(find.text('Surer'), findsOneWidget);
      expect(find.text('Fewest names. About 85% right'), findsOneWidget);
      expect(find.text('Balanced'), findsOneWidget);
      expect(find.text('More names. About 80% right'), findsOneWidget);
      expect(find.text('Eager'), findsOneWidget);
      expect(find.text('Most names. About 70% right'), findsOneWidget);
    });

    testWidgets('choosing one sets the level', (tester) async {
      await pumpLevels(tester, withLevels(const [balanced, eager]));
      const eagerKey = ValueKey('species_id_level_eager');
      await tester.ensureVisible(find.byKey(eagerKey));
      await tester.tap(find.byKey(eagerKey));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MarineLifeIdentificationPage)),
      );
      expect(container.read(namingLevelNotifierProvider), NamingLevel.eager);
    });

    testWidgets('a level the pack lacks shows the one in force', (
      tester,
    ) async {
      await pumpLevels(
        tester,
        withLevels(const [balanced]),
        chosen: NamingLevel.eager,
      );
      final group = tester.widget<RadioGroup<NamingLevel>>(
        find.byType(RadioGroup<NamingLevel>),
      );
      expect(group.groupValue, NamingLevel.balanced);
      expect(
        find.byKey(const ValueKey('species_id_level_eager')),
        findsNothing,
      );
    });

    const fallbackNote =
        'Eager is not in this version of the model, so the app uses '
        'Balanced until an update adds Eager. Choose Balanced to keep using it.';
    const balancedKey = ValueKey('species_id_level_balanced');

    testWidgets('a level the pack lacks says which one is in use', (
      tester,
    ) async {
      await pumpLevels(
        tester,
        withLevels(const [balanced]),
        chosen: NamingLevel.eager,
      );
      expect(find.text(fallbackNote), findsOneWidget);
    });

    testWidgets('with no level picked, a pack without Eager uses its most '
        'eager level and says nothing (issue #4789)', (tester) async {
      await pumpLevels(
        tester,
        withLevels(const [balanced]),
        chosen: NamingLevel.eager,
        picked: false,
      );
      final group = tester.widget<RadioGroup<NamingLevel>>(
        find.byType(RadioGroup<NamingLevel>),
      );
      expect(group.groupValue, NamingLevel.balanced);
      expect(find.text(fallbackNote), findsNothing);
      final tile = tester.widget<RadioListTile<NamingLevel>>(
        find.byKey(balancedKey),
      );
      expect(tile.toggleable, isFalse);
    });

    testWidgets('picking a level the pack lacks after the default shows the '
        'note (issue #4789)', (tester) async {
      await pumpLevels(
        tester,
        withLevels(const [balanced]),
        chosen: NamingLevel.eager,
        picked: false,
      );
      expect(find.text(fallbackNote), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MarineLifeIdentificationPage)),
      );
      final notifier = container.read(namingLevelNotifierProvider.notifier);
      await notifier.setLevel(NamingLevel.surer);
      await notifier.setLevel(NamingLevel.eager);
      await tester.pumpAndSettle();
      expect(notifier.picked, isTrue);
      expect(find.text(fallbackNote), findsOneWidget);
      final tile = tester.widget<RadioListTile<NamingLevel>>(
        find.byKey(balancedKey),
      );
      expect(tile.toggleable, isTrue);
    });

    testWidgets('a level the pack carries has no note', (tester) async {
      await pumpLevels(
        tester,
        withLevels(const [balanced, eager]),
        chosen: NamingLevel.eager,
      );
      expect(find.textContaining('not in this version'), findsNothing);
    });

    testWidgets('choosing the level in use keeps it over one the pack lacks', (
      tester,
    ) async {
      await pumpLevels(
        tester,
        withLevels(const [balanced]),
        chosen: NamingLevel.eager,
      );
      await tester.ensureVisible(find.byKey(balancedKey));
      await tester.tap(find.byKey(balancedKey));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MarineLifeIdentificationPage)),
      );
      expect(container.read(namingLevelNotifierProvider), NamingLevel.balanced);
      expect(find.text(fallbackNote), findsNothing);
      final group = tester.widget<RadioGroup<NamingLevel>>(
        find.byType(RadioGroup<NamingLevel>),
      );
      expect(group.groupValue, NamingLevel.balanced);
    });

    testWidgets('choosing another level in a fallback sets it', (tester) async {
      await pumpLevels(
        tester,
        withLevels(const [balanced]),
        chosen: NamingLevel.eager,
      );
      await tester.ensureVisible(find.byKey(surerKey));
      await tester.tap(find.byKey(surerKey));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MarineLifeIdentificationPage)),
      );
      expect(container.read(namingLevelNotifierProvider), NamingLevel.surer);
      expect(find.text(fallbackNote), findsNothing);
    });

    bool toggleable(WidgetTester tester, NamingLevel level) => tester
        .widget<RadioListTile<NamingLevel>>(
          find.byKey(ValueKey('species_id_level_${level.id}')),
        )
        .toggleable;

    testWidgets('in a fallback only the level in use takes a tap on itself', (
      tester,
    ) async {
      await pumpLevels(
        tester,
        withLevels(const [balanced]),
        chosen: NamingLevel.eager,
      );
      expect(toggleable(tester, NamingLevel.balanced), isTrue);
      expect(toggleable(tester, NamingLevel.surer), isFalse);
    });

    testWidgets('a level the pack carries takes no tap on itself', (
      tester,
    ) async {
      await pumpLevels(
        tester,
        withLevels(const [balanced, eager]),
        chosen: NamingLevel.balanced,
      );
      for (final level in NamingLevel.values) {
        expect(toggleable(tester, level), isFalse, reason: level.id);
      }
    });
  });

  group('the entry on Photos and videos', () {
    Future<void> pumpPhotos(WidgetTester tester) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const PhotosVideosPage(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is there while the feature is on', (tester) async {
      await pumpPhotos(tester);
      await tester.scrollUntilVisible(find.text('Species identification'), 200);
      expect(find.text('Species identification'), findsOneWidget);
    });

    // Not a photo source, so not under Where photos come from (#4773).
    testWidgets('sits under its own Species header, after the photo sources', (
      tester,
    ) async {
      await pumpPhotos(tester);
      final row = find.text('Species identification');
      await tester.scrollUntilVisible(row, 200);
      final header = find.text('Species');
      final sources = find.text('Where photos come from');
      expect(header, findsOneWidget);
      expect(
        tester.getTopLeft(header).dy,
        greaterThan(tester.getTopLeft(sources).dy),
      );
      expect(
        tester.getTopLeft(row).dy,
        greaterThan(tester.getTopLeft(header).dy),
      );
    });

    testWidgets('is absent while it is off, header and all', (tester) async {
      marineLifeIdEnabled = false;
      await pumpPhotos(tester);
      expect(find.text('Species identification'), findsNothing);
      expect(find.text('Species'), findsNothing);
    });
  });
}
