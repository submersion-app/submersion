import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_location_fields.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/pages/connect_shared_library_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/account_groups_fixture.dart';
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
  }) async => prefix == 'boom'
      ? throw const CloudStorageException('probe failed')
      : probes[prefix] ?? const LibraryProbe(exists: false);

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
    accountGroupsProvider.overrideWith(
      (ref) async => signedInGroupsOf(accounts()),
    ),
    accountGroupsOfKindsProvider(
      libraryKindsKey,
    ).overrideWith((ref) async => signedInGroupsOf(accounts())),
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

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

ConnectedAccount _bucket({AccountLocation? location}) => ConnectedAccount(
  id: 'a',
  kind: AccountKind.s3,
  label: 'Bucket',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  location: location,
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
          accountGroupsProvider.overrideWith(
            (ref) async => signedInGroupsOf(accounts),
          ),
          accountGroupsOfKindsProvider(
            libraryKindsKey,
          ).overrideWith((ref) async => signedInGroupsOf(accounts)),
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
    expect(find.text('Using: Bucket'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('library-prefix')),
      'site-sync',
    );
    await tester.tap(find.text('Check location'));
    await tester.pumpAndSettle();
    expect(find.text('Join Reef Survey'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget, reason: 'display name prefilled');

    await tester.enterText(find.byKey(const Key('library-prefix')), 'other');
    await tester.tap(find.text('Check location'));
    await tester.pumpAndSettle();
    expect(find.text('No library here yet.'), findsOneWidget);
    expect(find.text('Create library'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('library-prefix')), 'old');
    await tester.tap(find.text('Check location'));
    await tester.pumpAndSettle();
    expect(
      find.text('This library needs a newer version of Submersion.'),
      findsOneWidget,
    );
  });

  testWidgets('the join preview shows the library description', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          accountGroupsProvider.overrideWith(
            (ref) async => signedInGroupsOf([_bucket()]),
          ),
          accountGroupsOfKindsProvider(
            libraryKindsKey,
          ).overrideWith((ref) async => signedInGroupsOf([_bucket()])),
          sharedLibraryMembershipServiceProvider.overrideWithValue(
            _FakeMembershipService(const {
              'site-sync': LibraryProbe(
                exists: true,
                id: 'L',
                name: 'Reef Survey',
                description: 'Sites our group dives',
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
    await tester.enterText(
      find.byKey(const Key('library-prefix')),
      'site-sync',
    );
    await tester.tap(find.text('Check location'));
    await tester.pumpAndSettle();
    expect(find.text('Sites our group dives'), findsOneWidget);
  });

  testWidgets('editing the location clears an earlier error', (tester) async {
    await tester.pumpWidget(
      _connectApp(await getBaseOverrides(), () => [_bucket()]),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), 'boom');
    await tester.tap(find.text('Check location'));
    await tester.pumpAndSettle();
    expect(find.textContaining('probe failed'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('library-prefix')), 'reef');
    await tester.pumpAndSettle();
    expect(find.textContaining('probe failed'), findsNothing);
  });

  testWidgets('without an eligible account the hint shows', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          accountGroupsProvider.overrideWith(
            (ref) async => signedInGroupsOf(const []),
          ),
          accountGroupsOfKindsProvider(
            libraryKindsKey,
          ).overrideWith((ref) async => signedInGroupsOf(const [])),
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
    await tester.tap(find.text('Check location'));
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
    container.invalidate(accountGroupsProvider);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Using: Bucket'), findsOneWidget);
  });

  // Issue #3482: a library's server is picked through the account sheet,
  // restricted to S3 and WebDAV, in place of the inline account form.
  testWidgets('with no account yet, Add account offers my own server only', (
    tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(_connectApp(await getBaseOverrides(), () => []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    expect(find.text('Add an account'), findsOneWidget);
    expect(find.text('My own server'), findsOneWidget);
    expect(find.text('Google Drive'), findsNothing);
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
          accountGroupsProvider.overrideWith(
            (ref) async => signedInGroupsOf([_bucket()]),
          ),
          accountGroupsOfKindsProvider(
            libraryKindsKey,
          ).overrideWith((ref) async => signedInGroupsOf([_bucket()])),
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
    await tester.tap(find.text('Check location'));
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
          accountGroupsProvider.overrideWith(
            (ref) async => signedInGroupsOf([_bucket()]),
          ),
          accountGroupsOfKindsProvider(
            libraryKindsKey,
          ).overrideWith((ref) async => signedInGroupsOf([_bucket()])),
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
    await tester.tap(find.text('Check location'));
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
          accountGroupsProvider.overrideWith(
            (ref) async => signedInGroupsOf([_bucket()]),
          ),
          accountGroupsOfKindsProvider(
            libraryKindsKey,
          ).overrideWith((ref) async => signedInGroupsOf([_bucket()])),
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
    await tester.tap(find.text('Check location'));
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
      _connectApp(await getBaseOverrides(), () => [_bucket()]),
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
    // The account's location names its bucket (the accounts list adds this
    // device's stored settings as a location for a row that has none).
    await tester.pumpWidget(
      _connectApp(
        await getBaseOverrides(),
        () => [
          _bucket(
            location: const S3AccountLocation(
              displayHost: 'minio.home',
              endpoint: 'https://minio.home',
              bucket: 'reef-bucket',
              region: 'us-east-1',
              prefix: 'submersion-sync/',
              pathStyle: true,
            ),
          ),
        ],
      ),
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
    await tester.tap(find.text('Check location'));
    await tester.pumpAndSettle();
    expect(
      find.text('A library folder cannot contain *, ? or dollar signs.'),
      findsOneWidget,
    );
    expect(find.text('Create library'), findsNothing);
  });

  testWidgets('the folder field sits above the server', (tester) async {
    await tester.pumpWidget(
      _connectApp(await getBaseOverrides(), () => [_bucket()]),
    );
    await tester.pumpAndSettle();
    final folderY = tester
        .getTopLeft(find.byKey(const Key('library-prefix')))
        .dy;
    final pickerY = tester
        .getTopLeft(find.byKey(const Key('library-server')))
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
    await tester.tap(find.text('Check location'));
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
    await tester.tap(find.text('Check location'));
    await tester.pumpAndSettle();

    expect(
      find.text('Folder names cannot contain . or .. segments'),
      findsOneWidget,
    );
    expect(find.text('No library here yet.'), findsNothing);
  });
}
