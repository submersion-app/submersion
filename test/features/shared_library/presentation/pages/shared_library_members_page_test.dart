import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
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

Future<Widget> _page(
  SharedLibraryRole myRole, {
  required _RecordingMembershipService service,
}) async => testApp(
  overrides: [
    ...await getBaseOverrides(),
    sharedLibrariesProvider.overrideWith(
      (ref) => Stream.value([
        const SharedLibrary(
          id: 'L',
          name: 'Club',
          connectedAccountId: 'a',
          prefix: 'club',
          roles: SharedLibraryRoles(owners: {'me'}, editors: {'ed'}),
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
          libraryName: 'Club',
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
        ),
        SharedLibraryMember(
          memberId: 'ed',
          displayName: 'Bob',
          joinedAt: DateTime.utc(2026, 10, 2),
        ),
        SharedLibraryMember(
          memberId: 'rd',
          displayName: '',
          joinedAt: DateTime.utc(2026, 10, 3),
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
}
