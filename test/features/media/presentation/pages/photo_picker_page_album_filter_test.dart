// Issue #189: the Gallery tab can narrow a dive's time window to one album.
//
// The tab used to show every photo from the window in one grid, so a dive's
// camera photos sat among chat images, downloads and screenshots taken in the
// same hour. A row of album chips now narrows the grid, and picks made under
// one album stay picked while the user looks at another.

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

/// Gallery service with library access and four photos in every range: two
/// in GoPro, one in WhatsApp Images and one in no album at all.
class _GalleryService implements PhotoPickerService {
  @override
  Future<PhotoPermissionStatus> currentPermission() => checkPermission();

  @override
  bool get supportsGalleryBrowsing => true;

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(DateTime s, DateTime e) async =>
      [
        _asset('gopro-1', [_goPro]),
        _asset('wa-1', [_whatsApp]),
        _asset('gopro-2', [_goPro]),
        _asset('loose-1'),
      ];

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

const _goPro = GalleryAlbum(id: 'gopro', name: 'GoPro');
const _whatsApp = GalleryAlbum(id: 'wa', name: 'WhatsApp Images');

AssetInfo _asset(String id, [List<GalleryAlbum> albums = const []]) =>
    AssetInfo(
      id: id,
      type: AssetType.image,
      createDateTime: DateTime.utc(2024, 1, 1, 10),
      width: 4032,
      height: 3024,
      albums: albums,
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

Widget _host(List<List<AssetInfo>?> results) {
  return ProviderScope(
    overrides: [
      photoPickerServiceProvider.overrideWithValue(_GalleryService()),
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
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showPhotoPicker(
                context: context,
                diveStartTime: DateTime.utc(2024, 1, 1, 9),
                diveEndTime: DateTime.utc(2024, 1, 1, 11),
                target: const DiveAttachTarget('dive-a'),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openPicker(
  WidgetTester tester, [
  List<List<AssetInfo>?>? results,
]) async {
  await tester.pumpWidget(_host(results ?? []));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Every thumbnail in the grid, selected or not.
Finder get _thumbnails =>
    find.bySemanticsLabel(RegExp(r'^Toggle selection for photo'));

/// The unselected thumbnails, in grid order.
Finder get _unselectedThumbnails =>
    find.bySemanticsLabel('Toggle selection for photo');

TextButton _button(WidgetTester tester, String label) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, label));

void main() {
  testWidgets('offers each album with the photos it holds', (tester) async {
    await _openPicker(tester);

    expect(find.text('All albums (4)'), findsOneWidget);
    expect(find.text('GoPro (2)'), findsOneWidget);
    expect(find.text('WhatsApp Images (1)'), findsOneWidget);
  });

  testWidgets('choosing an album shows only its photos', (tester) async {
    final semantics = tester.ensureSemantics();
    await _openPicker(tester);
    expect(_thumbnails, findsNWidgets(4));

    await _tapText(tester, 'GoPro (2)');
    expect(_thumbnails, findsNWidgets(2));

    await _tapText(tester, 'All albums (4)');
    expect(_thumbnails, findsNWidgets(4));
    semantics.dispose();
  });

  testWidgets('a pick survives switching albums, and Done returns both', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final results = <List<AssetInfo>?>[];
    await _openPicker(tester, results);

    await _tapText(tester, 'GoPro (2)');
    await tester.tap(_unselectedThumbnails.first);
    await tester.pumpAndSettle();
    await _tapText(tester, 'WhatsApp Images (1)');
    // The grid is in selection mode now, so this tap reports the grid's
    // whole selection: only the WhatsApp photo.
    await tester.tap(_unselectedThumbnails.first);
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsOneWidget);
    await _tapText(tester, 'Done (2)');
    expect(results.single!.map((a) => a.id), ['gopro-1', 'wa-1']);
    semantics.dispose();
  });

  testWidgets('Select All under an album adds that album and keeps the rest', (
    tester,
  ) async {
    await _openPicker(tester);

    await _tapText(tester, 'GoPro (2)');
    await _tapText(tester, 'Select All');
    expect(find.text('2 selected'), findsOneWidget);
    expect(_button(tester, 'Select All').onPressed, isNull);

    await _tapText(tester, 'WhatsApp Images (1)');
    expect(_button(tester, 'Select All').onPressed, isNotNull);
    await _tapText(tester, 'Select All');
    expect(find.text('3 selected'), findsOneWidget);

    await _tapText(tester, 'All albums (4)');
    expect(_button(tester, 'Select All').onPressed, isNotNull);
  });

  testWidgets('Clear drops every pick, the hidden ones too', (tester) async {
    await _openPicker(tester);

    await _tapText(tester, 'Select All');
    await _tapText(tester, 'GoPro (2)');
    await _tapText(tester, 'Clear');

    expect(find.text('0 selected'), findsOneWidget);
    await _tapText(tester, 'All albums (4)');
    expect(find.text('0 selected'), findsOneWidget);
  });
}
