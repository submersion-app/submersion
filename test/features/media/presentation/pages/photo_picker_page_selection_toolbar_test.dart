// Issue #2059: selecting the first photo must not move the grid.
//
// The Gallery tab's selection toolbar used to appear only once something was
// selected, which pushed every thumbnail down by a row. A user tapping
// several photos quickly then hit the wrong one. The toolbar is now always
// present, and its buttons are disabled rather than removed, so neither the
// grid nor the buttons move as the selection changes.

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

Widget _host() {
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
            onPressed: () => showPhotoPicker(
              context: context,
              diveStartTime: DateTime.utc(2024, 1, 1, 9),
              diveEndTime: DateTime.utc(2024, 1, 1, 11),
              target: const SiteAttachTarget('site-a'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// The unselected thumbnails, in grid order. A selected thumbnail changes its
/// label, so after selecting the first photo this finds only the second.
Finder get _unselectedThumbnails =>
    find.bySemanticsLabel('Toggle selection for photo');

TextButton _button(WidgetTester tester, String label) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, label));

void main() {
  testWidgets('selecting the first photo does not move the others', (
    tester,
  ) async {
    // The thumbnails are only addressable by their semantics label. The
    // handle is disposed in the body: Flutter checks for live handles before
    // tear-downs run.
    final semantics = tester.ensureSemantics();
    await _openPicker(tester);

    final secondBefore = tester.getTopLeft(_unselectedThumbnails.last);
    await tester.tap(_unselectedThumbnails.first);
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(_unselectedThumbnails, findsOneWidget);
    expect(tester.getTopLeft(_unselectedThumbnails), secondBefore);
    semantics.dispose();
  });

  testWidgets('with nothing selected the toolbar offers only Select All', (
    tester,
  ) async {
    await _openPicker(tester);

    expect(find.text('0 selected'), findsOneWidget);
    expect(_button(tester, 'Select All').onPressed, isNotNull);
    expect(_button(tester, 'Clear').onPressed, isNull);
  });

  testWidgets('Select All is disabled, not removed, once all are selected', (
    tester,
  ) async {
    await _openPicker(tester);

    final clearBefore = tester.getTopLeft(find.text('Clear'));
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsOneWidget);
    expect(_button(tester, 'Select All').onPressed, isNull);
    expect(_button(tester, 'Clear').onPressed, isNotNull);
    expect(tester.getTopLeft(find.text('Clear')), clearBefore);
  });

  testWidgets('Clear returns the toolbar to its empty state', (tester) async {
    await _openPicker(tester);

    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(_button(tester, 'Clear').onPressed, isNull);
  });
}
