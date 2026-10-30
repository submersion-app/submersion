// Issue #3482 phase 2: the S3 settings page's form tests, ported to the one
// My own server form that replaced it (spec section 7.5).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/own_server_form.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/test_database.dart';
import '../../../../../support/fake_keychain_storage.dart';

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
// the real client's 404 path. Extends Fake so client additions never break
// this double: unstubbed members throw only if actually called.
class _FakeS3ApiClient extends Fake implements S3ApiClient {
  final List<String> calls = [];
  final Map<String, Uint8List> _objects = {};
  CloudStorageException? failListWith;

  @override
  void Function(String region)? onRegionCorrected;

  @override
  Future<void> putObject(
    String key,
    Uint8List bytes, {
    String? contentType,
  }) async {
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

  /// When set, listObjects parks on this future first, keeping the probe
  /// in flight so tests can dispose the page mid-operation.
  Future<void>? listGate;

  @override
  Future<List<S3ObjectInfo>> listObjects({
    String prefix = '',
    int? maxKeys,
  }) async {
    final gate = listGate;
    if (gate != null) await gate;
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

/// Remembers which account the form last wrote, so a test reads its config
/// back from the keychain without a database query racing the form's own.
class _RecordingCredentials extends AccountCredentialsStore {
  _RecordingCredentials() : super(storage: InMemoryKeychain());
  String? lastWritten;

  @override
  Future<void> write(String accountId, String json) {
    lastWritten = accountId;
    return super.write(accountId, json);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryCredentialsStore store;
  late _FakeS3ApiClient apiClient;
  late S3StorageProvider provider;
  late _RecordingCredentials credentials;

  setUp(() async {
    await setUpTestDatabase();
    store = _MemoryCredentialsStore();
    apiClient = _FakeS3ApiClient();
    provider = S3StorageProvider(
      store: store,
      apiClientFactory: (_, {onRegionCorrected}) =>
          apiClient..onRegionCorrected = onRegionCorrected,
    );
    credentials = _RecordingCredentials();
  });

  tearDown(() => tearDownTestDatabase());

  /// The saving and probing run on the database and keychain; let them
  /// finish, then rebuild.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  /// The config the form saved, read back from the account it wrote.
  Future<S3Config?> savedConfig(WidgetTester tester) async {
    final id = credentials.lastWritten;
    if (id == null) return null;
    final raw = await tester.runAsync(() => credentials.read(id));
    return raw == null
        ? null
        : S3Config.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  /// Pumps the form; with [existing], as the account detail view does for an
  /// account this device holds credentials for.
  Future<void> pumpPage(WidgetTester tester, {S3Config? existing}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    AccountGroup? group;
    if (existing != null) {
      group = await tester.runAsync(() async {
        final row = await ConnectedAccountsRepository().ensure(
          kind: AccountKind.s3,
          naturalKey: s3NaturalKey(existing),
          label: existing.bucket,
          // As the detail view has it: the row's location groups it by
          // server, so a save of the same server edits it in place.
          location: S3AccountLocation.fromConfig(existing),
        );
        await credentials.write(row.id, jsonEncode(existing.toJson()));
        credentials.lastWritten = null;
        return groupAccounts(
          rows: [row],
          statusById: {row.id: AccountStatus.signedIn},
          localLocationById: const {},
          usagesOf: (_) => const [],
        ).single;
      });
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          s3StorageProviderInstanceProvider.overrideWithValue(provider),
          accountCredentialsStoreProvider.overrideWithValue(credentials),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: OwnServerForm(
                existing: group,
                kinds: const {AccountKind.s3},
                onSaved: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.pumpAndSettle();
  }

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'http://nas.local:9000',
    );
    await tester.enterText(
      find.byKey(const Key('account-s3-bucket')),
      'dive-sync',
    );
    await tester.enterText(
      find.byKey(const Key('account-s3-access-key')),
      'ak',
    );
    await tester.enterText(
      find.byKey(const Key('account-s3-secret-key')),
      'sk',
    );
    await tester.pump();
  }

  Future<void> expandAdvanced(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('account-s3-advanced')));
    await tester.tap(find.byKey(const Key('account-s3-advanced')));
    await tester.pumpAndSettle();
  }

  testWidgets('empty form shows required errors and saves nothing', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('own-server-save')));
    await tester.tap(find.byKey(const Key('own-server-save')));
    await settle(tester);

    expect(find.text('Required'), findsNWidgets(4));
    expect(await savedConfig(tester), isNull);
  });

