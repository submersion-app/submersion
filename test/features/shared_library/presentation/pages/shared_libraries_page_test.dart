import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/pages/shared_libraries_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('empty state offers Connect a library', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          sharedLibrariesProvider.overrideWith(
            (ref) => Stream.value(const <SharedLibrary>[]),
          ),
          currentMembershipsProvider.overrideWith((ref) async => const []),
        ],
        locale: const Locale('en'),
        child: const SharedLibrariesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No shared site library connected yet.'), findsOneWidget);
    expect(find.text('Connect a library'), findsWidgets);
  });

  testWidgets('a connected library shows name, role and member count', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          sharedLibrariesProvider.overrideWith(
            (ref) => Stream.value(const [
              SharedLibrary(
                id: 'L',
                name: 'Club',
                connectedAccountId: 'a',
                prefix: 'club',
                roles: SharedLibraryRoles(owners: {'m'}),
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
          libraryMemberNamesProvider(
            'L',
          ).overrideWith((ref) async => {'m': 'Ann', 'x': 'Bob'}),
        ],
        locale: const Locale('en'),
        child: const SharedLibrariesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Club'), findsOneWidget);
    expect(find.textContaining('Owner'), findsOneWidget);
    expect(find.textContaining('2 members'), findsOneWidget);
  });

  testWidgets('a membership not connected on this device offers Connect', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          sharedLibrariesProvider.overrideWith(
            (ref) => Stream.value(const <SharedLibrary>[]),
          ),
          currentMembershipsProvider.overrideWith(
            (ref) async => const [
              SharedLibraryMembership(
                id: 'ms',
                diverId: 'd',
                libraryId: 'L',
                memberId: 'm',
                displayName: 'Ann',
                libraryName: 'Reef Club',
                backendKind: 's3',
                locationHint: 'Club bucket: reef',
              ),
            ],
          ),
        ],
        locale: const Locale('en'),
        child: const SharedLibrariesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reef Club'), findsOneWidget);
    expect(find.text('Not connected on this device'), findsOneWidget);
    expect(find.text('No shared site library connected yet.'), findsNothing);
  });
}
