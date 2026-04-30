// Coverage for the tab-shell branches in PhotoPickerPage.build():
//   - When mediaPickerHiddenTabsProvider == false → simple Scaffold body.
//   - When mediaPickerHiddenTabsProvider == true  → DefaultTabController
//     with Gallery / Files / URL tabs.
//
// Phase 3a / Task 17 swapped the URL placeholder for [UrlTab]. The tab's
// notifier eagerly reads [networkFetchPipelineProvider], which constructs
// a [NetworkFetchPipeline] from `DatabaseService.instance.database` —
// uninitialized in widget tests. We therefore override
// [urlTabNotifierProvider] (and [networkCredentialsServiceProvider], which
// `NetworkThumbnail` reads directly) with hand-rolled fakes so the URL tab
// can paint its empty review pane without touching the database.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/files_tab.dart';
import 'package:submersion/features/media/presentation/widgets/url_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _StubPhotoPickerService implements PhotoPickerService {
  @override
  bool get supportsGalleryBrowsing => true;
  @override
  Future<List<AssetInfo>> getAssetsInDateRange(DateTime s, DateTime e) async =>
      const [];
  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async =>
      null;
  @override
  Future<Uint8List?> getFileBytes(String assetId) async => null;
  @override
  Future<PhotoPermissionStatus> checkPermission() async =>
      PhotoPermissionStatus.denied;
  @override
  Future<PhotoPermissionStatus> requestPermission() async =>
      PhotoPermissionStatus.denied;
  @override
  Future<String?> getFilePath(String assetId) async => null;
}

/// `noSuchMethod`-based fake for [NetworkFetchPipeline]. The tab-shell
/// test only constructs [UrlTabNotifier] to satisfy the provider override
/// — the notifier never invokes pipeline methods because the test does
/// not commit any URLs.
class _FakeNetworkFetchPipeline implements NetworkFetchPipeline {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `noSuchMethod`-based fake for [NetworkCredentialsService]. Returning
/// `null` from `headersFor` means "no auth header needed", which is the
/// branch the URL tab's review pane hits when the draft list is empty.
class _FakeNetworkCredentialsService implements NetworkCredentialsService {
  @override
  Future<Map<String, String>?> headersFor(Uri uri) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `noSuchMethod`-based fake for [MediaRepository]. The URL tab only
/// reaches into the repository on undo; the tab-shell test never commits.
class _FakeMediaRepository implements MediaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap({required bool showHiddenTabs}) {
  final pipeline = _FakeNetworkFetchPipeline();
  final credentials = _FakeNetworkCredentialsService();
  final mediaRepo = _FakeMediaRepository();
  return ProviderScope(
    overrides: [
      photoPickerServiceProvider.overrideWithValue(_StubPhotoPickerService()),
      mediaPickerHiddenTabsProvider.overrideWith((ref) => showHiddenTabs),
      // [UrlTab] watches [urlTabNotifierProvider]. The default factory
      // pulls `DatabaseService.instance.database` (uninitialized in tests),
      // so swap it for a notifier built from the fakes above.
      urlTabNotifierProvider.overrideWith(
        (ref) => UrlTabNotifier(
          pipeline: pipeline,
          credentials: credentials,
          mediaRepository: mediaRepo,
        ),
      ),
      // `NetworkThumbnail` (inside `UrlReviewPane`) reads this provider
      // directly. Even when the staged draft list is empty we override it
      // defensively so future test edits cannot accidentally trip the
      // real `DatabaseService` path.
      networkCredentialsServiceProvider.overrideWithValue(credentials),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PhotoPickerPage(
        startTime: DateTime.utc(2024, 1, 1, 9),
        endTime: DateTime.utc(2024, 1, 1, 11),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders single Scaffold (no tabs) when mediaPickerHiddenTabsProvider is false',
    (tester) async {
      await tester.pumpWidget(_wrap(showHiddenTabs: false));
      await tester.pump();

      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(DefaultTabController), findsNothing);
    },
  );

  testWidgets(
    'renders DefaultTabController with Gallery / Files / URL tabs when mediaPickerHiddenTabsProvider is true',
    (tester) async {
      await tester.pumpWidget(_wrap(showHiddenTabs: true));
      await tester.pump();

      expect(find.byType(DefaultTabController), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('URL'), findsOneWidget);
    },
  );

  testWidgets('switching to Files tab shows FilesTab', (tester) async {
    await tester.pumpWidget(_wrap(showHiddenTabs: true));
    await tester.pump();

    await tester.tap(find.text('Files'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(FilesTab), findsOneWidget);
  });

  testWidgets('switching to URL tab shows UrlTab', (tester) async {
    await tester.pumpWidget(_wrap(showHiddenTabs: true));
    await tester.pump();

    await tester.tap(find.text('URL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(UrlTab), findsOneWidget);
  });
}