  testWidgets('plain http endpoint shows the unencrypted warning', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('account-s3-http-warning')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'http://nas.local:9000',
    );
    await tester.pump();
    expect(find.byKey(const Key('account-s3-http-warning')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'https://minio.example.com',
    );
    await tester.pump();
    expect(find.byKey(const Key('account-s3-http-warning')), findsNothing);
  });

  testWidgets('path-style auto-enables when a custom endpoint is entered', (
    tester,
  ) async {
    await pumpPage(tester);
    await expandAdvanced(tester);
    Switch pathStyleSwitch() => tester.widget<Switch>(
      find.descendant(
        of: find.byKey(const Key('account-s3-path-style')),
        matching: find.byType(Switch),
      ),
    );
    expect(pathStyleSwitch().value, isFalse);

    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'http://nas.local:9000',
    );
    await tester.pump();
    expect(pathStyleSwitch().value, isTrue);
  });

  testWidgets('save stores the server as its sync-role account', (
    tester,
  ) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('own-server-save')));
    await tester.tap(find.byKey(const Key('own-server-save')));
    await settle(tester);

    final saved = await savedConfig(tester);
    expect(saved, isNotNull);
    expect(saved!.bucket, 'dive-sync');
    expect(saved.prefix, 'submersion-sync/');
    expect(saved.pathStyle, isTrue);
    expect(find.text('Account saved'), findsOneWidget);
  });

  testWidgets('test connection probes without persisting', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('own-server-check')));
    await tester.tap(find.byKey(const Key('own-server-check')));
    await tester.pumpAndSettle();

    expect(find.text('Connection successful'), findsOneWidget);
    expect(await savedConfig(tester), isNull);
    expect(apiClient.calls.first, startsWith('list:'));
  });

  testWidgets('endpoint with a sub-path is rejected on save', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'https://nas.example.com/s3-api',
    );
    await tester.ensureVisible(find.byKey(const Key('own-server-save')));
    await tester.tap(find.byKey(const Key('own-server-save')));
    await settle(tester);

    expect(find.text('Endpoint URL must not include a path'), findsOneWidget);
    expect(await savedConfig(tester), isNull);
  });

  testWidgets('http warning is case-insensitive', (tester) async {
    await pumpPage(tester);
    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'HTTP://nas.local:9000',
    );
    await tester.pump();
    expect(find.byKey(const Key('account-s3-http-warning')), findsOneWidget);
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
    await tester.ensureVisible(find.byKey(const Key('own-server-check')));
    await tester.tap(find.byKey(const Key('own-server-check')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Access denied'), findsOneWidget);
    expect(await savedConfig(tester), isNull);
  });

  testWidgets('test connection failure surfaces the underlying cause', (
    tester,
  ) async {
    // A transport failure wraps the actionable detail (here a TLS handshake
    // error) in the exception's cause; the snackbar must show it, not just
    // the generic top-level message.
    apiClient.failListWith = const CloudStorageException(
      'Could not reach S3 endpoint host.example.com',
      'HandshakeException: CERTIFICATE_VERIFY_FAILED',
    );
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('own-server-check')));
    await tester.tap(find.byKey(const Key('own-server-check')));
    await tester.pumpAndSettle();
    expect(find.textContaining('CERTIFICATE_VERIFY_FAILED'), findsOneWidget);
  });

  testWidgets('endpoint guidance is an in-field hint, not a floating helper', (
    tester,
  ) async {
    await pumpPage(tester);
    final endpointField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('account-s3-endpoint')),
        matching: find.byType(TextField),
      ),
    );
    // hintText shows only while the field is blank, so it cannot be read
    // as describing the neighboring Bucket field.
    expect(
      endpointField.decoration!.hintText,
      'For example: https://s3.example.com',
    );
    expect(endpointField.decoration!.helperText, isNull);
  });

  testWidgets('advanced section is collapsed by default', (tester) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('account-s3-region')), findsNothing);
    expect(find.byKey(const Key('account-s3-prefix')), findsNothing);
    expect(find.byKey(const Key('account-s3-path-style')), findsNothing);

    await expandAdvanced(tester);
    expect(find.byKey(const Key('account-s3-region')), findsOneWidget);
    // A new server's folders are the roles' defaults; none is typed here.
    expect(find.byKey(const Key('account-s3-prefix')), findsNothing);
    expect(find.byKey(const Key('account-s3-path-style')), findsOneWidget);
  });

  testWidgets('region helper live-derives from the endpoint', (tester) async {
    await pumpPage(tester);
    await expandAdvanced(tester);
    expect(find.text('Auto-detected: us-east-1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'https://s3.us-west-004.backblazeb2.com',
    );
    await tester.pump();
    expect(find.text('Auto-detected: us-west-004'), findsOneWidget);
  });

  testWidgets('empty region saves the derived value', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'https://s3.eu-central-2.amazonaws.com',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('own-server-save')));
    await tester.tap(find.byKey(const Key('own-server-save')));
    await settle(tester);

    expect((await savedConfig(tester))!.region, 'eu-central-2');
  });

  testWidgets('manual region overrides derivation', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await expandAdvanced(tester);
    await tester.enterText(
      find.byKey(const Key('account-s3-region')),
      'eu-west-2',
    );
    await tester.ensureVisible(find.byKey(const Key('own-server-save')));
    await tester.tap(find.byKey(const Key('own-server-save')));
    await settle(tester);

    expect((await savedConfig(tester))!.region, 'eu-west-2');
  });

  testWidgets('test connection adopts and announces a detected region', (
    tester,
  ) async {
    apiClient.correctRegionTo = 'eu-west-1';
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('own-server-check')));
    await tester.tap(find.byKey(const Key('own-server-check')));
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
        of: find.byKey(const Key('account-s3-path-style')),
        matching: find.byType(Switch),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'https://s3.amazonaws.com',
    );
    await tester.pump();
    // AWS prefers virtual-hosted addressing, and the global endpoint only
    // reaches cross-region buckets in that mode.
    expect(pathStyleSwitch().value, isFalse);

    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'http://nas.local:9000',
    );
    await tester.pump();
    expect(pathStyleSwitch().value, isTrue);
  });

  testWidgets('legacy blank-endpoint config prefills the AWS endpoint', (
    tester,
  ) async {
    await pumpPage(
      tester,
      existing: S3Config(
        endpoint: '',
        region: 'eu-west-1',
        bucket: 'dive-sync',
        accessKeyId: 'ak',
        secretAccessKey: 'sk',
      ),
    );
    expect(find.text('https://s3.eu-west-1.amazonaws.com'), findsOneWidget);
  });

  testWidgets('test connection finishing after disposal does not throw', (
    tester,
  ) async {
    final gate = Completer<void>();
    apiClient.listGate = gate.future;
    apiClient.correctRegionTo = 'eu-west-1';
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('own-server-check')));
    await tester.tap(find.byKey(const Key('own-server-check')));
    await tester.pump();

    // Dispose the page while the probe is still in flight, then let it
    // complete: the detected-region write must not touch dead controllers.
    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('existing config populates the region field on load', (
    tester,
  ) async {
    await pumpPage(
      tester,
      existing: S3Config(
        endpoint: 'https://s3.example.com',
        region: 'auto',
        bucket: 'dive-sync',
        accessKeyId: 'ak',
        secretAccessKey: 'sk',
      ),
    );
    await expandAdvanced(tester);
    expect(find.text('auto'), findsOneWidget);
    expect(find.textContaining('Auto-detected'), findsNothing);
  });

  // Review: saving an edit of the same server wrote only the keys, so a new
  // region or addressing silently reverted.
  testWidgets('an edited region survives saving the same server', (
    tester,
  ) async {
    await pumpPage(
      tester,
      existing: S3Config(
        endpoint: 'https://s3.example.com',
        region: 'auto',
        bucket: 'dive-sync',
        accessKeyId: 'ak',
        secretAccessKey: 'sk',
      ),
    );
    await expandAdvanced(tester);
    await tester.enterText(
      find.byKey(const Key('account-s3-region')),
      'eu-west-2',
    );
    await tester.ensureVisible(find.byKey(const Key('own-server-save')));
    await tester.tap(find.byKey(const Key('own-server-save')));
    await settle(tester);

    final saved = (await savedConfig(tester))!;
    expect(saved.region, 'eu-west-2');
    expect(saved.bucket, 'dive-sync');
  });

  // Review of #3527: rows arrive newest first, so a library folder added
  // after the sync folder came first; signing in must start from the sync
  // folder, or the save relabels the library row and can move sync there.
  testWidgets('signing in starts from the sync folder, not the newest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    S3AccountLocation at(String prefix) => S3AccountLocation(
      displayHost: 'minio.home',
      endpoint: 'https://minio.home',
      bucket: 'dives',
      region: 'us-east-1',
      prefix: prefix,
      pathStyle: true,
    );
    ConnectedAccount row(String id, String prefix) => ConnectedAccount(
      id: id,
      kind: AccountKind.s3,
      label: 'dives @ minio.home',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      location: at(prefix),
    );
    final group = groupAccounts(
      rows: [
        row('library', 'submersion-sites/reef/'),
        row('sync', 'submersion-sync/'),
      ],
      statusById: const {
        'library': AccountStatus.needsSignIn,
        'sync': AccountStatus.needsSignIn,
      },
      localLocationById: const {},
      usagesOf: (_) => const [],
    ).single;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          s3StorageProviderInstanceProvider.overrideWithValue(provider),
          accountCredentialsStoreProvider.overrideWithValue(credentials),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: OwnServerForm(
                existing: group,
                kinds: const {AccountKind.s3},
                showSyncFolder: true,
                onSaved: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.pumpAndSettle();
    await expandAdvanced(tester);

    final prefix = tester.widget<TextFormField>(
      find.byKey(const Key('account-s3-prefix')),
    );
    expect(prefix.controller!.text, 'submersion-sync/');
  });
}
