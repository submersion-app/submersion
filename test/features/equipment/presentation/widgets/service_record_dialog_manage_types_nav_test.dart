import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/presentation/pages/service_kind_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

// Regression coverage for "Manage Service Types" opening behind the Add
// Service Record dialog.
//
// Root cause: the dialog is shown with showDialog (useRootNavigator: true by
// default), but 'manageServiceTypes' is a GoRoute nested under the app's
// ShellRoute. Without a parentNavigatorKey it mounts on the shell's nested
// navigator, whose pages paint underneath the root navigator's dialog, so
// the service types page opened hidden behind the still-open dialog.
//
// This test reuses the REAL 'manageServiceTypes' GoRoute from the app
// router, so it goes red if that route loses its root navigator key.

GoRoute? _findRouteByName(List<RouteBase> routes, String name) {
  for (final route in routes) {
    if (route is GoRoute && route.name == name) return route;
    final found = _findRouteByName(route.routes, name);
    if (found != null) return found;
  }
  return null;
}

/// Mirrors the equipment detail page: a shell-hosted page that opens
/// [ServiceRecordDialog] through showDialog's default root navigator.
class _EquipmentHost extends StatelessWidget {
  const _EquipmentHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) =>
                ServiceRecordDialog(equipmentId: 'e1', onSave: (_) async {}),
          ),
          child: const Text('Add service'),
        ),
      ),
    );
  }
}

void main() {
  final t0 = DateTime(2026, 1, 1);

  testWidgets(
    'Manage Service Types pushed from the service record dialog shows the '
    'page on top, and the dialog comes back with its input intact',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final appContainer = ProviderContainer(
        overrides: [hasAnyDiversProvider.overrideWith((ref) async => true)],
      );
      addTearDown(appContainer.dispose);
      final manageRoute = _findRouteByName(
        appContainer.read(appRouterProvider).configuration.routes,
        'manageServiceTypes',
      );
      expect(manageRoute, isNotNull);

      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/equipment',
        routes: [
          ShellRoute(
            builder: (context, state, child) => child,
            routes: [
              GoRoute(
                path: '/equipment',
                builder: (context, state) => const _EquipmentHost(),
                routes: [manageRoute!],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      final overrides = await getBaseOverrides();
      final kinds = [
        ServiceKind(id: 'k1', name: 'Annual', createdAt: t0, updatedAt: t0),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            serviceKindsProvider.overrideWith((ref) async => kinds),
            serviceSchedulesForEquipmentProvider(
              'e1',
            ).overrideWith((ref) async => const []),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add service'));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceRecordDialog), findsOneWidget);

      final notesField = find.widgetWithText(TextFormField, 'Notes');
      await tester.enterText(notesField, 'Seal kit replaced');

      await tester.tap(find.text('Manage service types'));
      await tester.pumpAndSettle();

      // Behind the dialog the page exists in the tree but the dialog's
      // barrier swallows every tap; only a page above it is hit-testable.
      expect(
        find.byType(ServiceKindListPage).hitTestable(),
        findsOneWidget,
        reason: 'The service types page must open above the dialog.',
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ServiceKindListPage), findsNothing);
      expect(find.byType(ServiceRecordDialog), findsOneWidget);
      expect(find.text('Seal kit replaced'), findsOneWidget);
    },
  );
}
