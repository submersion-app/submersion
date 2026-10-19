import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_location_fields.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/library_connection_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/pages/change_library_connection_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/library_connection_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/account_groups_fixture.dart';

final _accounts = [
  for (final (id, label) in [('a', 'Old bucket'), ('b', 'New bucket')])
    ConnectedAccount(
      id: id,
      kind: AccountKind.s3,
      label: label,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
];

class _FakeConnection implements LibraryConnectionService {
  LibraryLocationCheck next = const LibraryLocationCheck(
    LibraryLocationVerdict.same,
    foundName: 'Reef Survey',
  );
  LibraryLocationCheck? unlocked;
  LibraryLocationCheck? rejectWith;
  final checks = <({String account, String prefix, String? secret})>[];
  final repoints = <({String prefix, bool acceptOlder, String? secret})>[];

  /// When set, a check waits for it.
  Completer<void>? hold;

  /// When set, a check or a save throws it.
  Object? failWith;

  @override
  Future<LibraryLocationCheck> check({
    required String libraryId,
    required String diverId,
    required ConnectedAccount account,
    required String prefix,
    String? secret,
  }) async {
    checks.add((account: account.id, prefix: prefix, secret: secret));
    await hold?.future;
    if (failWith != null) throw failWith!;
    return secret != null && unlocked != null ? unlocked! : next;
  }

  @override
  Future<SharedLibrary> repoint({
    required String libraryId,
    required String diverId,
    required ConnectedAccount account,
    required String prefix,
    String? secret,
    bool acceptOlder = false,
  }) async {
    if (rejectWith != null) throw LibraryLocationRejected(rejectWith!);
    if (failWith != null) throw failWith!;
    repoints.add((prefix: prefix, acceptOlder: acceptOlder, secret: secret));
    return SharedLibrary(
      id: 'L',
      name: 'Reef Survey',
      connectedAccountId: account.id,
      prefix: prefix,
    );
  }
}

class _RecordingSync extends SharedLibrarySyncNotifier {
  _RecordingSync(super.ref);

  static final synced = <String>[];

  @override
  Future<SharedLibrarySyncResult> syncOne(String libraryId) async {
    synced.add(libraryId);
    return const SharedLibrarySyncResult(
      status: SharedLibrarySyncStatus.success,
    );
  }
}

Widget _app(
  _FakeConnection service, {
  String accountId = 'a',
  bool connected = true,
  List<ConnectedAccount>? accounts,
}) => testAppRouter(
  router: GoRouter(
    initialLocation: '/change',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('library page')),
        routes: [
          GoRoute(
            path: 'change',
            builder: (_, _) =>
                const ChangeLibraryConnectionPage(libraryId: 'L'),
          ),
        ],
      ),
    ],
  ),
  overrides: [
    validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
    sharedLibrariesProvider.overrideWith(
      (ref) => Stream.value([
        if (connected)
          SharedLibrary(
            id: 'L',
            name: 'Reef Survey',
            connectedAccountId: accountId,
            prefix: 'site-sync',
          ),
      ]),
    ),
    accountGroupsProvider.overrideWith(
      (ref) async => signedInGroupsOf(accounts ?? _accounts),
    ),
    accountGroupsOfKindsProvider(
      libraryKindsKey,
    ).overrideWith((ref) async => signedInGroupsOf(accounts ?? _accounts)),
    libraryConnectionServiceProvider.overrideWithValue(service),
    sharedLibrarySyncProvider.overrideWith(_RecordingSync.new),
  ],
  locale: const Locale('en'),
);

