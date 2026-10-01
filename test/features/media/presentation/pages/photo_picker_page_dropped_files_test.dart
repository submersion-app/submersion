// Coverage for opening the picker with files already in hand (a desktop
// drag-and-drop, issue #2488): it starts on the Files tab with those files
// staged, and does not open the Gallery tab's file dialog until that tab is
// actually shown.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/files_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A Windows / Linux picker service: no gallery to browse, so loading the
/// Gallery tab opens a file dialog. [dialogsOpened] counts those dialogs.
class _DesktopPickerService implements PhotoPickerService {
  int dialogsOpened = 0;

  @override
  bool get supportsGalleryBrowsing => false;
  @override
  Future<List<AssetInfo>> getAssetsInDateRange(DateTime s, DateTime e) async {
    dialogsOpened++;
    return const [];
  }

  @override
  Future<PhotoPermissionStatus> currentPermission() => checkPermission();
  @override
  Future<PhotoPermissionStatus> checkPermission() async =>
      PhotoPermissionStatus.authorized;
  @override
  Future<PhotoPermissionStatus> requestPermission() => checkPermission();
  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async =>
      null;
  @override
  Future<Uint8List?> getFileBytes(String assetId) async => null;
  @override
  Future<String?> getFilePath(String assetId) async => null;
  @override
  Future<MediaSourceMetadata?> getAssetMetadata(String assetId) async => null;
}

class _Unused
    implements
        MediaRepository,
        LocalBookmarkStorage,
        LocalMediaPlatform,
        NetworkFetchPipeline,
        NetworkCredentialsService {
  @override
  Future<Map<String, String>?> headersFor(Uri uri) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Every file reads as a JPEG with no capture time.
class _PlainExtractor implements ExifExtractor {
  @override
  Future<MediaSourceMetadata?> extract(File file) async =>
      const MediaSourceMetadata(mimeType: 'image/jpeg');
}

final _dropped = [p.join('photos', 'a.jpg'), p.join('photos', 'b.jpg')];

class _Harness {
  final service = _DesktopPickerService();
  final unused = _Unused();
  late final filesTab = FilesTabNotifier(
    mediaRepository: unused,
    bookmarkStorage: unused,
    platform: unused,
  );
  final navigatorKey = GlobalKey<NavigatorState>();
  late final ProviderContainer container;

  Widget build({List<String>? initialFilePaths}) {
    return ProviderScope(
      overrides: [
        photoPickerServiceProvider.overrideWithValue(service),
        filesTabNotifierProvider.overrideWith((ref) => filesTab),
        exifExtractorProvider.overrideWithValue(_PlainExtractor()),
        diveBoundsProvider.overrideWith((ref) async => const []),
        urlTabNotifierProvider.overrideWith(
          (ref) => UrlTabNotifier(
            pipeline: unused,
            credentials: unused,
            mediaRepository: unused,
          ),
        ),
        networkCredentialsServiceProvider.overrideWithValue(unused),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
  }

  void open({List<String>? initialFilePaths, MediaAttachTarget? target}) {
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoPickerPage(
          startTime: DateTime.utc(2024, 1, 1, 9),
          endTime: DateTime.utc(2024, 1, 1, 11),
          target: target,
          initialFilePaths: initialFilePaths,
        ),
      ),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('without files in hand, the Gallery tab loads on open', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    h.open();
    await _settle(tester);

    expect(h.service.dialogsOpened, 1);
    expect(find.byType(FilesTab), findsNothing);
  });

  testWidgets('dropped files open on the Files tab, staged for review', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    h.open(
      initialFilePaths: _dropped,
      target: const SiteAttachTarget('site-1'),
    );
    await _settle(tester);

    expect(find.byType(FilesTab), findsOneWidget);
    expect(h.filesTab.state.files.map((f) => f.sourcePath), _dropped);
  });

  testWidgets(
    'dropped files defer the Gallery file dialog until the tab is shown',
    (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.build());
      h.open(initialFilePaths: _dropped);
      await _settle(tester);

      expect(h.service.dialogsOpened, 0);

      await tester.tap(find.text('Gallery'));
      await _settle(tester);
      expect(h.service.dialogsOpened, 1);

      // Coming back to the Gallery tab does not open a second dialog.
      await tester.tap(find.text('Files'));
      await _settle(tester);
      await tester.tap(find.text('Gallery'));
      await _settle(tester);
      expect(h.service.dialogsOpened, 1);
    },
  );

  testWidgets('an open picker is counted until it closes', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    final sessions = h.container.read(openPhotoPickerSessionsProvider);
    expect(sessions.value, 0);

    h.open(initialFilePaths: _dropped);
    await _settle(tester);
    expect(sessions.value, 1);

    h.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(sessions.value, 0);
  });
}
