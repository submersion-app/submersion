import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/core/services/shared_library/library_account_setup.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/pages/connect_shared_library_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _FakeMembershipService extends SharedLibraryMembershipService {
  _FakeMembershipService(this.probes)
    : super(
        store: SharedLibraryStore(),
        transportFor: ({required account, required prefix}) async =>
            SharedLibraryTransport(FakeCloudStorageProvider(), prefix: prefix),
      );

  final Map<String, LibraryProbe> probes;

  @override
  Future<LibraryProbe> probe({
    required ConnectedAccount account,
    required String prefix,
  }) async => probes[prefix] ?? const LibraryProbe(exists: false);

  /// A library made by Create; null refuses it as already there.
  CreatedLibrary? created;

  /// The secret each join was given.
  final joinSecrets = <String?>[];

  @override
  Future<LibraryProbe> unlockProbe({
    required ConnectedAccount account,
    required String prefix,
    required String secret,
  }) async {
    if (secret != 'pw') throw WrongPassphraseError();
    return const LibraryProbe(
      exists: true,
      id: 'S',
      name: 'Sealed',
      encrypted: true,
      keyId: 'k',
    );
  }

  @override
  Future<SharedLibrary> join({
    required ConnectedAccount account,
    required String prefix,
    required String diverId,
    required String displayName,
    String? secret,
    bool adoptFolderRoles = false,
    LibrarySigningKey? signingKey,
  }) async {
    joinSecrets.add(secret);
    throw StateError('stop here');
  }

  @override
  Future<CreatedLibrary> createWithRecovery({
    required ConnectedAccount account,
    required String prefix,
    required String name,
    required String diverId,
    required String displayName,
  }) async => created ?? (throw LibraryExistsError(prefix));
}

Widget _connectApp(
  List<Override> base,
  List<ConnectedAccount> Function() accounts,
) => testApp(
  overrides: [
    ...base,
    eligibleLibraryAccountsProvider.overrideWith((ref) async => accounts()),
    sharedLibraryMembershipServiceProvider.overrideWithValue(
      _FakeMembershipService(const {}),
    ),
    validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
    currentDiverProvider.overrideWith(
      (ref) async => Diver(
        id: 'd',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ),
  ],
  locale: const Locale('en'),
  child: const ConnectSharedLibraryPage(),
);

/// The connect page with no account yet and [setup] saving new ones into
/// [accounts].
Widget _setupApp(
  List<Override> base,
  List<ConnectedAccount> accounts,
  LibraryAccountSetup setup,
) => testApp(
  overrides: [
    ...base,
    eligibleLibraryAccountsProvider.overrideWith(
      (ref) async => List.of(accounts),
    ),
    libraryAccountSetupProvider.overrideWithValue(setup),
    validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
    currentDiverProvider.overrideWith((ref) async => null),
  ],
  locale: const Locale('en'),
  child: const ConnectSharedLibraryPage(),
);

Future<void> _fillS3(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('library-s3-endpoint')),
    'https://s3.eu-west-1.amazonaws.com',
  );
  await tester.enterText(
    find.byKey(const Key('library-s3-bucket')),
    'submersion-sync',
  );
  await tester.enterText(find.byKey(const Key('library-s3-access-key')), 'k');
  await tester.enterText(find.byKey(const Key('library-s3-secret-key')), 's');
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

