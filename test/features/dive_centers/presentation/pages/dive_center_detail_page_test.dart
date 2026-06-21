import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';
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

  group('DiveCenterDetailPage map section', () {
    final centerWithCoords = DiveCenter(
      id: 'center-map',
      name: 'Ocean Dive Center',
      notes: '',
      latitude: 18.4655,
      longitude: -66.1057,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    testWidgets(
      'renders FlutterMap and MapInteractionDetector when center has coordinates',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(800, 600);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final overrides = await getBaseOverrides();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              diveCenterByIdProvider(
                centerWithCoords.id,
              ).overrideWith((ref) async => centerWithCoords),
              diveCenterDiveCountProvider(
                centerWithCoords.id,
              ).overrideWith((ref) async => 0),
            ].cast(),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DiveCenterDetailPage(
                centerId: centerWithCoords.id,
                embedded: true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.byType(MapInteractionDetector), findsOneWidget);
      },
    );

    testWidgets('tapping fullscreen button opens fullscreen map page', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveCenterByIdProvider(
              centerWithCoords.id,
            ).overrideWith((ref) async => centerWithCoords),
            diveCenterDiveCountProvider(
              centerWithCoords.id,
            ).overrideWith((ref) async => 0),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveCenterDetailPage(
              centerId: centerWithCoords.id,
              embedded: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the fullscreen icon button overlay on the map.
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();

      // The fullscreen page renders with the center's name in the app bar
      // and a FlutterMap with a MapInteractionDetector.
      expect(find.text(centerWithCoords.name), findsWidgets);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MapInteractionDetector), findsOneWidget);
    });
  });
}
