import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/shared_library/presentation/pages/shared_library_members_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Records role changes instead of touching storage; throws the last-owner
/// StateError on demand.
class _RecordingMembershipService extends SharedLibraryMembershipService {
  _RecordingMembershipService({this.refuse = false, this.offline = false})
    : super(
        store: SharedLibraryStore(),
        transportFor: ({required account, required prefix}) =>
            throw UnimplementedError(),
      );

  final bool refuse;
  final bool offline;
  final calls = <(String, String, SharedLibraryRole)>[];
  final approvals = <(String, String)>[];
  final rejections = <String>[];

  @override
  Future<void> approveMember({
    required String libraryId,
    required String memberId,
    required String actingMemberId,
    required String publicKey,
  }) async => approvals.add((memberId, publicKey));

  @override
  Future<void> rejectMember({
    required String libraryId,
    required String memberId,
    required String actingMemberId,
  }) async => rejections.add(memberId);

  @override
  Future<void> setRole({
    required String libraryId,
    required String actingMemberId,
    required String memberId,
    required SharedLibraryRole role,
  }) async {
    if (refuse) throw LastOwnerDemoteError(libraryId);
    if (offline) throw const CloudStorageException('Network unreachable');
    calls.add((actingMemberId, memberId, role));
  }
}

String _key(int n) => base64Encode(List.filled(32, n));

Future<Widget> _page(
  SharedLibraryRole myRole, {
  required _RecordingMembershipService service,
  bool withPending = false,
  bool withDeparted = false,
}) async => testApp(
  overrides: [
    ...await getBaseOverrides(),
    sharedLibrariesProvider.overrideWith(
      (ref) => Stream.value([
        SharedLibrary(
          id: 'L',
          name: 'Reef Survey',
          connectedAccountId: 'a',
          prefix: 'site-sync',
          roles: SharedLibraryRoles(
            owners: const {'me'},
            editors: {'ed', if (withDeparted) 'gone'},
            approvedKeys: {'me': _key(1), 'ed': _key(2), 'rd': _key(3)},
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
          memberId: 'me',
          displayName: 'Ann',
          libraryName: 'Reef Survey',
          backendKind: 's3',
        ),
      ],
    ),
    libraryRoleProvider('L').overrideWith((ref) async => myRole),
    libraryMembersProvider('L').overrideWith(
      (ref) async => [
        SharedLibraryMember(
          memberId: 'me',
          displayName: 'Ann',
          joinedAt: DateTime.utc(2026, 10, 1),
          publicKey: _key(1),
          cardVerified: true,
        ),
        SharedLibraryMember(
          memberId: 'ed',
          displayName: 'Bob',
          joinedAt: DateTime.utc(2026, 10, 2),
          publicKey: _key(2),
          cardVerified: true,
        ),
        SharedLibraryMember(
          memberId: 'rd',
          displayName: '',
          joinedAt: DateTime.utc(2026, 10, 3),
          publicKey: _key(3),
          cardVerified: true,
        ),
        if (withPending)
          SharedLibraryMember(
            memberId: 'pd',
            displayName: 'Pat',
            joinedAt: DateTime.utc(2026, 10, 4),
            publicKey: _key(4),
            cardVerified: true,
          ),
      ],
    ),
    sharedLibraryMembershipServiceProvider.overrideWithValue(service),
  ],
  locale: const Locale('en'),
  child: const SharedLibraryMembersPage(libraryId: 'L'),
);

void main() {
  testWidgets('lists members with their roles, falling back to the id', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _page(
        SharedLibraryRole.reader,
        service: _RecordingMembershipService(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('rd'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Reader'), findsOneWidget);
    // A reader gets no role menu.
    expect(find.byType(PopupMenuButton<SharedLibraryRole>), findsNothing);
  });

  testWidgets('an owner changes a role through the menu', (tester) async {
    final service = _RecordingMembershipService();
    await tester.pumpWidget(
      await _page(SharedLibraryRole.owner, service: service),
    );
    await tester.pumpAndSettle();
    final menus = find.byType(PopupMenuButton<SharedLibraryRole>);
    expect(menus, findsNWidgets(3));

    await tester.tap(menus.at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editor').last);
    await tester.pumpAndSettle();

    expect(service.calls, [('me', 'rd', SharedLibraryRole.editor)]);
  });

  testWidgets('demoting the last owner shows the refusal', (tester) async {
    await tester.pumpWidget(
      await _page(
        SharedLibraryRole.owner,
        service: _RecordingMembershipService(refuse: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<SharedLibraryRole>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reader').last);
    await tester.pumpAndSettle();
    expect(find.text('The last owner cannot be demoted.'), findsOneWidget);
  });

  testWidgets('a storage failure says what went wrong', (tester) async {
    await tester.pumpWidget(
      await _page(
        SharedLibraryRole.owner,
        service: _RecordingMembershipService(offline: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<SharedLibraryRole>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editor').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Network unreachable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an owner sees and approves a member waiting for approval', (
    tester,
  ) async {
    final service = _RecordingMembershipService();
    await tester.pumpWidget(
      await _page(SharedLibraryRole.owner, service: service, withPending: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Waiting for approval'), findsOneWidget);
    expect(find.text('Pat'), findsOneWidget);
    expect(
      find.text('Key ${LibrarySigner.fingerprint(_key(4))}'),
      findsOneWidget,
    );
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    // The key the owner was shown, for the service to hold the card to.
    expect(service.approvals, [('pd', _key(4))]);
  });

  testWidgets('rejecting asks first', (tester) async {
    final service = _RecordingMembershipService();
    await tester.pumpWidget(
      await _page(SharedLibraryRole.owner, service: service, withPending: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();
    expect(service.rejections, ['pd']);
  });

  testWidgets('a reader sees approved members only', (tester) async {
    await tester.pumpWidget(
      await _page(
        SharedLibraryRole.reader,
        service: _RecordingMembershipService(),
        withPending: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pat'), findsNothing);
    expect(find.text('Waiting for approval'), findsNothing);
  });

  testWidgets('an owner removes the role of a member who left', (tester) async {
    final service = _RecordingMembershipService();
    await tester.pumpWidget(
      await _page(
        SharedLibraryRole.owner,
        service: service,
        withDeparted: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Left the library'), findsOneWidget);
    await tester.tap(find.text('Remove role'));
    await tester.pumpAndSettle();
    expect(service.calls, [('me', 'gone', SharedLibraryRole.reader)]);
  });
}
