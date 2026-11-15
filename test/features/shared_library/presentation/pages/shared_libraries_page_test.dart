import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/pages/shared_libraries_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';

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
                name: 'Reef Survey',
                connectedAccountId: 'a',
                prefix: 'site-sync',
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
                libraryName: 'Reef Survey',
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
    expect(find.text('Reef Survey'), findsOneWidget);
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
                libraryName: 'Reef Watch',
                backendKind: 's3',
                locationHint: 'Survey bucket: reef',
              ),
            ],
          ),
        ],
        locale: const Locale('en'),
        child: const SharedLibrariesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reef Watch'), findsOneWidget);
    expect(find.text('Not connected on this device'), findsOneWidget);
    expect(find.text('No shared site library connected yet.'), findsNothing);
  });

  // Issue #4561: each library with a problem carries its own mark, at its
  // own level, and the error icon keeps its shape but not its colour.
  testWidgets('each library is marked at its own level', (tester) async {
    const libraries = [
      SharedLibrary(
        id: 'L1',
        name: 'Reef Survey',
        connectedAccountId: 'a',
        prefix: 'site-sync',
        roles: SharedLibraryRoles(owners: {'m'}),
        lastError: 'boom',
      ),
      SharedLibrary(
        id: 'L2',
        name: 'Cave Survey',
        connectedAccountId: 'a',
        prefix: 'cave',
        roles: SharedLibraryRoles(owners: {'m'}),
      ),
    ];
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          sharedLibrariesProvider.overrideWith(
            (ref) => Stream.value(libraries),
          ),
          currentMembershipsProvider.overrideWith(
            (ref) async => [
              for (final l in libraries)
                SharedLibraryMembership(
                  id: 'ms-${l.id}',
                  diverId: 'd',
                  libraryId: l.id,
                  memberId: 'm',
                  displayName: 'Ann',
                  libraryName: l.name,
                  backendKind: 's3',
                ),
            ],
          ),
          sharedLibrariesHealthProvider.overrideWithValue(
            pickHealth(DataFeature.sharedLibraries, const [
              FeatureHealth(
                feature: DataFeature.sharedLibraries,
                level: HealthLevel.failing,
                reason: HealthReason.librariesFailed,
                subjectId: 'L1',
              ),
              FeatureHealth(
                feature: DataFeature.sharedLibraries,
                level: HealthLevel.attention,
                reason: HealthReason.librariesEditsHeld,
                subjectId: 'L2',
              ),
            ]),
          ),
        ],
        locale: const Locale('en'),
        child: const SharedLibrariesPage(),
      ),
    );
    await tester.pumpAndSettle();

    HealthLevel levelOf(String name) => tester
        .widget<HealthSymbol>(
          find.descendant(
            of: find.ancestor(
              of: find.text(name),
              matching: find.byType(ListTile),
            ),
            matching: find.byType(HealthSymbol),
          ),
        )
        .level;
    expect(levelOf('Reef Survey'), HealthLevel.failing);
    expect(levelOf('Cave Survey'), HealthLevel.attention);
    expect(tester.widget<Icon>(find.byIcon(Icons.error_outline)).color, isNull);
  });
}
