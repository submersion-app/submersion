import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/unit_configurations_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/test_app.dart';

void main() {
  final now = DateTime.utc(2026, 8, 5);

  CylinderConfigItem item(TankRole role) => CylinderConfigItem(
    id: 'i-${role.name}',
    configId: 'c1',
    tankRole: role,
    createdAt: now,
    updatedAt: now,
  );

  Widget host(List<CylinderConfig> configs) => ProviderScope(
    overrides: [
      cylinderConfigsForEquipmentProvider(
        'rb-1',
      ).overrideWith((ref) async => configs),
    ],
    child: const MaterialApp(
      // Pinned: an unpinned locale makes text finders machine-dependent.
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: UnitConfigurationsCard(equipmentId: 'rb-1')),
    ),
  );

  testWidgets("lists the unit's configurations with cylinder counts", (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        CylinderConfig(
          id: 'c1',
          name: 'JJ trimix',
          equipmentId: 'rb-1',
          items: [item(TankRole.diluent), item(TankRole.oxygenSupply)],
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configurations'), findsOneWidget);
    expect(find.text('JJ trimix'), findsOneWidget);
    expect(find.text('Diluent, O₂ Supply'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows an empty state with an add action when there are none', (
    tester,
  ) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();

    expect(find.text('Configurations'), findsOneWidget);
    expect(find.text('New configuration'), findsOneWidget);
    expect(
      find.textContaining('Save a diluent and bailout setup once'),
      findsOneWidget,
    );
  });

  testWidgets('a pending read shows a spinner, not the empty state', (
    tester,
  ) async {
    // "None yet" and "still loading" are different answers; showing the empty
    // copy mid-read reads as though the unit's configurations were lost.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cylinderConfigsForEquipmentProvider(
            'rb-1',
          ).overrideWith((ref) => Completer<List<CylinderConfig>>().future),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: UnitConfigurationsCard(equipmentId: 'rb-1')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.textContaining('Save a diluent and bailout setup once'),
      findsNothing,
    );
  });

  testWidgets('a failed read surfaces the error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // A thrown error, not an eagerly built Future.error: the latter has
          // no listener at construction time and the test framework claims it
          // before Riverpod can route it to the widget's error arm.
          cylinderConfigsForEquipmentProvider(
            'rb-1',
          ).overrideWith((ref) async => throw Exception('no database')),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: UnitConfigurationsCard(equipmentId: 'rb-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('no database'), findsOneWidget);
  });

  group('navigation', () {
    late String location;

    Widget routedHost(List<CylinderConfig> configs) {
      Widget probe() => Builder(
        builder: (context) {
          location = GoRouterState.of(context).uri.toString();
          return const Scaffold(body: Text('elsewhere'));
        },
      );

      return testAppRouter(
        locale: const Locale('en'),
        overrides: [
          cylinderConfigsForEquipmentProvider(
            'rb-1',
          ).overrideWith((ref) async => configs),
        ],
        router: GoRouter(
          initialLocation: '/equipment/rb-1',
          routes: [
            GoRoute(
              path: '/equipment/rb-1',
              builder: (context, state) => const Scaffold(
                body: UnitConfigurationsCard(equipmentId: 'rb-1'),
              ),
            ),
            GoRoute(
              path: '/equipment/cylinder-configs/new',
              builder: (context, state) => probe(),
            ),
            GoRoute(
              path: '/equipment/cylinder-configs/:configId',
              builder: (context, state) => probe(),
            ),
          ],
        ),
      );
    }

    testWidgets('the add action pre-selects the owning unit', (tester) async {
      await tester.pumpWidget(routedHost(const []));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New configuration'));
      await tester.pumpAndSettle();

      // The query parameter is what makes the new config belong to this unit
      // instead of landing as a generic gas plan.
      expect(location, '/equipment/cylinder-configs/new?equipmentId=rb-1');
    });

    testWidgets('tapping a configuration opens it by id', (tester) async {
      await tester.pumpWidget(
        routedHost([
          CylinderConfig(
            id: 'c1',
            name: 'JJ trimix',
            equipmentId: 'rb-1',
            items: [item(TankRole.diluent)],
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('JJ trimix'));
      await tester.pumpAndSettle();

      expect(location, '/equipment/cylinder-configs/c1');
    });
  });
}
