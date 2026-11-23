import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/data/services/metadata_write_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_photo_picker_service.dart';
import '../../../../helpers/pump_until.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/marine_life_id_off.dart';

/// Rounds of 20 ms of real time, so about five seconds before a wait fails:
/// room for a machine running many test bundles at once.
const _maxRealAsyncRounds = 250;

class _UnavailableResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// Answers every resolution with [result], or with the row's own id when
/// [result] is null, which is what the linking device gets.
class _FixedResolution extends AssetResolutionService {
  _FixedResolution(this.result, {this.error})
    : super(
        cacheRepository: LocalAssetCacheRepository(),
        photoPickerService: FakePhotoPickerService(),
      );

  final ResolutionResult? result;

  /// Thrown instead of answering, when set.
  final Object? error;

  @override
  Future<ResolutionResult> resolveAssetId(MediaItem item) async {
    if (error case final error?) throw error;
    return result ??
        ResolutionResult(
          localAssetId: item.platformAssetId,
          status: ResolutionStatus.resolved,
        );
  }
}

/// The write-metadata action only appears once the item carries enrichment
/// depth, so every case here needs one.
MediaItem item({
  String id = 'm1',
  String? platformAssetId = 'asset-1',
  double? depthMeters = 18.3,
  MediaType mediaType = MediaType.photo,
}) => MediaItem(
  id: id,
  diveId: 'dive-1',
  platformAssetId: platformAssetId,
  mediaType: mediaType,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2026, 7, 1, 10),
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
  enrichment: MediaEnrichment(
    id: 'e-$id',
    mediaId: id,
    diveId: 'dive-1',
    depthMeters: depthMeters,
    temperatureCelsius: 21.5,
    elapsedSeconds: 600,
    matchConfidence: MatchConfidence.exact,
    createdAt: DateTime.utc(2026, 7, 1),
  ),
);

