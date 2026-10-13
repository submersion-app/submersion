import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_site_publisher.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/pages/shared_library_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

Future<Widget> _page(
  SharedLibraryRole role, {
  bool readOnly = false,
  bool rolesRejected = false,
  SharedLibraryRoles? pendingRoles,
  String? keyId,
  String? error,
  SharedLibraryMembershipService? service,
  SharedSitePublisher? publisher,
}) async => testApp(
  overrides: [
    ...await getBaseOverrides(),
    if (service != null)
      sharedLibraryMembershipServiceProvider.overrideWithValue(service),
    if (publisher != null)
      sharedSitePublisherProvider.overrideWithValue(publisher),
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
      (ref) async => const [
        SharedLibraryMembership(
          id: 'ms',
          diverId: 'd',
          libraryId: 'L',
          memberId: 'm',
          displayName: 'Ann',
          libraryName: 'Reef Survey',
          backendKind: 's3',
        ),
      ],
    ),
    libraryRoleProvider('L').overrideWith(
      (ref) async => effectiveRole(listed: role, readOnlyDetected: readOnly),
    ),
    libraryMemberNamesProvider('L').overrideWith((ref) async => {'m': 'Ann'}),
    pendingIncomingSuggestionCountProvider('L').overrideWith((ref) async => 2),
    sitesProvider.overrideWith(
      (ref) async => const [
        DiveSite(id: 'p1', name: 'Reef'),
        DiveSite(id: 'p2', name: 'Wreck'),
        DiveSite(id: 'l1', name: 'Reef wall', sharedLibraryId: 'L'),
      ],
    ),
  ],
  locale: const Locale('en'),
  child: const SharedLibraryPage(libraryId: 'L'),
);

void main() {
  testWidgets(
    'an owner sees Members, Suggestions with a badge, Add my sites, Leave',
    (tester) async {
      await tester.pumpWidget(await _page(SharedLibraryRole.owner));
      await tester.pumpAndSettle();
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Suggestions'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Add my sites'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Leave library'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Leave library'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
    },
  );

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
      await _page(SharedLibraryRole.reader, service: service, keyId: 'k2'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Enter the passphrase for Reef Survey.'), findsOneWidget);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('secret-field')), 'pw');
    await tester.tap(find.text('Unlock').last);
    await tester.pumpAndSettle();
    expect(service.secrets, ['pw']);
  });

  testWidgets('a lone owner is warned', (tester) async {
    await tester.pumpWidget(await _page(SharedLibraryRole.owner));
    await tester.pumpAndSettle();
    expect(find.textContaining('Only one owner'), findsOneWidget);
  });

  testWidgets('an editor gets no owner warning', (tester) async {
    await tester.pumpWidget(await _page(SharedLibraryRole.editor));
    await tester.pumpAndSettle();
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
