import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/widgets/personal_records_card.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('PersonalRecordsCard bottomTime coverage', () {
    testWidgets('shows longest dive duration from bottomTime', (tester) async {
      final dives = [
        createTestDiveWithBottomTime(
          id: 'longest',
          bottomTime: const Duration(minutes: 60),
          maxDepth: 30.0,
          waterTemp: 20.0,
        ),
      ];
      final overrides = await getBaseOverrides();

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: PersonalRecordsCard()),
          ),
          GoRoute(
            path: '/dives/:id',
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

      expect(find.text('60min'), findsOneWidget);
    });
  });
}
