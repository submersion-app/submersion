import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/data/services/metadata_write_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

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

  Future<void> pump(WidgetTester tester, MediaItem media) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
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
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();
  }

  /// The write runs over a real platform channel, so it needs the real event
  /// loop rather than the fake test clock.
  Future<void> confirmWrite(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Write'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
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

  testWidgets('media not in the library reports it and never calls native', (
    tester,
  ) async {
    await pump(tester, item(platformAssetId: null));

    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    expect(
      find.text('Cannot write metadata - media not linked to library'),
      findsOneWidget,
    );
    expect(nativeCalls, isEmpty);
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

    await tester.tap(find.text('Cancel'));
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
}
