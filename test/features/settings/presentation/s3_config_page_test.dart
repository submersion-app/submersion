import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/sync_service.dart'
    show ConflictResolution;
import 'package:submersion/features/settings/presentation/pages/s3_config_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _MemoryCredentialsStore implements S3CredentialsStore {
  S3Config? stored;
  Object? failSaveWith;

  @override
  Future<S3Config?> load() async => stored;

  @override
  Future<void> save(S3Config config) async {
    if (failSaveWith != null) throw failSaveWith!;
    stored = config;
  }

  @override
  Future<void> clear() async => stored = null;
}

// Stores objects written via putObject and serves them via getObject.
// Throws CloudStorageException for keys that have never been put, mirroring
// the real client's 404 path.
class _FakeS3ApiClient implements S3ApiClient {
  final List<String> calls = [];
  final Map<String, Uint8List> _objects = {};
  CloudStorageException? failListWith;

  @override
  void Function(String region)? onRegionCorrected;

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

  /// When set, the next listObjects reports this region as a server
  /// correction, mirroring the real client's replay behavior.
  String? correctRegionTo;

  @override
  Future<List<S3ObjectInfo>> listObjects({
    String prefix = '',
    int? maxKeys,
  }) async {
    if (failListWith != null) throw failListWith!;
    final correction = correctRegionTo;
    if (correction != null) {
      correctRegionTo = null;
      onRegionCorrected?.call(correction);
    }
    calls.add('list:$prefix');
    return const [];
  }

  @override
  void close() {}
}