Future<void> _check(WidgetTester tester) async {
  await tester.tap(find.text('Check location'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(_RecordingSync.synced.clear);

  testWidgets('starts at the current account and folder', (tester) async {
    final service = _FakeConnection();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.text('Using: Old bucket'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('library-prefix')))
          .controller!
          .text,
      'site-sync',
    );
    await _check(tester);
    expect(service.checks.single.account, 'a');
    expect(service.checks.single.prefix, 'site-sync');
  });

  testWidgets('a long account label fits a phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _accounts[0] = _accounts[0].copyWith(
      label:
          'group-sites @ s3.us-west-2.amazonaws.com (submersion-sites/puget-sound)',
    );
    addTearDown(
      () => _accounts[0] = _accounts[0].copyWith(label: 'Old bucket'),
    );
    await tester.pumpWidget(_app(_FakeConnection()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a library no longer connected says so', (tester) async {
    await tester.pumpWidget(_app(_FakeConnection(), connected: false));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No shared site library connected yet.'), findsOneWidget);
  });

  testWidgets('a stored account no longer on the device is named', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeConnection(), accountId: 'gone'));
    await tester.pumpAndSettle();
    expect(
      find.text('This account is no longer on this device'),
      findsOneWidget,
    );
  });

  testWidgets('the same library saves, syncs and returns', (tester) async {
    final service = _FakeConnection();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), 'moved');
    await _check(tester);
    expect(
      find.text('Found Reef Survey here. This is the same library.'),
      findsOneWidget,
    );
    expect(find.text('Save anyway'), findsNothing);
    await tester.tap(find.text('Save connection'));
    await tester.pumpAndSettle();
    expect(service.repoints.single.prefix, 'moved');
    expect(service.repoints.single.acceptOlder, isFalse);
    expect(_RecordingSync.synced, ['L']);
    expect(find.text('library page'), findsOneWidget);
  });

  testWidgets('a double tap saves once', (tester) async {
    final service = _FakeConnection();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _check(tester);
    await tester.tap(find.text('Save connection'));
    await tester.tap(find.text('Save connection'));
    await tester.pumpAndSettle();
    expect(service.repoints, hasLength(1));
    expect(_RecordingSync.synced, ['L']);
  });

  testWidgets('an older copy offers Save anyway', (tester) async {
    final service = _FakeConnection()
      ..next = const LibraryLocationCheck(
        LibraryLocationVerdict.olderCopy,
        foundName: 'Reef Survey',
      );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _check(tester);
    expect(
      find.text(
        'This copy looks older than the one you have been syncing with.',
      ),
      findsOneWidget,
    );
    expect(find.text('Save connection'), findsNothing);
    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();
    expect(service.repoints.single.acceptOlder, isTrue);
  });

  for (final (verdict, message) in [
    (
      const LibraryLocationCheck(
        LibraryLocationVerdict.differentLibrary,
        foundName: 'Other Group',
      ),
      'This folder holds a different library (Other Group). Your connection is unchanged.',
    ),
    (
      const LibraryLocationCheck(LibraryLocationVerdict.differentLibrary),
      'This folder holds a different library. Your connection is unchanged.',
    ),
    (
      const LibraryLocationCheck(LibraryLocationVerdict.noLibrary),
      'No library found in this folder. Your connection is unchanged.',
    ),
  ]) {
    testWidgets('${verdict.verdict.name} cannot be saved', (tester) async {
      final service = _FakeConnection()..next = verdict;
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await _check(tester);
      expect(find.text(message), findsOneWidget);
      expect(find.text('Save connection'), findsNothing);
      expect(find.text('Save anyway'), findsNothing);
    });
  }

  for (final (verdict, message) in [
    (
      LibraryLocationVerdict.retired,
      'This library was made by a test build of Submersion. Create it again.',
    ),
    (
      LibraryLocationVerdict.needsNewerApp,
      'This library needs a newer version of Submersion.',
    ),
  ]) {
    testWidgets('${verdict.name} is explained', (tester) async {
      final service = _FakeConnection()..next = LibraryLocationCheck(verdict);
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await _check(tester);
      expect(find.text(message), findsOneWidget);
      expect(find.text('Save connection'), findsNothing);
    });
  }

  testWidgets('a folder that leaves the library space is refused', (
    tester,
  ) async {
    final service = _FakeConnection();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), '../x');
    await _check(tester);
    expect(service.checks, isEmpty);
    expect(find.text('Save connection'), findsNothing);
  });

  testWidgets('a failed check and a failed save say why', (tester) async {
    final service = _FakeConnection()
      ..failWith = const CloudStorageException('storage unreachable');
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _check(tester);
    expect(find.text('storage unreachable'), findsOneWidget);

    service.failWith = null;
    await _check(tester);
    service.failWith = const CloudStorageException('upload refused');
    await tester.tap(find.text('Save connection'));
    await tester.pumpAndSettle();
    expect(find.text('upload refused'), findsOneWidget);
    expect(find.text('library page'), findsNothing);
    expect(_RecordingSync.synced, isEmpty);
  });

  testWidgets('with no account yet one can be added here', (tester) async {
    await tester.pumpWidget(_app(_FakeConnection(), accounts: const []));
    await tester.pumpAndSettle();
    expect(find.text('Check location'), findsNothing);
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    expect(find.text('My own server'), findsOneWidget);
  });

  testWidgets('a locked copy asks for the passphrase', (tester) async {
    final service = _FakeConnection()
      ..next = const LibraryLocationCheck(LibraryLocationVerdict.locked)
      ..unlocked = const LibraryLocationCheck(
        LibraryLocationVerdict.same,
        foundName: 'Reef Survey',
      );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _check(tester);
    await tester.enterText(find.byKey(const Key('library-secret')), 'pw');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(service.checks.last.secret, 'pw');
    await tester.tap(find.text('Save connection'));
    await tester.pumpAndSettle();
    expect(service.repoints.single.secret, 'pw');
  });

  testWidgets('the location cannot change while a check runs', (tester) async {
    final service = _FakeConnection()..hold = Completer<void>();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check location'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('library-prefix'))).enabled,
      isFalse,
    );
    service.hold!.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('library-prefix'))).enabled,
      isTrue,
    );
  });

  testWidgets('editing the folder clears the result', (tester) async {
    final service = _FakeConnection();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _check(tester);
    expect(find.text('Save connection'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('library-prefix')), 'x');
    await tester.pumpAndSettle();
    expect(find.text('Save connection'), findsNothing);
  });

  testWidgets('a save the re-check refuses shows why and stays', (
    tester,
  ) async {
    final service = _FakeConnection()
      ..rejectWith = const LibraryLocationCheck(
        LibraryLocationVerdict.noLibrary,
      );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _check(tester);
    await tester.tap(find.text('Save connection'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No library found in this folder. Your connection is unchanged.',
      ),
      findsOneWidget,
    );
    expect(find.text('library page'), findsNothing);
    expect(_RecordingSync.synced, isEmpty);
  });
}
