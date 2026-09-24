// Issue #1996: the Gallery tab's selection is scoped to one picker session.
//
// The picker is opened from a dive or a dive site, and each session may
// attach to a different owner. Photos selected while attaching to site A
// must not arrive preselected when the picker next opens for site B.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Gallery service with library access and two photos in every range.
class _GalleryService implements PhotoPickerService {
  @override
  Future<PhotoPermissionStatus> currentPermission() => checkPermission();

  @override
  bool get supportsGalleryBrowsing => true;

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(DateTime s, DateTime e) async =>
      [_asset('photo-1'), _asset('photo-2')];

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async =>
      null;

  @override
  Future<Uint8List?> getFileBytes(String assetId) async => null;

  @override
  Future<PhotoPermissionStatus> checkPermission() async =>
      PhotoPermissionStatus.authorized;

  @override
  Future<PhotoPermissionStatus> requestPermission() async =>
      PhotoPermissionStatus.authorized;

  @override
  Future<String?> getFilePath(String assetId) async => null;

  @override
  Future<MediaSourceMetadata?> getAssetMetadata(String assetId) async => null;
}

AssetInfo _asset(String id) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime.utc(2024, 1, 1, 10),
  width: 4032,
  height: 3024,
);

/// Opening the picker resets the URL tab, whose default factory reaches the
/// uninitialized database. None of these collaborators is ever called.
class _FakeNetworkFetchPipeline implements NetworkFetchPipeline {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNetworkCredentialsService implements NetworkCredentialsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMediaRepository implements MediaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A host screen with one button per attach target, both opening the
/// picker the way the dive and site media sections do.
Widget _host(PhotoPickerService service) {
  Widget openButton(String label, MediaAttachTarget target) => Builder(
    builder: (context) => TextButton(
      onPressed: () => showPhotoPicker(
        context: context,
        diveStartTime: DateTime.utc(2024, 1, 1, 9),
        diveEndTime: DateTime.utc(2024, 1, 1, 11),
        target: target,
      ),
      child: Text(label),
    ),
  );

  return ProviderScope(
    overrides: [
      photoPickerServiceProvider.overrideWithValue(service),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      urlTabNotifierProvider.overrideWith(
        (ref) => UrlTabNotifier(
          pipeline: _FakeNetworkFetchPipeline(),
          credentials: _FakeNetworkCredentialsService(),
          mediaRepository: _FakeMediaRepository(),
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            openButton('Site A', const SiteAttachTarget('site-a')),
            openButton('Site B', const SiteAttachTarget('site-b')),
          ],
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _selectFirstPhoto(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Toggle selection for photo').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'photos confirmed for one site are not preselected for the next',
    (tester) async {
      // The thumbnails are only addressable by their semantics label. The
      // handle is disposed in the body: Flutter checks for live handles before
      // tear-downs run.
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(_GalleryService()));

      await _open(tester, 'Site A');
      await _selectFirstPhoto(tester);
      expect(find.text('Done (1)'), findsOneWidget);
      await tester.tap(find.text('Done (1)'));
      await tester.pumpAndSettle();

      await _open(tester, 'Site B');

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Done (1)'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('a selection abandoned with Close does not follow the user', (
    tester,
  ) async {
    // The thumbnails are only addressable by their semantics label. The
    // handle is disposed in the body: Flutter checks for live handles before
    // tear-downs run.
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(_GalleryService()));

    await _open(tester, 'Site A');
    await _selectFirstPhoto(tester);
    await tester.tap(find.byTooltip('Close photo picker'));
    await tester.pumpAndSettle();

    await _open(tester, 'Site B');

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Done (1)'), findsNothing);
    semantics.dispose();
  });
}
