import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dives_card.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('RecentDivesCard bottomTime coverage', () {
    testWidgets('renders dive card with runtime/bottomTime fallback', (
      tester,
    ) async {
      final dives = [
        createTestDiveWithBottomTime(
          id: 'recent-1',
          diveNumber: 1,
          bottomTime: const Duration(minutes: 45),
          runtime: const Duration(minutes: 50),
          maxDepth: 25.0,
          waterTemp: 22.0,
        ),
      ];
      final overrides = await getBaseOverrides();

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: RecentDivesCard()),
          ),
          GoRoute(
            path: '/dives',
            builder: (context, state) => const Scaffold(),
          ),
          GoRoute(
            path: '/dives/:id',
            builder: (context, state) => const Scaffold(),
          ),
          GoRoute(
            path: '/dives/new',
            builder: (context, state) => const Scaffold(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            divesProvider.overrideWith((ref) async => dives),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RecentDivesCard), findsOneWidget);
    });
  });
}
