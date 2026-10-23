import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/member_removal.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/library_encryption_service.dart';
import 'package:submersion/core/services/shared_library/library_sync_error.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_site_publisher.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/pages/shared_library_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/shared_library_test_account.dart';

Future<Widget> _page(
  SharedLibraryRole role, {
  bool readOnly = false,
  bool rolesRejected = false,
  SharedLibraryRoles? pendingRoles,
  String? keyId,
  String? memberKeyId,
  String? error,
  SharedLibraryMembershipService? service,
  SharedSitePublisher? publisher,
  LibraryEncryptionService? encryption,
  LibrarySigningKey? signingKey,
  int held = 0,
  bool fakeSync = false,
  bool inShell = false,
  List<MemberRemoval> removed = const [],
  Locale locale = const Locale('en'),
}) async => (inShell ? testAppInShell : testApp)(
  overrides: [
    ...await getBaseOverrides(),
    if (service != null)
      sharedLibraryMembershipServiceProvider.overrideWithValue(service),
    if (publisher != null)
      sharedSitePublisherProvider.overrideWithValue(publisher),
    if (encryption != null)
      libraryEncryptionServiceProvider.overrideWithValue(encryption),
    validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
    sharedLibrariesProvider.overrideWith(
      (ref) => Stream.value([
        SharedLibrary(
          id: 'L',
          name: 'Reef Survey',
          connectedAccountId: 'a',
          prefix: 'site-sync',
          readOnlyDetected: readOnly,
          rolesRejected: rolesRejected,
          pendingRoles: pendingRoles,
          encrypted: keyId != null,
          keyId: keyId,
          lastError: error,
          roles: SharedLibraryRoles(
            owners: role == SharedLibraryRole.owner ? {'m'} : {},
            editors: role == SharedLibraryRole.editor ? {'m'} : {},
          ),
        ),
      ]),
    ),
    currentMembershipsProvider.overrideWith(
      (ref) async => [
        SharedLibraryMembership(
          id: 'ms',
          diverId: 'd',
          libraryId: 'L',
          memberId: 'm',
          displayName: 'Ann',
          libraryName: 'Reef Survey',
          backendKind: 's3',
          libraryKeyId: memberKeyId,
          libraryKey: memberKeyId == null ? null : 'key',
          signingKey: signingKey,
        ),
      ],
    ),
    libraryRoleProvider('L').overrideWith(
      (ref) async => effectiveRole(listed: role, readOnlyDetected: readOnly),
    ),
    libraryMemberNamesProvider('L').overrideWith((ref) async => {'m': 'Ann'}),
    pendingIncomingSuggestionCountProvider('L').overrideWith((ref) async => 2),
    heldIncomingSuggestionCountProvider('L').overrideWith((ref) async => held),
    libraryRemovalsProvider('L').overrideWith((ref) async => removed),
    if (fakeSync) sharedLibrarySyncProvider.overrideWith(_RecordingSync.new),
    sitesProvider.overrideWith(
      (ref) async => const [
        DiveSite(id: 'p1', name: 'Reef'),
        DiveSite(id: 'p2', name: 'Wreck'),
        DiveSite(id: 'l1', name: 'Reef wall', sharedLibraryId: 'L'),
      ],
    ),
  ],
  locale: locale,
  child: const SharedLibraryPage(libraryId: 'L'),
);

