import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/features/settings/presentation/pages/s3_config_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _MemoryCredentialsStore implements S3CredentialsStore {
  S3Config? stored;

  @override
  Future<S3Config?> load() async => stored;

  @override
  Future<void> save(S3Config config) async => stored = config;

  @override
  Future<void> clear() async => stored = null;
}

// Stores objects written via putObject and serves them via getObject.
// Throws CloudStorageException for keys that have never been put, mirroring
// the real client's 404 path.
class _FakeS3ApiClient implements S3ApiClient {
  final List<String> calls = [];
  final Map<String, Uint8List> _objects = {};

  @override
  Future<void> putObject(String key, Uint8List bytes) async {
    calls.add('put:$key');
    _objects[key] = bytes;
  }

  @override
  Future<Uint8List> getObject(String key) async {
    final data = _objects[key];
    if (data == null) {
      throw CloudStorageException('File not found in S3: $key');
    }
    return data;
  }

  @override
  Future<S3ObjectInfo?> headObject(String key) async => null;

  @override
  Future<void> deleteObject(String key) async {
    calls.add('delete:$key');
    _objects.remove(key);
  }

  @override
  Future<List<S3ObjectInfo>> listObjects({
    String prefix = '',
    int? maxKeys,
  }) async {
    calls.add('list:$prefix');
    return const [];
  }

  @override
  void close() {}
}

void main() {
  late _MemoryCredentialsStore store;
  late _FakeS3ApiClient apiClient;
  late S3StorageProvider provider;

  setUp(() {
    store = _MemoryCredentialsStore();
    apiClient = _FakeS3ApiClient();
    provider = S3StorageProvider(
      store: store,
      apiClientFactory: (_) => apiClient,
    );
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          s3StorageProviderInstanceProvider.overrideWithValue(provider),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: S3ConfigPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'http://nas.local:9000',
    );
    await tester.enterText(find.byKey(const Key('s3-bucket')), 'dive-sync');
    await tester.enterText(find.byKey(const Key('s3-access-key')), 'ak');
    await tester.enterText(find.byKey(const Key('s3-secret-key')), 'sk');
    await tester.pump();
  }

  testWidgets('empty form shows required errors and saves nothing', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('s3-save')));
    await tester.tap(find.byKey(const Key('s3-save')));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNWidgets(3));
    expect(store.stored, isNull);
  });

  testWidgets('plain http endpoint shows the unencrypted warning', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('s3-http-warning')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'http://nas.local:9000',
    );
    await tester.pump();
    expect(find.byKey(const Key('s3-http-warning')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'https://minio.example.com',
    );
    await tester.pump();
    expect(find.byKey(const Key('s3-http-warning')), findsNothing);
  });

  testWidgets('path-style auto-enables when a custom endpoint is entered', (
    tester,
  ) async {
    await pumpPage(tester);
    Switch pathStyleSwitch() => tester.widget<Switch>(
      find.descendant(
        of: find.byKey(const Key('s3-path-style')),
        matching: find.byType(Switch),
      ),
    );
    expect(pathStyleSwitch().value, isFalse);

    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'http://nas.local:9000',
    );
    await tester.pump();
    expect(pathStyleSwitch().value, isTrue);
  });

  testWidgets('save persists the config and selects the S3 provider', (
    tester,
  ) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('s3-save')));
    await tester.tap(find.byKey(const Key('s3-save')));
    await tester.pumpAndSettle();

    expect(store.stored, isNotNull);
    expect(store.stored!.bucket, 'dive-sync');
    expect(store.stored!.prefix, 'submersion-sync/');
    expect(store.stored!.pathStyle, isTrue);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(S3ConfigPage)),
    );
    expect(
      container.read(selectedCloudProviderTypeProvider),
      CloudProviderType.s3,
    );
    expect(find.text('S3 configuration saved'), findsOneWidget);
  });

  testWidgets('test connection probes without persisting', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('s3-test')));
    await tester.tap(find.byKey(const Key('s3-test')));
    await tester.pumpAndSettle();

    expect(find.text('Connection successful'), findsOneWidget);
    expect(store.stored, isNull);
    expect(apiClient.calls.first, startsWith('list:'));
  });

  testWidgets('remove clears an existing configuration after confirm', (
    tester,
  ) async {
    store.stored = S3Config(
      endpoint: 'http://nas.local:9000',
      bucket: 'dive-sync',
      accessKeyId: 'ak',
      secretAccessKey: 'sk',
    );
    await pumpPage(tester);

    await tester.ensureVisible(find.byKey(const Key('s3-remove')));
    await tester.tap(find.byKey(const Key('s3-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Remove S3 configuration?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('s3-remove-confirm')));
    await tester.pumpAndSettle();

    expect(store.stored, isNull);
  });

  testWidgets('endpoint with a sub-path is rejected on save', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'https://nas.example.com/s3-api',
    );
    await tester.ensureVisible(find.byKey(const Key('s3-save')));
    await tester.tap(find.byKey(const Key('s3-save')));
    await tester.pumpAndSettle();

    expect(find.text('Endpoint URL must not include a path'), findsOneWidget);
    expect(store.stored, isNull);
  });

  testWidgets('http warning is case-insensitive', (tester) async {
    await pumpPage(tester);
    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'HTTP://nas.local:9000',
    );
    await tester.pump();
    expect(find.byKey(const Key('s3-http-warning')), findsOneWidget);
  });
}
