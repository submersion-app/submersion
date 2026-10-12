import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/pages/shared_library_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

Future<Widget> _page(
  SharedLibraryRole role, {
  bool readOnly = false,
  String? error,
}) async => testApp(
  overrides: [
    ...await getBaseOverrides(),
    sharedLibrariesProvider.overrideWith(
      (ref) => Stream.value([
        SharedLibrary(
          id: 'L',
          name: 'Club',
          connectedAccountId: 'a',
          prefix: 'club',
          readOnlyDetected: readOnly,
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
          libraryName: 'Club',
          backendKind: 's3',
        ),
      ],
    ),
    libraryRoleProvider('L').overrideWith(
      (ref) async => effectiveRole(listed: role, readOnlyDetected: readOnly),
    ),
    libraryMemberNamesProvider('L').overrideWith((ref) async => {'m': 'Ann'}),
    pendingIncomingSuggestionCountProvider('L').overrideWith((ref) async => 2),
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
}