void main() {
  group('a removed member (issue #3481)', () {
    MemberRemoval removal(String memberId) => MemberRemoval(
      memberId: memberId,
      displayName: 'Ann',
      removedAt: DateTime.utc(2026, 10, 18),
      removedBy: 'o',
    );

    testWidgets('sees the removal notice', (tester) async {
      await tester.pumpWidget(
        await _page(SharedLibraryRole.reader, removed: [removal('m')]),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('An owner removed you from this library'),
        findsOneWidget,
      );
    });

    testWidgets("someone else's removal shows nothing", (tester) async {
      await tester.pumpWidget(
        await _page(SharedLibraryRole.owner, removed: [removal('x')]),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('An owner removed you from this library'),
        findsNothing,
      );
    });
  });

  testWidgets(
    'an owner sees Members, Suggestions with a badge, Add my sites, Leave',
    (tester) async {
      await tester.pumpWidget(await _page(SharedLibraryRole.owner));
      await tester.pumpAndSettle();
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Suggestions'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Add my sites'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Leave library'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Leave library'), findsOneWidget);
    },
  );

  for (final role in SharedLibraryRole.values) {
    testWidgets('Backups is offered to owners only (${role.name})', (
      tester,
    ) async {
      await tester.pumpWidget(await _page(role));
      await tester.pumpAndSettle();
      final backups = find.text('Back up the library and restore it');
      if (role == SharedLibraryRole.owner) {
        await tester.scrollUntilVisible(
          backups,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(backups, findsOneWidget);
      } else {
        expect(backups, findsNothing);
      }
    });
  }

  testWidgets('an owner is told of suggestions held for approval', (
    tester,
  ) async {
    await tester.pumpWidget(await _page(SharedLibraryRole.owner, held: 1));
    await tester.pumpAndSettle();
    expect(
      find.text('1 suggestion waits until you approve its author'),
      findsOneWidget,
    );
  });

  testWidgets('a member sees their own key to compare with an owner', (
    tester,
  ) async {
    final key = LibrarySigningKey(
      publicKey: base64Encode(List.filled(32, 7)),
      privateKey: base64Encode(List.filled(32, 8)),
    );
    await tester.pumpWidget(
      await _page(SharedLibraryRole.reader, signingKey: key),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Your key ${LibrarySigner.fingerprint(key.publicKey)}'),
      findsOneWidget,
    );
  });

  testWidgets('a reader sees neither Add my sites nor Suggestions', (
    tester,
  ) async {
    await tester.pumpWidget(await _page(SharedLibraryRole.reader));
    await tester.pumpAndSettle();
    expect(find.text('Add my sites'), findsNothing);
    expect(find.text('Suggestions'), findsNothing);
    expect(find.text('Reader'), findsOneWidget);
  });

  testWidgets('read-only and error banners', (tester) async {
    await tester.pumpWidget(
      await _page(SharedLibraryRole.editor, readOnly: true, error: 'boom'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('allow reading only'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });

  // Issue #3563: the row stores a code, and the banner says it in the
  // reader's language.
  group('a stored sync failure', () {
    Future<void> show(
      WidgetTester tester,
      LibrarySyncError error, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        await _page(
          SharedLibraryRole.owner,
          error: error.encode(),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a missing account reads in French on a French phone', (
      tester,
    ) async {
      await show(
        tester,
        const LibrarySyncError(LibrarySyncErrorCode.accountMissing),
        locale: const Locale('fr'),
      );
      expect(
        find.textContaining(
          'La dernière synchronisation a échoué : '
          "Le compte de cette bibliothèque n'est plus sur cet appareil.",
        ),
        findsOneWidget,
      );
      expect(find.textContaining('no longer on this device'), findsNothing);
      expect(find.textContaining('accountMissing'), findsNothing);
    });

    testWidgets('a storage message shows as the storage gave it', (
      tester,
    ) async {
      await show(
        tester,
        const LibrarySyncError(
          LibrarySyncErrorCode.failed,
          detail: 'HTTP 403 Forbidden',
        ),
      );
      expect(
        find.textContaining('Last sync failed: HTTP 403 Forbidden'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a refused roles file is flagged', (tester) async {
    await tester.pumpWidget(
      await _page(SharedLibraryRole.reader, rolesRejected: true),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('changed by someone who is not an owner'),
      findsOneWidget,
    );
  });

  testWidgets('an encrypted library without its key asks to be unlocked', (
    tester,
  ) async {
    final service = _OwnerLoss();
    await tester.pumpWidget(
      await _page(
        SharedLibraryRole.reader,
        service: service,
        keyId: 'k2',
        fakeSync: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Enter the passphrase for Reef Survey.'), findsOneWidget);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('secret-field')), 'pw');
    await tester.tap(find.text('Unlock').last);
    await tester.pumpAndSettle();
    expect(service.secrets, ['pw']);
    // Its sites come in at once, not at the next sync.
    expect(_RecordingSync.synced, ['L']);
  });

  testWidgets('an owner turns encryption on and sees the new code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final encryption = _RecordingEncryption();
    await tester.pumpWidget(
      await _page(SharedLibraryRole.owner, encryption: encryption),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Turn on encryption'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Turn on encryption'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('passphrase-field')), 'short');
    await tester.enterText(
      find.byKey(const Key('passphrase-confirm')),
      'short',
    );
    await tester.tap(find.text('Turn on encryption').last);
    await tester.pumpAndSettle();
    expect(encryption.calls, isEmpty);
    await tester.enterText(
      find.byKey(const Key('passphrase-field')),
      'long enough phrase',
    );
    await tester.enterText(
      find.byKey(const Key('passphrase-confirm')),
      'long enough phrase',
    );
    await tester.tap(find.text('Turn on encryption').last);
    await tester.pumpAndSettle();
    expect(encryption.calls, ['on:long enough phrase']);
    expect(find.text('new-recovery-code'), findsOneWidget);
  });

  testWidgets('in the app shell the progress closes and the page stays open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      await _page(
        SharedLibraryRole.owner,
        encryption: _RecordingEncryption(),
        inShell: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Turn on encryption'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Turn on encryption'));
    await tester.pumpAndSettle();
    for (final key in ['passphrase-field', 'passphrase-confirm']) {
      await tester.enterText(find.byKey(Key(key)), 'long enough phrase');
    }
    await tester.tap(find.text('Turn on encryption').last);
    await tester.pumpAndSettle();
    expect(find.text('new-recovery-code'), findsOneWidget);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Reef Survey'), findsWidgets);
    expect(find.text('Members'), findsOneWidget);
  });

  testWidgets('a turn-on cut short still shows its recovery code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final encryption = _RecordingEncryption(cutShort: true);
    await tester.pumpWidget(
      await _page(SharedLibraryRole.owner, encryption: encryption),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Turn on encryption'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Turn on encryption'));
    await tester.pumpAndSettle();
    for (final key in ['passphrase-field', 'passphrase-confirm']) {
      await tester.enterText(find.byKey(Key(key)), 'long enough phrase');
    }
    await tester.tap(find.text('Turn on encryption').last);
    await tester.pumpAndSettle();
    expect(find.text('new-recovery-code'), findsOneWidget);
  });

  testWidgets('an encrypted library offers a new passphrase and turning off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final encryption = _RecordingEncryption();
    await tester.pumpWidget(
      await _page(
        SharedLibraryRole.owner,
        encryption: encryption,
        keyId: 'k',
        memberKeyId: 'k',
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Turn off encryption'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Change passphrase'), findsOneWidget);
    await tester.tap(find.text('Turn off encryption'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn off encryption').last);
    await tester.pumpAndSettle();
    expect(encryption.calls, ['off']);
  });

  testWidgets('a reader sees the state but no encryption actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _page(SharedLibraryRole.reader, keyId: 'k', memberKeyId: 'k'),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Encrypted with a passphrase'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Turn off encryption'), findsNothing);
  });

  testWidgets('a lone owner is warned', (tester) async {
    await tester.pumpWidget(await _page(SharedLibraryRole.owner));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Only one owner'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Only one owner'), findsOneWidget);
  });

  testWidgets('an editor gets no owner warning', (tester) async {
    await tester.pumpWidget(await _page(SharedLibraryRole.editor));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Leave library'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Only one owner'), findsNothing);
  });

  testWidgets('a pending ownership reset asks to be accepted', (tester) async {
    final service = _OwnerLoss();
    final key = base64Encode(List.filled(32, 9));
    await tester.pumpWidget(
      await _page(
        SharedLibraryRole.reader,
        service: service,
        pendingRoles: SharedLibraryRoles(
          version: 3,
          owners: const {'m'},
          approvedKeys: {'m': key},
          reset: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('was reset by Ann'), findsOneWidget);
    expect(find.textContaining(LibrarySigner.fingerprint(key)), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(service.accepted, ['L']);
  });

  testWidgets('a wrong recovery code says so', (tester) async {
    final service = _OwnerLoss();
    await tester.pumpWidget(
      await _page(SharedLibraryRole.reader, service: service),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Recover ownership'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Recover ownership'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'wrong-code');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(service.codes, ['wrong-code']);
    expect(
      find.text("That is not this library's recovery code."),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the rename dialog keeps the name', (tester) async {
    await tester.pumpWidget(await _page(SharedLibraryRole.owner));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Ann'), findsOneWidget);
  });

  testWidgets('cancelling the leave dialog stays on the page', (tester) async {
    await tester.pumpWidget(await _page(SharedLibraryRole.owner));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Leave library'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Leave library'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reef Survey'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Leave library'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Leave library'), findsOneWidget);
  });

  testWidgets('Add my sites lists only personal sites and enables the button '
      'once one is ticked', (tester) async {
    await tester.pumpWidget(await _page(SharedLibraryRole.editor));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add my sites'));
    await tester.pumpAndSettle();
    expect(find.text('Reef'), findsOneWidget);
    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('Reef wall'), findsNothing);
    final button = find.widgetWithText(
      FilledButton,
      'Add to shared site library',
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.text('Reef'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(find.text('Reef'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    // Dismiss without confirming: nothing is pushed.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Reef'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a rename the storage refuses says so', (tester) async {
    await tester.pumpWidget(
      await _page(SharedLibraryRole.owner, service: _OfflineRename()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Annie');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Network unreachable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a push the service refuses says so', (tester) async {
    await tester.pumpWidget(
      await _page(SharedLibraryRole.editor, publisher: _RefusingPublisher()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add my sites'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reef'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Add to shared site library'),
    );
    await tester.pumpAndSettle();
    // What is shared is confirmed first.
    expect(find.text('Add Reef to Reef Survey?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

/// Records syncs instead of reaching storage.
class _RecordingSync extends SharedLibrarySyncNotifier {
  _RecordingSync(super.ref) {
    synced.clear();
  }

  static final synced = <String>[];

  @override
  Future<SharedLibrarySyncResult> syncOne(String libraryId) async {
    synced.add(libraryId);
    return const SharedLibrarySyncResult(
      status: SharedLibrarySyncStatus.success,
    );
  }
}

class _OfflineRename extends SharedLibraryMembershipService {
  _OfflineRename()
    : super(
        store: SharedLibraryStore(),
        transportFor: ({required account, required prefix}) =>
            throw UnimplementedError(),
      );

  @override
  Future<void> rename({
    required String libraryId,
    required String diverId,
    required String displayName,
  }) async => throw const CloudStorageException('Network unreachable');
}

class _RefusingPublisher extends SharedSitePublisher {
  @override
  Future<void> push({
    required String siteId,
    required String libraryId,
    required String diverId,
  }) async => throw StateError('a reader cannot add sites');
}

/// Records owner-loss actions; every recovery code is wrong.
class _OwnerLoss extends SharedLibraryMembershipService {
  _OwnerLoss()
    : super(
        store: SharedLibraryStore(),
        transportFor: ({required account, required prefix}) =>
            throw UnimplementedError(),
      );

  final accepted = <String>[];
  final codes = <String>[];
  final secrets = <String>[];

  @override
  Future<void> unlockLibrary({
    required String libraryId,
    required String diverId,
    required String secret,
  }) async => secrets.add(secret);

  @override
  Future<void> acceptReset(String libraryId) async => accepted.add(libraryId);

  @override
  Future<void> recoverOwnership({
    required String libraryId,
    required String diverId,
    required String code,
  }) async {
    codes.add(code);
    throw WrongRecoveryCodeError();
  }
}

/// Records encryption actions instead of rewriting storage.
class _RecordingEncryption extends LibraryEncryptionService {
  _RecordingEncryption({this.cutShort = false})
    : super(
        store: SharedLibraryStore(),
        memberships: SharedLibraryMembershipService(
          accountById: anyTestAccount,
          store: SharedLibraryStore(),
          transportFor: ({required account, required prefix}) =>
              throw UnimplementedError(),
        ),
      );

  final calls = <String>[];

  /// Stops after the new keys are written, as a lost connection would.
  final bool cutShort;

  @override
  Future<String> turnOn({
    required String libraryId,
    required String diverId,
    required String passphrase,
    RewriteProgress? progress,
  }) async {
    calls.add('on:$passphrase');
    if (cutShort) {
      throw RekeyIncompleteError('new-recovery-code', StateError('lost'));
    }
    return 'new-recovery-code';
  }

  @override
  Future<void> turnOff({
    required String libraryId,
    required String diverId,
    RewriteProgress? progress,
  }) async => calls.add('off');
}
