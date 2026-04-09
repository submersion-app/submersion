import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('DiveCenterDetailPage desktop redirect', () {
    final center = DiveCenter(
      id: 'center-1',
      name: 'Reef Divers',
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
          initialLocation: '/dive-centers/center-1',
          routes: [
            GoRoute(
              path: '/dive-centers',
              builder: (context, state) =>
                  const Scaffold(body: Text('DIVE_CENTER_LIST_PAGE')),
            ),
            GoRoute(
              path: '/dive-centers/:id',
              builder: (context, state) =>
                  DiveCenterDetailPage(centerId: state.pathParameters['id']!),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              diveCenterListViewModeProvider.overrideWith(
                (ref) => ListViewMode.detailed,
              ),
              diveCenterByIdProvider(
                center.id,
              ).overrideWith((ref) async => center),
              diveCenterDiveCountProvider(
                center.id,
              ).overrideWith((ref) async => 0),
            ].cast(),
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('DIVE_CENTER_LIST_PAGE'), findsOneWidget);
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
        initialLocation: '/dive-centers/center-1',
        routes: [
          GoRoute(
            path: '/dive-centers',
            builder: (context, state) =>
                const Scaffold(body: Text('DIVE_CENTER_LIST_PAGE')),
          ),
          GoRoute(
            path: '/dive-centers/:id',
            builder: (context, state) =>
                DiveCenterDetailPage(centerId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveCenterListViewModeProvider.overrideWith(
              (ref) => ListViewMode.table,
            ),
            diveCenterByIdProvider(
              center.id,
            ).overrideWith((ref) async => center),
            diveCenterDiveCountProvider(
              center.id,
            ).overrideWith((ref) async => 0),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('DIVE_CENTER_LIST_PAGE'), findsNothing);
    });
  });
}
