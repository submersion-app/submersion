import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('EquipmentDetailPage desktop redirect', () {
    const equipment = EquipmentItem(
      id: 'equip-1',
      name: 'BCD',
      type: EquipmentType.bcd,
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
          initialLocation: '/equipment/equip-1',
          routes: [
            GoRoute(
              path: '/equipment',
              builder: (context, state) =>
                  const Scaffold(body: Text('EQUIPMENT_LIST_PAGE')),
            ),
            GoRoute(
              path: '/equipment/:id',
              builder: (context, state) =>
                  EquipmentDetailPage(equipmentId: state.pathParameters['id']!),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              equipmentListViewModeProvider.overrideWith(
                (ref) => ListViewMode.detailed,
              ),
              equipmentItemProvider(
                equipment.id,
              ).overrideWith((ref) async => equipment),
              equipmentDiveCountProvider(
                equipment.id,
              ).overrideWith((ref) async => 0),
              equipmentTripCountProvider(
                equipment.id,
              ).overrideWith((ref) async => 0),
              serviceRecordNotifierProvider(
                equipment.id,
              ).overrideWith((ref) => _MockServiceRecordNotifier()),
              serviceRecordTotalCostProvider(
                equipment.id,
              ).overrideWith((ref) async => 0.0),
            ].cast(),
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('EQUIPMENT_LIST_PAGE'), findsOneWidget);
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
        initialLocation: '/equipment/equip-1',
        routes: [
          GoRoute(
            path: '/equipment',
            builder: (context, state) =>
                const Scaffold(body: Text('EQUIPMENT_LIST_PAGE')),
          ),
          GoRoute(
            path: '/equipment/:id',
            builder: (context, state) =>
                EquipmentDetailPage(equipmentId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            equipmentListViewModeProvider.overrideWith(
              (ref) => ListViewMode.table,
            ),
            equipmentItemProvider(
              equipment.id,
            ).overrideWith((ref) async => equipment),
            equipmentDiveCountProvider(
              equipment.id,
            ).overrideWith((ref) async => 0),
            equipmentTripCountProvider(
              equipment.id,
            ).overrideWith((ref) async => 0),
            serviceRecordNotifierProvider(
              equipment.id,
            ).overrideWith((ref) => _MockServiceRecordNotifier()),
            serviceRecordTotalCostProvider(
              equipment.id,
            ).overrideWith((ref) async => 0.0),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('EQUIPMENT_LIST_PAGE'), findsNothing);
    });
  });
}

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
