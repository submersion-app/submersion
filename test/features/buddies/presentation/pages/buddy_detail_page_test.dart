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

class _MockBuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>>
    implements BuddyListNotifier {
  _MockBuddyListNotifier() : super(const AsyncValue.data(<Buddy>[]));

  String? lastConvertedBuddyId;

  @override
  Future<String> convertToDiveCenter(Buddy buddy) async {
    lastConvertedBuddyId = buddy.id;
    return 'new-dive-center-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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

  group('BuddyDetailPage conversion', () {
    testWidgets('triggers _handleConvertToDiveCenter flow when selected', (
      tester,
    ) async {
      // Tolerate overflow errors in test layout throughout the test
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          return;
        }
        oldOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldOnError);

      final buddy = Buddy(
        id: 'buddy-conv-1',
        name: 'Conversion Buddy',
        notes: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final notifier = _MockBuddyListNotifier();
      final overrides = await getBaseOverrides();

      // Use a size just below master-detail breakpoint to avoid redirect
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(719, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/buddies/buddy-conv-1',
        routes: [
          GoRoute(
            path: '/buddies/:id',
            builder: (context, state) =>
                BuddyDetailPage(buddyId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/dive-centers/:id',
            builder: (context, state) => Scaffold(
              body: Text('DIVE_CENTER_${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            buddyStatsProvider(
              buddy.id,
            ).overrideWith((ref) async => const BuddyStats(totalDives: 0)),
            diveIdsForBuddyProvider(
              buddy.id,
            ).overrideWith((ref) async => <String>[]),
            divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
            buddyListNotifierProvider.overrideWith((ref) => notifier),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Get localization strings early
      final context = tester.element(find.byType(BuddyDetailPage));
      final l10n = AppLocalizations.of(context);
      final convertText = l10n.buddies_action_convertToDiveCenter;
      final confirmTitle = l10n.buddies_conversion_confirmTitle;
      final continueText = l10n.common_action_continue;
      final successText = l10n.buddies_conversion_success;

      // 1. Open the popup menu
      // In mobile mode, it's a more_vert icon in AppBar
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // 2. Tap "Convert to Dive Center"
      await tester.tap(find.text(convertText));
      await tester.pumpAndSettle();

      // 3. Verify confirmation dialog appears
      expect(find.text(confirmTitle), findsOneWidget);

      // 4. Tap "Continue"
      await tester.tap(find.text(continueText));
      await tester.pumpAndSettle();

      // 5. Verify notifier was called
      expect(notifier.lastConvertedBuddyId, equals(buddy.id));

      // 6. Verify navigation to the new dive center
      expect(find.text('DIVE_CENTER_new-dive-center-id'), findsOneWidget);

      // 7. Verify success snackbar
      expect(find.text(successText), findsOneWidget);
    });
  });
}
