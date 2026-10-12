import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
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

  @override
  Future<SharedLibrary> create({
    required ConnectedAccount account,
    required String prefix,
    required String name,
    required String diverId,
    required String displayName,
  }) async => throw LibraryExistsError(prefix);
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
      'club': const LibraryProbe(exists: true, id: 'L', name: 'Club'),
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

    await tester.enterText(find.byKey(const Key('library-prefix')), 'club');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('Join Club'), findsOneWidget);
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
    await tester.enterText(find.byKey(const Key('library-prefix')), 'club');
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
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final accounts = <ConnectedAccount>[];
    final setup = _RecordingSetup(onSave: accounts.add);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          eligibleLibraryAccountsProvider.overrideWith(
            (ref) async => List.of(accounts),
          ),
          libraryAccountSetupProvider.overrideWithValue(setup),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
          currentDiverProvider.overrideWith((ref) async => null),
        ],
        locale: const Locale('en'),
        child: const ConnectSharedLibraryPage(),
      ),
    );
    await tester.pumpAndSettle();

    // No account yet: set one up here instead of leaving for Settings.
    await tester.tap(find.text('Add storage account'));
    await tester.pumpAndSettle();
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
    expect(find.byKey(const Key('library-s3-prefix')), findsNothing);
    await tester.tap(find.text('Save account'));
    await tester.pumpAndSettle();

    expect(setup.s3.single.bucket, 'submersion-sync');
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
}

class _RecordingSetup extends LibraryAccountSetup {
  _RecordingSetup({required this.onSave});

  final void Function(ConnectedAccount) onSave;
  final s3 = <S3Config>[];

  @override
  Future<ConnectedAccount> saveS3(S3Config server) async {
    s3.add(server);
    final account = ConnectedAccount(
      id: 'new',
      kind: AccountKind.s3,
      label: '${server.bucket} @ ${server.displayHost}',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    onSave(account);
    return account;
  }

  @override
  Future<ConnectedAccount> saveWebDav(WebDavConfig server) async =>
      throw UnimplementedError();
}
