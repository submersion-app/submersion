import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/widgets/alerts_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('AlertsCard compact banner', () {
    testWidgets('hidden when no alerts', (tester) async {
      final overrides = await getBaseOverrides();

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: AlertsCard()),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            serviceDueEquipmentProvider.overrideWith((ref) async => []),
            currentDiverProvider.overrideWith((ref) async => null),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render nothing
      expect(find.byType(AlertsCard), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
    });

    testWidgets('shows compact banner with alert count badge', (tester) async {
      final overrides = await getBaseOverrides();
      final equipment = EquipmentItem(
        id: 'eq1',
        name: 'Regulator',
        type: EquipmentType.regulator,
        lastServiceDate: DateTime.now().subtract(const Duration(days: 400)),
        serviceIntervalDays: 365,
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: AlertsCard()),
          ),
          GoRoute(path: '/equipment/:id', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/settings', builder: (_, _) => const Scaffold()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            serviceDueEquipmentProvider.overrideWith(
              (ref) async => [equipment],
            ),
            currentDiverProvider.overrideWith((ref) async => null),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge count should be visible
      expect(find.text('1'), findsWidgets);
    });
  });
}
