import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/webdav_media_form.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _FakeService extends Fake implements MediaStoreService {
  final connected = <WebDavConfig>[];
  final tested = <WebDavConfig>[];
  bool untrustedOnce = false;

  @override
  Future<WebDavConfig> testWebDav(WebDavConfig config) async {
    tested.add(config);
    return config;
  }

  @override
  Future<MediaStoreConnectResult> connectWebDav(WebDavConfig config) async {
    if (untrustedOnce) {
      untrustedOnce = false;
      throw MediaStoreException(
        'untrusted',
        kind: MediaStoreErrorKind.auth,
        cause: WebDavUntrustedCertificateException(
          WebDavCertificateDetails(
            host: 'nas.local',
            port: 5006,
            sha256: 'ab' * 32,
            subject: 'CN=nas',
            issuer: 'CN=nas',
            startValidity: DateTime.utc(2026),
            endValidity: DateTime.utc(2027),
          ),
        ),
      );
    }
    connected.add(config);
    return const MediaStoreConnectResult(storeId: 's1', createdNewStore: true);
  }
}

void main() {
  late _FakeService service;
  final sync = WebDavConfig(
    serverUrl: 'https://nas.local:5006',
    username: 'alice',
    password: 'secret',
    pinnedCertSha256: 'cd' * 32,
  );

  Future<void> pump(WidgetTester tester, {WebDavConfig? syncConfig}) async {
    service = _FakeService();
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          mediaStoreServiceProvider.overrideWithValue(service),
          webdavConfigProvider.overrideWith((ref) async => syncConfig),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: WebDavMediaForm())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Use my sync server copies everything but the folder', (
    tester,
  ) async {
    await pump(tester, syncConfig: sync);
    await tester.tap(find.byKey(const Key('webdav-media-use-sync')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('webdav-media-connect')));
    await tester.pumpAndSettle();
    final sent = service.connected.single;
    expect(sent.serverUrl, sync.serverUrl);
    expect(sent.pinnedCertSha256, sync.pinnedCertSha256);
    expect(sent.folder, kDefaultWebDavMediaFolder);
  });

  testWidgets('Test connection probes the form config and reports success', (
    tester,
  ) async {
    await pump(tester, syncConfig: sync);
    await tester.tap(find.byKey(const Key('webdav-media-use-sync')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('webdav-media-test')));
    await tester.pumpAndSettle();
    expect(service.tested.single.serverUrl, sync.serverUrl);
    expect(service.connected, isEmpty);
    expect(find.text('Connection successful'), findsOneWidget);
  });

  testWidgets('no sync config, no prefill button', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('webdav-media-use-sync')), findsNothing);
  });

  testWidgets('an untrusted certificate is offered, trusted and retried', (
    tester,
  ) async {
    await pump(tester, syncConfig: sync.copyWith(clearPin: true));
    service.untrustedOnce = true;
    await tester.tap(find.byKey(const Key('webdav-media-use-sync')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('webdav-media-connect')));
    // The busy indicator animates while the dialog is up, so pumpAndSettle
    // would never settle: pump fixed frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('webdav-trust')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.connected.single.pinnedCertSha256, 'ab' * 32);
  });
}
