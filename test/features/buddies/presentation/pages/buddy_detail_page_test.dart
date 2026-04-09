import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('BuddyDetailPage desktop redirect', () {
    final buddy = Buddy(
      id: 'buddy-1',
      name: 'Jane Doe',
      notes: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    testWidgets(
      'redirects to master-detail on desktop when not in table mode',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final overrides = await getBaseOverrides();

        final router = GoRouter(
          initialLocation: '/buddies/buddy-1',
          routes: [
            GoRoute(
              path: '/buddies',
              builder: (context, state) =>
                  const Scaffold(body: Text('BUDDY_LIST_PAGE')),
            ),
            GoRoute(
              path: '/buddies/:id',
              builder: (context, state) =>
                  BuddyDetailPage(buddyId: state.pathParameters['id']!),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              buddyListViewModeProvider.overrideWith(
                (ref) => ListViewMode.detailed,
              ),
              buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
              buddyStatsProvider(
                buddy.id,
              ).overrideWith((ref) async => const BuddyStats(totalDives: 0)),
              diveIdsForBuddyProvider(
                buddy.id,
              ).overrideWith((ref) async => <String>[]),
              divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
            ].cast(),
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('BUDDY_LIST_PAGE'), findsOneWidget);
      },
    );

    testWidgets('does not redirect on desktop in table mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      final router = GoRouter(
        initialLocation: '/buddies/buddy-1',
        routes: [
          GoRoute(
            path: '/buddies',
            builder: (context, state) =>
                const Scaffold(body: Text('BUDDY_LIST_PAGE')),
          ),
          GoRoute(
            path: '/buddies/:id',
            builder: (context, state) =>
                BuddyDetailPage(buddyId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            buddyListViewModeProvider.overrideWith((ref) => ListViewMode.table),
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            buddyStatsProvider(
              buddy.id,
            ).overrideWith((ref) async => const BuddyStats(totalDives: 0)),
            diveIdsForBuddyProvider(
              buddy.id,
            ).overrideWith((ref) async => <String>[]),
            divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('BUDDY_LIST_PAGE'), findsNothing);
    });
  });

  group('BuddyDetailPage bottomTime coverage', () {
    testWidgets('displays dive bottomTime in buddy dive history', (
      tester,
    ) async {
      final buddy = Buddy(
        id: 'buddy-1',
        name: 'Jane Doe',
        notes: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final dives = [
        createTestDiveWithBottomTime(
          id: 'buddy-dive-1',
          diveNumber: 1,
          bottomTime: const Duration(minutes: 45),
          maxDepth: 25.0,
        ),
      ];

      final overrides = await getBaseOverrides();

      // Use mobile size to avoid master-detail layout
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            buddyStatsProvider(
              buddy.id,
            ).overrideWith((ref) async => const BuddyStats(totalDives: 1)),
            diveIdsForBuddyProvider(
              buddy.id,
            ).overrideWith((ref) async => ['buddy-dive-1']),
            divesForBuddyProvider(buddy.id).overrideWith((ref) async => dives),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyDetailPage(buddyId: buddy.id, embedded: true),
          ),
        ),
      );
      // Tolerate overflow errors in test layout
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = (d) => errors.add(d);
      await tester.pumpAndSettle();
      FlutterError.onError = FlutterError.presentError;

      // Should show bottomTime formatted as minutes in dive history
      expect(find.text('45min'), findsOneWidget);
    });
  });
}
