// Issue #259: a dive's Gallery tab shows what the dive's lookup finds, not
// what a plain date range returns. The range only knows this device's clock,
// so it comes back empty once the device has left the dive's timezone.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A library with access granted and nothing in the date range it is asked
/// for, like one searched on the wrong clock.
class _EmptyRangeService implements PhotoPickerService {
  int rangeQueries = 0;

  @override
  Future<PhotoPermissionStatus> currentPermission() => checkPermission();

  @override
  bool get supportsGalleryBrowsing => true;

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(DateTime s, DateTime e) async {
    rangeQueries++;
    return [];
  }

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
  createDateTime: DateTime(2026, 3, 10, 10, 20),
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

Future<void> _open(
  WidgetTester tester,
  _EmptyRangeService service,
  Future<List<AssetInfo>> Function(bool Function() isActive) loadAssets,
) async {
  await tester.pumpWidget(
    ProviderScope(
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
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPhotoPicker(
                context: context,
                diveStartTime: DateTime(2026, 3, 10, 9, 30),
                diveEndTime: DateTime(2026, 3, 10, 12),
                buffer: Duration.zero,
                loadAssets: loadAssets,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
}

void main() {
  testWidgets('the Gallery tab shows what the dive lookup found', (
    tester,
  ) async {
    final service = _EmptyRangeService();

    await _open(tester, service, (_) async => [_asset('palau')]);
    await tester.pumpAndSettle();

    expect(find.text('No photos found'), findsNothing);
    expect(service.rangeQueries, 0);
  });

  testWidgets('the lookup learns when the picker has closed', (tester) async {
    final service = _EmptyRangeService();
    final lookupDone = Completer<List<AssetInfo>>();
    late bool Function() isActive;

    await _open(tester, service, (active) {
      isActive = active;
      return lookupDone.future;
    });
    // The page shows a spinner until the lookup answers, so it never settles.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(isActive(), isTrue);

    await tester.tap(find.byTooltip('Close photo picker'));
    // One frame to start the route's exit, one past its end to dispose it.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(isActive(), isFalse);
    lookupDone.complete([]);
  });
}