ConnectedAccount _bucket() => ConnectedAccount(
  id: 'a',
  kind: AccountKind.s3,
  label: 'Bucket',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  testWidgets('probe routes to Join or Create', (tester) async {
    final accounts = [
      ConnectedAccount(
        id: 'a',
        kind: AccountKind.s3,
        label: 'Bucket',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ];
    final probes = <String, LibraryProbe>{
      'site-sync': const LibraryProbe(
        exists: true,
        id: 'L',
        name: 'Reef Survey',
      ),
      'old': const LibraryProbe(
        exists: true,
        id: 'O',
        name: 'Old',
        formatVersion: 9,
      ),
    };
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          eligibleLibraryAccountsProvider.overrideWith((ref) async => accounts),
          sharedLibraryMembershipServiceProvider.overrideWithValue(
            _FakeMembershipService(probes),
          ),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
          currentDiverProvider.overrideWith(
            (ref) async => Diver(
              id: 'd',
              name: 'Ann',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ),
        ],
        locale: const Locale('en'),
        child: const ConnectSharedLibraryPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bucket'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('library-prefix')),
      'site-sync',
    );
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('Join Reef Survey'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget, reason: 'display name prefilled');

    await tester.enterText(find.byKey(const Key('library-prefix')), 'other');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('No library here yet.'), findsOneWidget);
    expect(find.text('Create library'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('library-prefix')), 'old');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(
      find.text('This library needs a newer version of Submersion.'),
      findsOneWidget,
    );
  });

  testWidgets('without an eligible account the hint shows', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          eligibleLibraryAccountsProvider.overrideWith((ref) async => const []),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
          currentDiverProvider.overrideWith((ref) async => null),
        ],
        locale: const Locale('en'),
        child: const ConnectSharedLibraryPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Shared site libraries work with S3 and WebDAV accounts.'),
      findsOneWidget,
    );
  });

  testWidgets('a create the storage refuses explains itself in words', (
    tester,
  ) async {
    await tester.pumpWidget(
      _connectApp(await getBaseOverrides(), () => [_bucket()]),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('library-prefix')),
      'site-sync',
    );
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create library'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Someone created a library here meanwhile. Check again to join it.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Bad state'), findsNothing);
  });

  testWidgets('a refreshed account list keeps the chosen account', (
    tester,
  ) async {
    await tester.pumpWidget(
      // Every load builds new instances, as the repository does.
      _connectApp(await getBaseOverrides(), () => [_bucket()]),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ConnectSharedLibraryPage)),
    );
    container.invalidate(eligibleLibraryAccountsProvider);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Bucket'), findsOneWidget);
  });

  testWidgets('a storage account is set up right on the connect page', (
    tester,
  ) async {
    _tallView(tester);
    final accounts = <ConnectedAccount>[];
    final setup = _RecordingSetup(onSave: accounts.add);
    await tester.pumpWidget(
      _setupApp(await getBaseOverrides(), accounts, setup),
    );
    await tester.pumpAndSettle();

    // No account yet: set one up here instead of leaving for Settings.
    await tester.tap(find.text('Add storage account'));
    await tester.pumpAndSettle();
    // The folder comes first: the account is saved for it.
    final folderY = tester
        .getTopLeft(find.byKey(const Key('library-prefix')))
        .dy;
    final formY = tester
        .getTopLeft(find.byKey(const Key('library-s3-endpoint')))
        .dy;
    expect(folderY, lessThan(formY));
    await tester.enterText(find.byKey(const Key('library-prefix')), 'reef');
    await _fillS3(tester);
    expect(find.byKey(const Key('library-s3-prefix')), findsNothing);
    await tester.tap(find.text('Save account'));
    await tester.pumpAndSettle();

    expect(setup.s3.single.bucket, 'submersion-sync');
    expect(setup.folders, ['reef']);
    expect(
      find.text('submersion-sync @ s3.eu-west-1.amazonaws.com'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('library-prefix')), findsOneWidget);
    expect(find.text('Save account'), findsNothing);
  });

  testWidgets('the WebDAV form leaves the folder to the library', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _connectApp(await getBaseOverrides(), () => [_bucket()]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add storage account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WebDAV'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-webdav-server-url')), findsOneWidget);
    expect(find.byKey(const Key('library-webdav-folder')), findsNothing);
  });

  testWidgets('a WebDAV server offers its certificate for trust first', (
    tester,
  ) async {
    _tallView(tester);
    final accounts = <ConnectedAccount>[];
    final setup = _RecordingSetup(onSave: accounts.add)..untrustedOnce = true;
    await tester.pumpWidget(
      _setupApp(await getBaseOverrides(), accounts, setup),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add storage account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WebDAV'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('library-webdav-server-url')),
      'https://nas.local:5006',
    );
    await tester.enterText(
      find.byKey(const Key('library-webdav-username')),
      'alice',
    );
    await tester.enterText(
      find.byKey(const Key('library-webdav-password')),
      'secret',
    );
    await tester.tap(find.text('Save account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('webdav-trust')));
    await tester.pumpAndSettle();

    expect(setup.webdav.single.pinnedCertSha256, 'ab' * 32);
    expect(find.text('Save account'), findsNothing);
  });

  testWidgets('a failed save says why when there is no account yet', (
    tester,
  ) async {
    _tallView(tester);
    final setup = _RecordingSetup(onSave: (_) {})
      ..saveError = const CloudStorageException('keychain locked');
    await tester.pumpWidget(_setupApp(await getBaseOverrides(), [], setup));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add storage account'));
    await tester.pumpAndSettle();
    await _fillS3(tester);
    await tester.tap(find.text('Save account'));
    await tester.pumpAndSettle();

    expect(find.text('keychain locked'), findsOneWidget);
  });

  testWidgets('an encrypted library asks for its passphrase first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _FakeMembershipService({
      'sealed': const LibraryProbe(exists: true, id: 'S', encrypted: true),
    });
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          eligibleLibraryAccountsProvider.overrideWith(
            (ref) async => [_bucket()],
          ),
          sharedLibraryMembershipServiceProvider.overrideWithValue(service),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
          currentDiverProvider.overrideWith(
            (ref) async => Diver(
              id: 'd',
              name: 'Ann',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ),
        ],
        locale: const Locale('en'),
        child: const ConnectSharedLibraryPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), 'sealed');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Encrypted library'), findsOneWidget);
    expect(find.textContaining('Join'), findsNothing);

    await tester.enterText(find.byKey(const Key('library-secret')), 'nope');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(
      find.text('That passphrase does not open this library.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('library-secret')), 'pw');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join Sealed'));
    await tester.pumpAndSettle();
    expect(service.joinSecrets, ['pw']);
  });

  testWidgets('a library from a test build cannot be joined', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          eligibleLibraryAccountsProvider.overrideWith(
            (ref) async => [_bucket()],
          ),
          sharedLibraryMembershipServiceProvider.overrideWithValue(
            _FakeMembershipService({
              'old': const LibraryProbe(
                exists: true,
                id: 'O',
                name: 'Old',
                formatVersion: 1,
              ),
            }),
          ),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
          currentDiverProvider.overrideWith((ref) async => null),
        ],
        locale: const Locale('en'),
        child: const ConnectSharedLibraryPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), 'old');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This library was made by a test build of Submersion. Create it again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Join Old'), findsNothing);
  });

  testWidgets('a new library shows its recovery code', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _FakeMembershipService(const {})
      ..created = const CreatedLibrary(
        library: SharedLibrary(
          id: 'N',
          name: 'Reef Survey',
          connectedAccountId: 'a',
          prefix: 'reef',
        ),
        recoveryCode: 'alpha-bravo-charlie',
      );
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          eligibleLibraryAccountsProvider.overrideWith(
            (ref) async => [_bucket()],
          ),
          sharedLibraryMembershipServiceProvider.overrideWithValue(service),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
          currentDiverProvider.overrideWith(
            (ref) async => Diver(
              id: 'd',
              name: 'Ann',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ),
        ],
        locale: const Locale('en'),
        child: const ConnectSharedLibraryPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), 'reef');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create library'));
    await tester.pumpAndSettle();
    expect(find.text('alpha-bravo-charlie'), findsOneWidget);
  });

  testWidgets('the storage guide opens for the typed folder', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _connectApp([
        ...await getBaseOverrides(),
        libraryAccountSetupProvider.overrideWithValue(_BucketSetup()),
      ], () => [_bucket()]),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), 'reef');
    await tester.tap(find.text('How to set up storage'));
    await tester.pumpAndSettle();
    expect(find.textContaining('submersion-sites/reef/'), findsWidgets);
  });

  testWidgets("the storage guide names the account's own bucket", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _connectApp([
        ...await getBaseOverrides(),
        libraryAccountSetupProvider.overrideWithValue(
          _BucketSetup('reef-bucket'),
        ),
      ], () => [_bucket()]),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), 'reef');
    await tester.tap(find.text('How to set up storage'));
    await tester.pumpAndSettle();
    // The account is labelled 'Bucket'; its stored bucket is reef-bucket.
    expect(find.textContaining('arn:aws:s3:::reef-bucket'), findsWidgets);
    expect(find.textContaining('arn:aws:s3:::Bucket'), findsNothing);
  });

  testWidgets('a folder with policy wildcards is refused', (tester) async {
    await tester.pumpWidget(
      _connectApp(await getBaseOverrides(), () => [_bucket()]),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), 'reef*');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(
      find.text('A library folder cannot contain *, ? or dollar signs.'),
      findsOneWidget,
    );
    expect(find.text('Create library'), findsNothing);
  });

  testWidgets('the folder field sits above the account picker', (tester) async {
    await tester.pumpWidget(
      _connectApp(await getBaseOverrides(), () => [_bucket()]),
    );
    await tester.pumpAndSettle();
    final folderY = tester
        .getTopLeft(find.byKey(const Key('library-prefix')))
        .dy;
    final pickerY = tester
        .getTopLeft(find.byType(DropdownButtonFormField<ConnectedAccount>))
        .dy;
    expect(folderY, lessThan(pickerY));
  });

  testWidgets('a folder named after a library subfolder is refused', (
    tester,
  ) async {
    await tester.pumpWidget(
      _connectApp(await getBaseOverrides(), () => [_bucket()]),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), 'sites');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'A library folder cannot start with sites, members, suggestions or backups.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a folder leading out of submersion-sites is refused', (
    tester,
  ) async {
    await tester.pumpWidget(
      _connectApp(await getBaseOverrides(), () => [_bucket()]),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('library-prefix')),
      '../submersion-sync',
    );
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(
      find.text('Folder names cannot contain . or .. segments'),
      findsOneWidget,
    );
    expect(find.text('No library here yet.'), findsNothing);
  });
}

