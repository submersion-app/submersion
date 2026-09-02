import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_chips_row.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('renders one chip per tag with the localized name', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/viewer',
      routes: [
        GoRoute(
          path: '/viewer',
          builder: (_, _) =>
              const Scaffold(body: MediaSpeciesChipsRow(mediaId: 'p1')),
        ),
        GoRoute(
          path: '/species/:id',
          builder: (_, state) =>
              Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('de'),
        overrides: [
          ...overrides,
          mediaTagChipsProvider('p1').overrideWith(
            (ref) async => const [
              SpeciesTagChip(
                speciesId: 'sp_whale_shark',
                storedName: 'Whale Shark',
                category: SpeciesCategory.shark,
                isBuiltIn: true,
              ),
              SpeciesTagChip(
                speciesId: 'c1',
                storedName: 'My Nudibranch',
                category: SpeciesCategory.invertebrate,
                isBuiltIn: false,
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Walhai'), findsOneWidget);
    expect(find.text('My Nudibranch'), findsOneWidget);

    await tester.tap(find.text('Walhai'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL sp_whale_shark'), findsOneWidget);
  });

  testWidgets('renders nothing without tags', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          mediaTagChipsProvider('p1').overrideWith((ref) async => const []),
        ],
        child: const MediaSpeciesChipsRow(mediaId: 'p1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActionChip), findsNothing);
  });
}