/// Minimal [SyncNotifier] stub that avoids touching the database.
/// Accepts a [Ref] so [signOut] can mirror the real notifier's side-effect of
/// clearing [selectedCloudProviderTypeProvider].
class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  final Ref _ref;
  _FakeSyncNotifier(this._ref) : super(const SyncState());

  @override
  Future<void> performSync({bool auto = false}) async {}

  @override
  Future<FirstSyncMergeInfo?> firstSyncMergeInfo() async => null;

  @override
  Future<LibraryEpochMarker?> libraryReplaceInfo() async => null;

  @override
  Future<void> adoptReplacedLibrary() async {}

  @override
  Future<void> refreshState() async {}

  @override
  Future<void> resetSyncState() async {}

  @override
  Future<void> signOut() async {
    _ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
    state = const SyncState();
  }

  @override
  Future<void> resolveConflict(
    String entityType,
    String recordId,
    ConflictResolution resolution,
  ) async {}
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
      apiClientFactory: (_, {onRegionCorrected}) =>
          apiClient..onRegionCorrected = onRegionCorrected,
    );
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    CloudProviderType? selected,
  }) async {
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
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier(ref)),
          selectedCloudProviderTypeProvider.overrideWith((ref) => selected),
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

  Future<void> expandAdvanced(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('s3-advanced')));
    await tester.tap(find.byKey(const Key('s3-advanced')));
    await tester.pumpAndSettle();
  }

  testWidgets('empty form shows required errors and saves nothing', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('s3-save')));
    await tester.tap(find.byKey(const Key('s3-save')));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNWidgets(4));
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
    await expandAdvanced(tester);
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

  testWidgets('test connection failure shows the specific error', (
    tester,
  ) async {
    apiClient.failListWith = const CloudStorageException(
      'Access denied. Check the access key, secret key, and bucket '
      'permissions.',
    );
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('s3-test')));
    await tester.tap(find.byKey(const Key('s3-test')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Access denied'), findsOneWidget);
    expect(store.stored, isNull);
  });

  testWidgets('save failure surfaces an error and selects nothing', (
    tester,
  ) async {
    store.failSaveWith = Exception('keychain locked');
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('s3-save')));
    await tester.tap(find.byKey(const Key('s3-save')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not access secure storage'),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(S3ConfigPage)),
    );
    expect(container.read(selectedCloudProviderTypeProvider), isNull);
  });

  testWidgets('removing while S3 is selected deselects the provider', (
    tester,
  ) async {
    store.stored = S3Config(
      endpoint: 'http://nas.local:9000',
      bucket: 'dive-sync',
      accessKeyId: 'ak',
      secretAccessKey: 'sk',
    );
    await pumpPage(tester, selected: CloudProviderType.s3);
    await tester.ensureVisible(find.byKey(const Key('s3-remove')));
    await tester.tap(find.byKey(const Key('s3-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('s3-remove-confirm')));
    await tester.pumpAndSettle();
    expect(store.stored, isNull);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(S3ConfigPage)),
    );
    expect(container.read(selectedCloudProviderTypeProvider), isNull);
  });

  testWidgets('endpoint guidance is an in-field hint, not a floating helper', (
    tester,
  ) async {
    await pumpPage(tester);
    final endpointField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('s3-endpoint')),
        matching: find.byType(TextField),
      ),
    );
    // hintText shows only while the field is blank, so it cannot be read
    // as describing the neighboring Bucket field.
    expect(
      endpointField.decoration!.hintText,
      'For Amazon S3, enter https://s3.amazonaws.com',
    );
    expect(endpointField.decoration!.helperText, isNull);
  });

  testWidgets('advanced section is collapsed by default', (tester) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('s3-region')), findsNothing);
    expect(find.byKey(const Key('s3-prefix')), findsNothing);
    expect(find.byKey(const Key('s3-path-style')), findsNothing);

    await expandAdvanced(tester);
    expect(find.byKey(const Key('s3-region')), findsOneWidget);
    expect(find.byKey(const Key('s3-prefix')), findsOneWidget);
    expect(find.byKey(const Key('s3-path-style')), findsOneWidget);
  });

  testWidgets('region helper live-derives from the endpoint', (tester) async {
    await pumpPage(tester);
    await expandAdvanced(tester);
    expect(find.text('Auto-detected: us-east-1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'https://s3.us-west-004.backblazeb2.com',
    );
    await tester.pump();
    expect(find.text('Auto-detected: us-west-004'), findsOneWidget);
  });

  testWidgets('empty region saves the derived value', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'https://s3.eu-central-2.amazonaws.com',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('s3-save')));
    await tester.tap(find.byKey(const Key('s3-save')));
    await tester.pumpAndSettle();

    expect(store.stored!.region, 'eu-central-2');
  });

  testWidgets('manual region overrides derivation', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await expandAdvanced(tester);
    await tester.enterText(find.byKey(const Key('s3-region')), 'eu-west-2');
    await tester.ensureVisible(find.byKey(const Key('s3-save')));
    await tester.tap(find.byKey(const Key('s3-save')));
    await tester.pumpAndSettle();

    expect(store.stored!.region, 'eu-west-2');
  });

  testWidgets('test connection adopts and announces a detected region', (
    tester,
  ) async {
    apiClient.correctRegionTo = 'eu-west-1';
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('s3-test')));
    await tester.tap(find.byKey(const Key('s3-test')));
    await tester.pumpAndSettle();

    expect(find.text('Region detected: eu-west-1'), findsOneWidget);
    await expandAdvanced(tester);
    expect(find.text('eu-west-1'), findsOneWidget); // field adopted it
  });

  testWidgets('an amazonaws endpoint does not auto-enable path-style', (
    tester,
  ) async {
    await pumpPage(tester);
    await expandAdvanced(tester);
    Switch pathStyleSwitch() => tester.widget<Switch>(
      find.descendant(
        of: find.byKey(const Key('s3-path-style')),
        matching: find.byType(Switch),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'https://s3.amazonaws.com',
    );
    await tester.pump();
    // AWS prefers virtual-hosted addressing, and the global endpoint only
    // reaches cross-region buckets in that mode.
    expect(pathStyleSwitch().value, isFalse);

    await tester.enterText(
      find.byKey(const Key('s3-endpoint')),
      'http://nas.local:9000',
    );
    await tester.pump();
    expect(pathStyleSwitch().value, isTrue);
  });

  testWidgets('legacy blank-endpoint config prefills the AWS endpoint', (
    tester,
  ) async {
    store.stored = S3Config(
      endpoint: '',
      region: 'eu-west-1',
      bucket: 'dive-sync',
      accessKeyId: 'ak',
      secretAccessKey: 'sk',
    );
    await pumpPage(tester);
    expect(find.text('https://s3.eu-west-1.amazonaws.com'), findsOneWidget);
  });

  testWidgets('existing config populates the region field on load', (
    tester,
  ) async {
    store.stored = S3Config(
      endpoint: 'https://s3.example.com',
      region: 'auto',
      bucket: 'dive-sync',
      accessKeyId: 'ak',
      secretAccessKey: 'sk',
    );
    await pumpPage(tester);
    await expandAdvanced(tester);
    expect(find.text('auto'), findsOneWidget);
    expect(find.textContaining('Auto-detected'), findsNothing);
  });
}
