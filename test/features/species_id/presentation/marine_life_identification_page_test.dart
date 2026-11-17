import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/media_store/presentation/pages/photos_videos_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_downloader.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_cleanup.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/presentation/pages/marine_life_identification_page.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';

class _Controller extends SpeciesPackController {
  _Controller(this.initial);

  final SpeciesPackState initial;
  var refreshes = 0;
  var downloads = 0;
  var cancels = 0;
  var removals = 0;

  @override
  SpeciesPackState build() => initial;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<void> download() async => downloads++;

  @override
  void cancel() => cancels++;

  @override
  Future<void> remove() async => removals++;
}

class _Cleanup extends IdentificationCleanup {
  _Cleanup()
    : super(
        identifications: MediaIdentificationRepository(),
        embeddings: IdentificationEmbeddingRepository(),
        crops: IdentificationCropStore(supportPath: () async => '/none'),
      );

  var cleared = 0;

  @override
  Future<void> clearAll() async => cleared++;
}

void main() {
  late bool flagBefore;
  late _Cleanup cleanup;

  setUp(() {
    flagBefore = marineLifeIdEnabled;
    marineLifeIdEnabled = true;
    cleanup = _Cleanup();
  });
  tearDown(() => marineLifeIdEnabled = flagBefore);

  Future<_Controller> pump(
    WidgetTester tester,
    SpeciesPackState state, {
    List<dynamic> extra = const [],
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
          identificationCountProvider.overrideWith((ref) async => 214),
          identificationCropBytesProvider.overrideWith((ref) async => 6100000),
          ...extra,
        ],
        child: const MarineLifeIdentificationPage(),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

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
    expect(controller.removals, 1);
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
    await tester.tap(find.byKey(const ValueKey('species_id_clear_confirm')));
    await tester.pumpAndSettle();
    expect(cleanup.cleared, 1);
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
      await tester.scrollUntilVisible(
        find.text('Marine life identification'),
        200,
      );
      expect(find.text('Marine life identification'), findsOneWidget);
    });

    testWidgets('is absent while it is off', (tester) async {
      marineLifeIdEnabled = false;
      await pumpPhotos(tester);
      expect(find.text('Marine life identification'), findsNothing);
    });
  });
}