void main() {
  // The page is built inside runAsync, so the viewer's wait before it asks
  // for marine life analysis runs on real time, and on a Linux runner the
  // labels ring then outlasts a pumpAndSettle (issue #4949).
  turnOffMarineLifeIdForEachTest();

  const channel = MethodChannel('com.submersion.app/metadata');
  late SharedPreferences prefs;
  late List<MethodCall> nativeCalls;

  /// Set per test to decide what the native metadata writer does.
  late Future<Object?> Function(MethodCall) handler;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    nativeCalls = [];
    // CI runs its test shards on Linux, where the service's real platform
    // check is false and would refuse before reaching the mocked channel.
    MetadataWriteService.debugSupportedOverride = true;
    handler = (_) async => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          nativeCalls.add(call);
          return handler(call);
        });
  });

  tearDown(() async {
    MetadataWriteService.debugSupportedOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await tearDownTestDatabase();
  });

  /// The viewer has its item: the toolbar is up, the stored photo has been
  /// read (only then is its unlock offered), and no loading spinner is left
  /// to keep a ticker running under a later pumpAndSettle.
  bool viewerLoaded() =>
      find.byType(MediaViewerToolbar).evaluate().isNotEmpty &&
      find.byKey(const ValueKey('viewer_unlock')).evaluate().isNotEmpty &&
      find.byType(CircularProgressIndicator).evaluate().isEmpty;

  Future<void> pump(
    WidgetTester tester,
    MediaItem media, {
    ResolutionResult? resolution,
    Object? resolutionError,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            assetResolutionServiceProvider.overrideWithValue(
              _FixedResolution(resolution, error: resolutionError),
            ),
            // The photo as stored, for its lock (issue #4527).
            photoRecordProvider(media.id).overrideWith(
              (ref) async =>
                  PhotoRecord(item: media, species: const [], people: const []),
            ),
            mediaByIdProvider(media.id).overrideWith((ref) async => media),
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.platformGallery: _UnavailableResolver(),
              }),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerPage(mediaList: [media], initialMediaId: media.id),
          ),
        ),
      );
    });
    // Loading the item is real async work (asset resolution, the photo
    // record, the media row), so wait for its end rather than a fixed slice
    // of real time, which a loaded machine can outrun (issue #4937).
    await pumpUntilRealAsync(
      tester,
      viewerLoaded,
      maxRounds: _maxRealAsyncRounds,
      reason: 'the viewer to load its item',
    );
  }

  /// Opens the write's confirmation. Writing to the file is a whole-record
  /// operation, so a locked photo is unlocked first (issue #4527).
  Future<void> openDialog(WidgetTester tester) async {
    final unlock = find.byKey(const ValueKey('viewer_unlock'));
    if (unlock.evaluate().isNotEmpty) {
      await tester.tap(unlock);
      await tester.pump();
    }
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();
  }

  /// The write runs over a real platform channel, so it needs the real event
  /// loop rather than the fake test clock. Every way it ends drops its
  /// spinner and shows a SnackBar, so that pair is what is waited for, not a
  /// fixed slice of real time (issue #4937). No spinner alone would hold
  /// before the write's spinner is first shown.
  Future<void> confirmWrite(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Write'));
    });
    await pumpUntilRealAsync(
      tester,
      () =>
          find.byType(SnackBar).evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty,
      maxRounds: _maxRealAsyncRounds,
      reason: 'the write to finish',
    );
  }

  testWidgets('the action is offered when the item has dive data', (
    tester,
  ) async {
    await pump(tester, item());
    expect(find.byIcon(Icons.edit_note), findsOneWidget);
  });

  testWidgets('the action is hidden without enrichment depth', (tester) async {
    await pump(tester, item(depthMeters: null));
    expect(find.byIcon(Icons.edit_note), findsNothing);
  });

  testWidgets('the action is hidden for videos (issue #1472)', (tester) async {
    // Writing metadata to a video meant exporting a copy, creating a new
    // asset and deleting the original. The whole path is gone, so the
    // action must not be offered for one.
    await pump(tester, item(mediaType: MediaType.video));
    expect(find.byIcon(Icons.edit_note), findsNothing);
  });

  testWidgets('the action is hidden for media with no library asset '
      '(issue #3808)', (tester) async {
    // A Files tab pick, a cloud-backed row or a linked URL has no photo in
    // any library to write to, so offering the action can only end in an
    // error message.
    await pump(tester, item(platformAssetId: null));
    expect(find.byIcon(Icons.edit_note), findsNothing);
  });

  testWidgets('the action is hidden where there is no native writer', (
    tester,
  ) async {
    MetadataWriteService.debugSupportedOverride = false;
    await pump(tester, item());
    expect(find.byIcon(Icons.edit_note), findsNothing);
  });

  testWidgets('the confirmation dialog opens before anything is written', (
    tester,
  ) async {
    await pump(tester, item());
    await openDialog(tester);

    expect(find.text('Write Dive Data to Photo'), findsOneWidget);
    expect(nativeCalls, isEmpty);
  });

  testWidgets('cancelling writes nothing', (tester) async {
    await pump(tester, item());
    await openDialog(tester);

    // The dialog's Cancel, not the unlocked bar's.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(nativeCalls, isEmpty);
    expect(find.text('Write Dive Data to Photo'), findsNothing);
  });

  testWidgets('confirming writes and reports success', (tester) async {
    await pump(tester, item());
    await openDialog(tester);
    await confirmWrite(tester);

    expect(nativeCalls.single.method, 'writeMetadata');
    expect(nativeCalls.single.arguments['assetId'], 'asset-1');
    expect(nativeCalls.single.arguments['isVideo'], isFalse);
    expect(find.text('Dive data written to photo'), findsOneWidget);
    // The modal spinner must not outlive the write.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a photo missing from this device reports it and never calls '
      'native', (tester) async {
    await pump(
      tester,
      item(),
      resolution: const ResolutionResult(status: ResolutionStatus.unavailable),
    );
    await openDialog(tester);
    await confirmWrite(tester);

    expect(
      find.text('Cannot write metadata - media not linked to library'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(nativeCalls, isEmpty);
  });

  testWidgets('lost library access is named and never calls native', (
    tester,
  ) async {
    // accessDenied says nothing about the photo, so "not linked" would be
    // the wrong thing to tell someone who only has to grant access again.
    await pump(
      tester,
      item(),
      resolution: const ResolutionResult(status: ResolutionStatus.accessDenied),
    );
    await openDialog(tester);
    await confirmWrite(tester);

    expect(find.text('No photo library access'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(nativeCalls, isEmpty);
  });

  testWidgets('a photo outside a limited selection is named as such', (
    tester,
  ) async {
    // Library access is granted here, so the same words the viewer's own
    // placeholder uses apply, not "no access".
    await pump(
      tester,
      item(),
      resolution: const ResolutionResult(
        status: ResolutionStatus.accessDenied,
        limitedAccess: true,
      ),
    );
    await openDialog(tester);
    await confirmWrite(tester);

    expect(find.text('Not in your allowed photos'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(nativeCalls, isEmpty);
  });

  testWidgets('a resolution failure is reported and never calls native', (
    tester,
  ) async {
    await pump(tester, item(), resolutionError: StateError('cache is gone'));
    await openDialog(tester);
    await confirmWrite(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('cache is gone'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(nativeCalls, isEmpty);
  });

  testWidgets('a synced photo is written through this device\'s asset id', (
    tester,
  ) async {
    // The row's platformAssetId belongs to the device that linked it. Sent
    // as is, it names some other photo here, or nothing at all.
    await pump(
      tester,
      item(platformAssetId: 'id-from-another-device'),
      resolution: const ResolutionResult(
        localAssetId: 'id-on-this-device',
        status: ResolutionStatus.resolved,
      ),
    );
    await openDialog(tester);
    await confirmWrite(tester);

    expect(nativeCalls.single.arguments['assetId'], 'id-on-this-device');
  });

  testWidgets('a native refusal is reported as a failure', (tester) async {
    handler = (_) async => false;
    await pump(tester, item());
    await openDialog(tester);
    await confirmWrite(tester);

    // MetadataWriteService THROWS on a false result rather than returning
    // it, so the viewer's localized media_photoViewer_failedToWriteMetadata
    // branch is unreachable and the raw exception text reaches the user
    // instead. Asserted as it behaves, not as it reads.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('The operation returned false'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a native error surfaces and drops the spinner', (tester) async {
    handler = (_) async =>
        throw PlatformException(code: 'PHOTO_ACCESS_DENIED', message: 'nope');
    await pump(tester, item());
    await openDialog(tester);
    await confirmWrite(tester);

    // Whatever the failure was, the user must not be left under a modal
    // barrier with no way out.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a Live Photo refusal is translated, not shown raw', (
    tester,
  ) async {
    // The native handlers now reject Live Photos up front; before that,
    // PhotoKit rejected the rewritten still and this untranslated string
    // reached the user verbatim (issue #795).
    handler = (_) async => throw PlatformException(
      code: metadataWriteLivePhotoUnsupportedCode,
      message:
          "The operation couldn't be completed. "
          '(PHPhotosErrorDomain error 3302.)',
    );
    await pump(tester, item());
    await openDialog(tester);
    await confirmWrite(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('PHPhotosErrorDomain'), findsNothing);
    expect(find.textContaining('Live Photos'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a native video refusal is translated, not shown raw', (
    tester,
  ) async {
    // Reachable when an item stored as a photo turns out to be a video in the
    // library: the native handlers check the real media type, not the flag
    // Dart sent, so the refusal can arrive even though the action is hidden
    // for anything already known to be a video (issue #1472).
    handler = (_) async => throw PlatformException(
      code: metadataWriteVideoUnsupportedCode,
      message: 'Writing metadata to a video is not supported.',
    );
    await pump(tester, item());
    await openDialog(tester);
    await confirmWrite(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('Dive data can only be written to photos, not videos.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  group('a whole-record operation (issue #4527)', () {
    IconButton action(WidgetTester tester) => tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('viewer_write_metadata')),
        matching: find.byType(IconButton),
      ),
    );

    RecordEditController<PhotoRecord> controller(WidgetTester tester) =>
        RecordEditScope.maybeOf<PhotoRecord>(
          tester.element(find.byType(MediaViewerToolbar)),
        )!;

    Future<void> unlock(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('viewer_unlock')));
      await tester.pump();
    }

    testWidgets('locked: disabled, "Unlock to use this"; no dialog on tap', (
      tester,
    ) async {
      await pump(tester, item());

      expect(action(tester).onPressed, isNull);
      expect(find.byTooltip('Unlock to use this'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_note), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Write Dive Data to Photo'), findsNothing);
    });

    testWidgets('unlocked with no changes: confirms and writes at once; still '
        'unlocked and clean', (tester) async {
      await pump(tester, item());
      await unlock(tester);

      await openDialog(tester);
      await confirmWrite(tester);

      expect(nativeCalls.single.method, 'writeMetadata');
      expect(controller(tester).isUnlocked, isTrue);
      expect(controller(tester).isDirty, isFalse);
    });

    testWidgets('unlocked with a change: disabled, "Save or cancel your '
        'changes first"', (tester) async {
      await pump(tester, item());
      await unlock(tester);

      controller(
        tester,
      ).session!.set(photoColorField, const ColorAdjustment(warmth: 0.3));
      await tester.pump();

      expect(action(tester).onPressed, isNull);
      expect(
        find.byTooltip('Save or cancel your changes first'),
        findsOneWidget,
      );
    });
  });
}