/// An account whose stored S3 settings name [bucket] (its label does not),
/// or none, without reaching the device's secure storage.
class _BucketSetup extends LibraryAccountSetup {
  _BucketSetup([this.bucket]);

  final String? bucket;

  @override
  Future<String?> s3Bucket(String accountId) async => bucket;
}

class _RecordingSetup extends LibraryAccountSetup {
  _RecordingSetup({required this.onSave});

  final void Function(ConnectedAccount) onSave;
  final s3 = <S3Config>[];
  final webdav = <WebDavConfig>[];

  /// The next server reached presents a certificate nobody trusted yet.
  bool untrustedOnce = false;

  /// Thrown by the next save instead of saving.
  Object? saveError;

  ConnectedAccount _saved(AccountKind kind, String label) {
    final error = saveError;
    if (error != null) throw error;
    final account = ConnectedAccount(
      id: 'new',
      kind: kind,
      label: label,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    onSave(account);
    return account;
  }

  /// The library folder each save was made for.
  final folders = <String>[];

  @override
  Future<ConnectedAccount> saveS3(
    S3Config server, {
    required String folder,
  }) async {
    folders.add(folder);
    final account = _saved(
      AccountKind.s3,
      '${server.bucket} @ ${server.displayHost}',
    );
    s3.add(server);
    return account;
  }

  @override
  Future<WebDavConfig> reachWebDav(WebDavConfig server) async {
    if (untrustedOnce) {
      untrustedOnce = false;
      throw WebDavUntrustedCertificateException(
        WebDavCertificateDetails(
          host: 'nas.local',
          port: 5006,
          sha256: 'ab' * 32,
          subject: 'CN=nas',
          issuer: 'CN=nas',
          startValidity: DateTime.utc(2026),
          endValidity: DateTime.utc(2027),
        ),
      );
    }
    return server;
  }

  @override
  Future<ConnectedAccount> saveWebDav(
    WebDavConfig server, {
    required String folder,
  }) async {
    folders.add(folder);
    final account = _saved(AccountKind.webdav, server.displayLabel);
    webdav.add(server);
    return account;
  }
}
